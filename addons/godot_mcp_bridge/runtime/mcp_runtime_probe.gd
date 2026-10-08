## Autoload injected into the running game by the GodotMCP editor plugin (see
## plugin.gd's add_autoload_singleton call). Connects out to the editor's
## runtime WebSocket channel and answers game_* tool calls using live
## SceneTree access. Only relevant while actually playing — in the editor
## itself this script is never instantiated as a bridge endpoint.
extends Node

const JsonRpc = preload("res://addons/godot_mcp_bridge/utils/json_rpc.gd")

const RUNTIME_CHANNEL_PORT := 8766

var _socket := WebSocketPeer.new()
var _dispatch: Dictionary = {}
var _deferred_dispatch: Dictionary = {}

## Tools that need more than one frame to answer (waiting for a condition,
## sampling over time, playing back a timed sequence) go through this queue
## instead of returning immediately from _handle_frame. Each entry is
## {id, elapsed, timeout, check}, where `check` is a Callable(delta: float)
## -> Variant: null means "not ready yet", any other value is the final
## result (or an error Dictionary) to send back.
var _pending_ops: Array = []

var _recording := false
var _recorded_events: Array = []
var _record_start_time: float = 0.0


func _ready() -> void:
	# Must keep polling (and stay reachable for game_set_paused(false)) even
	# while the game itself is paused — a debug bridge that pause locks
	# itself out is useless.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_register_handlers()
	# Default buffer sizes (64KB) are too small for a base64-encoded
	# screenshot or GIF frame sequence (game_screenshot/game_capture_gif) —
	# must be set before connect_to_url() establishes the handshake.
	_socket.inbound_buffer_size = 16 * 1024 * 1024
	_socket.outbound_buffer_size = 16 * 1024 * 1024
	var err := _socket.connect_to_url("ws://127.0.0.1:%d" % RUNTIME_CHANNEL_PORT)
	if err != OK:
		push_warning("GodotMCP runtime probe: could not start connecting to the editor bridge (err %d)" % err)


func _register_handlers() -> void:
	_dispatch["game_get_scene_tree"] = _get_scene_tree
	_dispatch["game_get_node_properties"] = _get_node_properties
	_dispatch["game_set_node_property"] = _set_node_property
	_dispatch["game_call_method"] = _call_method
	_dispatch["game_reload_scene"] = _reload_scene
	_dispatch["game_set_paused"] = _set_paused
	_dispatch["game_set_time_scale"] = _set_time_scale
	_dispatch["game_assert_property"] = _assert_property
	_dispatch["game_get_performance"] = _get_performance
	_dispatch["game_simulate_input"] = _simulate_input
	_dispatch["game_find_ui"] = _find_ui
	_dispatch["game_describe_screen"] = _describe_screen
	_dispatch["game_click_ui"] = _click_ui
	_dispatch["game_start_input_recording"] = _start_input_recording
	_dispatch["game_stop_input_recording"] = _stop_input_recording
	_dispatch["game_screenshot"] = _screenshot
	_dispatch["game_raycast_3d"] = _raycast_3d
	_dispatch["game_get_collision_report"] = _get_collision_report
	_dispatch["game_set_debug_draw"] = _set_debug_draw

	_deferred_dispatch["game_wait_for_node"] = _wait_for_node_deferred
	_deferred_dispatch["game_monitor_property"] = _monitor_property_deferred
	_deferred_dispatch["game_simulate_sequence"] = _simulate_sequence_deferred
	_deferred_dispatch["game_replay_input"] = _replay_input_deferred
	_deferred_dispatch["game_capture_gif"] = _capture_gif_deferred


func _process(delta: float) -> void:
	_socket.poll()
	if _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		while _socket.get_available_packet_count() > 0:
			_handle_frame(_socket.get_packet().get_string_from_utf8())
	_tick_pending_ops(delta)


func _handle_frame(raw: String) -> void:
	var request := JsonRpc.decode_request(raw)
	if request.is_empty():
		return

	var id: String = request["id"]
	var tool: String = request["tool"]
	var params: Dictionary = request["params"]

	if _deferred_dispatch.has(tool):
		var starter: Callable = _deferred_dispatch[tool]
		starter.call(id, params)
		return

	if not _dispatch.has(tool):
		_send(JsonRpc.encode_error(id, "TOOL_NOT_IMPLEMENTED", "No runtime handler bound for tool '%s'" % tool))
		return

	var handler: Callable = _dispatch[tool]
	_respond(id, handler.call(params))


func _respond(id: String, result: Variant) -> void:
	if typeof(result) == TYPE_DICTIONARY and result.has("__error_code__"):
		_send(JsonRpc.encode_error(id, result["__error_code__"], result["__error_message__"]))
	else:
		_send(JsonRpc.encode_success(id, result))


func _send(payload: String) -> void:
	if _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_socket.send_text(payload)


func _tick_pending_ops(delta: float) -> void:
	var i := _pending_ops.size() - 1
	while i >= 0:
		var op: Dictionary = _pending_ops[i]
		var check: Callable = op["check"]
		var result: Variant = check.call(delta)
		if result != null:
			_respond(op["id"], result)
			_pending_ops.remove_at(i)
		else:
			op["elapsed"] += delta
			if op["elapsed"] >= op["timeout"]:
				_send(JsonRpc.encode_error(op["id"], "TIMEOUT", "Operation timed out"))
				_pending_ops.remove_at(i)
		i -= 1


# --- node_path resolution, relative to the running game's current scene ----

func _resolve(params: Dictionary) -> Variant:
	var root := get_tree().current_scene
	if root == null:
		return {"__error_code__": "NO_GAME_RUNNING", "__error_message__": "No current scene in the running game"}
	var node_path: String = params.get("node_path", "")
	if node_path == "" or node_path == ".":
		return root
	var node := root.get_node_or_null(NodePath(node_path))
	if node == null:
		return {"__error_code__": "NODE_NOT_FOUND", "__error_message__": "No node at path %s" % node_path}
	return node


func _relative_path(root: Node, node: Node) -> String:
	return "." if node == root else str(root.get_path_to(node))


## Compares two Variants without ever invoking `==` on genuinely mismatched
## types — GDScript raises a runtime error for that (e.g. String == bool)
## rather than just returning false, which matters here because `expected`
## values come from arbitrary caller-supplied JSON.
func _safe_equals(a: Variant, b: Variant) -> bool:
	var ta := typeof(a)
	var tb := typeof(b)
	if ta == tb:
		return a == b
	var numeric := [TYPE_INT, TYPE_FLOAT]
	if ta in numeric and tb in numeric:
		return a == b
	return false


func _vec2(d: Dictionary) -> Vector2:
	return Vector2(d.get("x", 0.0), d.get("y", 0.0))


func _vec2_to_dict(v: Vector2) -> Dictionary:
	return {"x": v.x, "y": v.y}


func _vec3(d: Dictionary) -> Vector3:
	return Vector3(d.get("x", 0.0), d.get("y", 0.0), d.get("z", 0.0))


func _vec3_to_dict(v: Vector3) -> Dictionary:
	return {"x": v.x, "y": v.y, "z": v.z}


# --- core handlers -----------------------------------------------------------

func _get_scene_tree(_params: Dictionary) -> Dictionary:
	var root := get_tree().current_scene
	if root == null:
		return {"root": null}
	return {"root": _describe_node(root, root)}


func _describe_node(node: Node, root: Node) -> Dictionary:
	var children: Array = []
	for child in node.get_children():
		children.append(_describe_node(child, root))
	return {"name": node.name, "type": node.get_class(), "path": _relative_path(root, node), "children": children}


func _get_node_properties(params: Dictionary) -> Variant:
	var node := _resolve(params)
	if node is Dictionary:
		return node
	var requested: Array = params.get("properties", [])
	var result := {}
	if requested.is_empty():
		for prop in node.get_property_list():
			var name: String = prop.get("name", "")
			if name != "" and (prop.get("usage", 0) & PROPERTY_USAGE_STORAGE):
				result[name] = node.get(name)
	else:
		for name in requested:
			result[name] = node.get(name)
	return {"properties": result}


func _set_node_property(params: Dictionary) -> Variant:
	var node := _resolve(params)
	if node is Dictionary:
		return node
	var property: String = params.get("property", "")
	if property == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "property is required"}
	node.set(property, params.get("value"))
	return {"node_path": params.get("node_path", ""), "property": property, "value": node.get(property)}


func _call_method(params: Dictionary) -> Variant:
	var node := _resolve(params)
	if node is Dictionary:
		return node
	var method: String = params.get("method", "")
	if method == "" or not node.has_method(method):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "Node has no method %s" % method}
	var args: Array = params.get("args", [])
	return {"result": node.callv(method, args)}


func _reload_scene(_params: Dictionary) -> Variant:
	var err: Error = get_tree().reload_current_scene()
	if err != OK:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": error_string(err)}
	return {"reloaded": true}


func _set_paused(params: Dictionary) -> Dictionary:
	get_tree().paused = bool(params.get("paused", true))
	return {"paused": get_tree().paused}


func _set_time_scale(params: Dictionary) -> Dictionary:
	Engine.time_scale = float(params.get("time_scale", 1.0))
	return {"time_scale": Engine.time_scale}


func _assert_property(params: Dictionary) -> Variant:
	var node := _resolve(params)
	if node is Dictionary:
		return node
	var property: String = params.get("property", "")
	var expected: Variant = params.get("expected")
	var actual: Variant = node.get(property)
	return {"passed": _safe_equals(actual, expected), "property": property, "expected": expected, "actual": actual}


func _get_performance(_params: Dictionary) -> Dictionary:
	return {
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"process_time_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_process_time_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"static_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
		"object_count": Performance.get_monitor(Performance.OBJECT_COUNT),
		"node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
	}


## Was previously (dead) code in execution_testing.gd's editor-channel
## dispatch table, using EditorInterface's own viewport — game_* tools are
## always relayed to this runtime probe by bridge_server.gd before the editor
## dispatch table is ever consulted, so that registration could never be
## reached. Moved here, targeting the running game's own viewport instead.
func _set_debug_draw(params: Dictionary) -> Variant:
	var mode_str: String = params.get("mode", "disabled")
	var mode: int
	match mode_str:
		"disabled":
			mode = Viewport.DEBUG_DRAW_DISABLED
		"unshaded":
			mode = Viewport.DEBUG_DRAW_UNSHADED
		"lighting":
			mode = Viewport.DEBUG_DRAW_LIGHTING
		"overdraw":
			mode = Viewport.DEBUG_DRAW_OVERDRAW
		"wireframe":
			mode = Viewport.DEBUG_DRAW_WIREFRAME
		_:
			return {
				"__error_code__": "INVALID_PARAMS",
				"__error_message__": "Unknown mode '%s'. Use: disabled, unshaded, lighting, overdraw, wireframe" % mode_str,
			}
	get_viewport().debug_draw = mode
	return {"mode": mode_str}


# --- input simulation ---------------------------------------------------------

## Dispatches a single synthesized input event through Input.parse_input_event,
## exactly as if it came from a real device. `params.type` selects the shape:
## "action" (Input.action_press/release by name), "key", "mouse_button", or
## "mouse_motion".
func _simulate_input(params: Dictionary) -> Variant:
	var input_type: String = params.get("type", "")
	match input_type:
		"action":
			var action: String = params.get("action", "")
			if action == "":
				return {"__error_code__": "INVALID_PARAMS", "__error_message__": "action is required"}
			var pressed: bool = bool(params.get("pressed", true))
			if pressed:
				Input.action_press(action, float(params.get("strength", 1.0)))
			else:
				Input.action_release(action)
			return {"type": "action", "action": action, "pressed": pressed}
		"key":
			var event := InputEventKey.new()
			event.keycode = int(params.get("keycode", 0))
			event.pressed = bool(params.get("pressed", true))
			Input.parse_input_event(event)
			return {"type": "key", "keycode": event.keycode, "pressed": event.pressed}
		"mouse_button":
			var event2 := InputEventMouseButton.new()
			event2.button_index = int(params.get("button_index", MOUSE_BUTTON_LEFT))
			event2.pressed = bool(params.get("pressed", true))
			event2.position = _vec2(params.get("position", {}))
			event2.global_position = event2.position
			Input.parse_input_event(event2)
			return {"type": "mouse_button", "button_index": event2.button_index, "pressed": event2.pressed}
		"mouse_motion":
			var event3 := InputEventMouseMotion.new()
			event3.position = _vec2(params.get("position", {}))
			event3.relative = _vec2(params.get("relative", {}))
			Input.parse_input_event(event3)
			return {"type": "mouse_motion", "position": _vec2_to_dict(event3.position)}
		_:
			return {"__error_code__": "INVALID_PARAMS", "__error_message__": "Unknown input type '%s'" % input_type}


func _simulate_sequence_deferred(id: String, params: Dictionary) -> void:
	var steps: Array = params.get("steps", [])
	if steps.is_empty():
		_respond(id, {"__error_code__": "INVALID_PARAMS", "__error_message__": "steps must be a non-empty array"})
		return

	var state := {"index": 0, "wait": float(steps[0].get("delay", 0.0))}
	var executed: Array = []
	var total_timeout := 5.0
	for step in steps:
		total_timeout += float(step.get("delay", 0.0))

	var check := func(delta: float) -> Variant:
		state["wait"] -= delta
		if state["wait"] > 0.0:
			return null
		var step: Dictionary = steps[state["index"]]
		executed.append(_simulate_input(step.get("input", {})))
		state["index"] += 1
		if state["index"] >= steps.size():
			return {"executed": executed}
		state["wait"] = float(steps[state["index"]].get("delay", 0.0))
		return null

	_pending_ops.append({"id": id, "elapsed": 0.0, "timeout": total_timeout, "check": check})


# --- UI introspection ----------------------------------------------------------

func _find_ui(params: Dictionary) -> Dictionary:
	var root := get_tree().current_scene
	if root == null:
		return {"elements": []}
	var elements: Array = []
	_collect_ui(root, root, params.get("text", ""), params.get("class_name", ""), elements)
	return {"elements": elements}


func _describe_screen(_params: Dictionary) -> Dictionary:
	var root := get_tree().current_scene
	if root == null:
		return {"scene": "", "elements": []}
	var elements: Array = []
	_collect_ui(root, root, "", "", elements)
	return {"scene": str(root.name), "elements": elements}


func _collect_ui(node: Node, root: Node, text_filter: String, class_filter: String, out: Array) -> void:
	if node is Control:
		var ok_class: bool = class_filter == "" or node.is_class(class_filter)
		var node_text_val: Variant = node.get("text")
		var node_text: String = str(node_text_val) if node_text_val != null else ""
		var ok_text: bool = text_filter == "" or node_text.findn(text_filter) != -1
		if ok_class and ok_text:
			out.append({
				"node_path": _relative_path(root, node),
				"type": node.get_class(),
				"text": node_text,
				"visible": node.visible,
			})
	for child in node.get_children():
		_collect_ui(child, root, text_filter, class_filter, out)


func _click_ui(params: Dictionary) -> Variant:
	var text: String = params.get("text", "")
	if text == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "text is required"}
	var root := get_tree().current_scene
	if root == null:
		return {"__error_code__": "NO_GAME_RUNNING", "__error_message__": "No current scene in the running game"}

	var matches: Array = []
	_collect_ui(root, root, text, "", matches)
	if matches.is_empty():
		return {"__error_code__": "NODE_NOT_FOUND", "__error_message__": "No UI element with text '%s'" % text}

	var target_path: String = matches[0]["node_path"]
	var target := _resolve({"node_path": target_path})
	if target is Dictionary:
		return target
	if target.has_signal("pressed"):
		target.emit_signal("pressed")
	return {"node_path": target_path, "clicked": true}


# --- input recording -----------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not _recording:
		return
	var serialized := _serialize_input_event(event)
	if serialized != null:
		serialized["delay"] = Time.get_ticks_msec() / 1000.0 - _record_start_time
		_recorded_events.append(serialized)


func _serialize_input_event(event: InputEvent) -> Variant:
	if event is InputEventKey:
		return {"type": "key", "keycode": event.keycode, "pressed": event.pressed}
	if event is InputEventMouseButton:
		return {
			"type": "mouse_button",
			"button_index": event.button_index,
			"pressed": event.pressed,
			"position": _vec2_to_dict(event.position),
		}
	if event is InputEventMouseMotion:
		return {
			"type": "mouse_motion",
			"position": _vec2_to_dict(event.position),
			"relative": _vec2_to_dict(event.relative),
		}
	return null


func _start_input_recording(_params: Dictionary) -> Dictionary:
	_recording = true
	_recorded_events = []
	_record_start_time = Time.get_ticks_msec() / 1000.0
	return {"recording": true}


func _stop_input_recording(_params: Dictionary) -> Dictionary:
	_recording = false
	return {"recording": false, "event_count": _recorded_events.size(), "events": _recorded_events}


## Replays a list of {type, ..., delay} events (as returned by
## game_stop_input_recording) at their recorded relative delays. If `events`
## isn't provided, replays the buffer from the last recording.
func _replay_input_deferred(id: String, params: Dictionary) -> void:
	var raw_events: Array = params.get("events", [])
	var events: Array = raw_events if not raw_events.is_empty() else _recorded_events
	# Each step's "delay" is relative to the previous step, matching
	# game_simulate_sequence's convention; game_stop_input_recording reports
	# elapsed-since-start instead, so normalize here.
	var steps: Array = []
	var last_t := 0.0
	for e in events:
		var t: float = float(e.get("delay", 0.0))
		steps.append({"delay": max(t - last_t, 0.0), "input": e})
		last_t = t

	if steps.is_empty():
		_respond(id, {"replayed": 0})
		return

	# `state` holds every counter mutated across ticks — GDScript lambdas
	# capture bare primitive locals (int/float/bool) by value, so a plain
	# `var replayed := 0` mutated inside the closure would silently reset
	# every call instead of accumulating; a Dictionary's contents mutate
	# through the shared reference correctly instead.
	var state := {"index": 0, "wait": float(steps[0]["delay"]), "replayed": 0}
	var total_timeout := last_t + 5.0

	var check := func(delta: float) -> Variant:
		state["wait"] -= delta
		if state["wait"] > 0.0:
			return null
		_simulate_input(steps[state["index"]]["input"])
		state["replayed"] += 1
		state["index"] += 1
		if state["index"] >= steps.size():
			return {"replayed": state["replayed"]}
		state["wait"] = float(steps[state["index"]]["delay"])
		return null

	_pending_ops.append({"id": id, "elapsed": 0.0, "timeout": total_timeout, "check": check})


# --- waiting / sampling over time ----------------------------------------------

func _wait_for_node_deferred(id: String, params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	if node_path == "":
		_respond(id, {"__error_code__": "INVALID_PARAMS", "__error_message__": "node_path is required"})
		return
	var timeout: float = float(params.get("timeout", 5.0))

	var check := func(_delta: float) -> Variant:
		var root := get_tree().current_scene
		if root == null:
			return null
		var node := root.get_node_or_null(NodePath(node_path))
		if node != null:
			return {"node_path": node_path, "found": true}
		return null

	_pending_ops.append({"id": id, "elapsed": 0.0, "timeout": timeout, "check": check})


func _monitor_property_deferred(id: String, params: Dictionary) -> void:
	var node := _resolve(params)
	if node is Dictionary:
		_respond(id, node)
		return
	var property: String = params.get("property", "")
	if property == "":
		_respond(id, {"__error_code__": "INVALID_PARAMS", "__error_message__": "property is required"})
		return

	var duration: float = float(params.get("duration", 1.0))
	var interval: float = max(float(params.get("interval", 0.1)), 0.01)
	var samples: Array = []
	var state := {"total": 0.0, "since_sample": interval}

	var check := func(delta: float) -> Variant:
		state["total"] += delta
		state["since_sample"] += delta
		if state["since_sample"] >= interval:
			state["since_sample"] = 0.0
			samples.append({"t": state["total"], "value": node.get(property)})
		if state["total"] >= duration:
			return {"property": property, "samples": samples}
		return null

	_pending_ops.append({"id": id, "elapsed": 0.0, "timeout": duration + 2.0, "check": check})


# --- visual capture -------------------------------------------------------------

## Requires an actual rendering backend with a real framebuffer. Under
## `--headless` (the null/dummy rendering driver), the viewport has no pixel
## data to read back and this returns INTERNAL_ERROR rather than a blank image.
func _screenshot(_params: Dictionary) -> Variant:
	var viewport := get_viewport()
	if viewport == null:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "No viewport available"}
	var img: Image = viewport.get_texture().get_image()
	if img == null or img.is_empty():
		return {
			"__error_code__": "INTERNAL_ERROR",
			"__error_message__": "Viewport has no readable pixel data (no rendering backend, e.g. --headless)",
		}
	var png_bytes: PackedByteArray = img.save_png_to_buffer()
	return {"width": img.get_width(), "height": img.get_height(), "png_base64": Marshalls.raw_to_base64(png_bytes)}


## NOTE: this does not encode a real animated .gif file (Godot has no built-in
## GIF encoder and a hand-rolled LZW/GIF89a implementation was judged too much
## risk of subtly-corrupt output for this pass). It captures a PNG at each
## `interval` over `duration` and returns them as a `frames` array of base64
## PNGs instead — same underlying data, just not muxed into a single file.
func _capture_gif_deferred(id: String, params: Dictionary) -> void:
	var duration: float = float(params.get("duration", 1.0))
	var interval: float = max(float(params.get("interval", 0.1)), 0.05)
	var frames: Array = []
	var state := {"total": 0.0, "since_frame": interval}

	var check := func(delta: float) -> Variant:
		state["total"] += delta
		state["since_frame"] += delta
		if state["since_frame"] >= interval:
			state["since_frame"] = 0.0
			var shot: Variant = _screenshot({})
			if typeof(shot) == TYPE_DICTIONARY and not shot.has("__error_code__"):
				frames.append(shot["png_base64"])
		if state["total"] >= duration:
			return {"frame_count": frames.size(), "interval": interval, "frames_png_base64": frames}
		return null

	_pending_ops.append({"id": id, "elapsed": 0.0, "timeout": duration + 2.0, "check": check})


# --- physics --------------------------------------------------------------------

func _raycast_3d(params: Dictionary) -> Variant:
	var root := get_tree().current_scene
	if root == null:
		return {"__error_code__": "NO_GAME_RUNNING", "__error_message__": "No current scene in the running game"}
	# get_world_3d() lives on Viewport, not on Node — root may not even be a
	# Node3D, so go through the probe's own viewport (shared with the game).
	var world: World3D = get_viewport().get_world_3d()
	if world == null:
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "Current scene has no World3D (not a 3D scene?)"}

	var query := PhysicsRayQueryParameters3D.create(_vec3(params.get("from", {})), _vec3(params.get("to", {})))
	if params.has("collision_mask"):
		query.collision_mask = int(params["collision_mask"])

	var result: Dictionary = world.direct_space_state.intersect_ray(query)
	if result.is_empty():
		return {"hit": false}

	var collider: Variant = result.get("collider")
	return {
		"hit": true,
		"position": _vec3_to_dict(result.get("position", Vector3())),
		"normal": _vec3_to_dict(result.get("normal", Vector3())),
		"collider_path": _relative_path(root, collider) if collider is Node else "",
	}


## Works for Area2D/Area3D (overlap queries) and any body with contact_monitor
## enabled (RigidBody2D/3D's get_colliding_bodies()). Other node types have no
## collision data to report and return INVALID_PARAMS.
func _get_collision_report(params: Dictionary) -> Variant:
	var node := _resolve(params)
	if node is Dictionary:
		return node
	var root: Node = get_tree().current_scene

	if node is Area2D or node is Area3D:
		var bodies: Array = node.get_overlapping_bodies()
		var areas: Array = node.get_overlapping_areas()
		return {
			"overlapping_bodies": bodies.map(func(b): return _relative_path(root, b) if b is Node else str(b)),
			"overlapping_areas": areas.map(func(a): return _relative_path(root, a) if a is Node else str(a)),
		}

	if node.has_method("get_colliding_bodies"):
		var colliding: Array = node.get_colliding_bodies()
		return {"colliding_bodies": colliding.map(func(b): return _relative_path(root, b) if b is Node else str(b))}

	return {
		"__error_code__": "INVALID_PARAMS",
		"__error_message__": "%s has no collision data (expected Area2D/3D, or a body with contact_monitor enabled)" % node.get_class(),
	}
