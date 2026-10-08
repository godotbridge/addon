## Handlers for the animation_systems tool category. Animation tools operate
## on an AnimationPlayer's default ("") AnimationLibrary — Godot 4 requires
## animations to live in a library, unlike 3.x's flat list.
class_name GodotMCPAnimationSystemsHandlers
extends RefCounted

const NodeResolver = preload("res://addons/godot_mcp_bridge/utils/node_resolver.gd")

const TRACK_TYPES := {
	"value": Animation.TYPE_VALUE,
	"method": Animation.TYPE_METHOD,
	"bezier": Animation.TYPE_BEZIER,
}


static func register(dispatch: Dictionary) -> void:
	dispatch["add_sprite_frames"] = add_sprite_frames
	dispatch["create_animation"] = create_animation
	dispatch["list_animations"] = list_animations
	dispatch["rename_animation"] = rename_animation
	dispatch["remove_animation"] = remove_animation
	dispatch["get_animation_info"] = get_animation_info
	dispatch["add_animation_track"] = add_animation_track
	dispatch["set_animation_keyframe"] = set_animation_keyframe
	dispatch["add_tween_animation"] = add_tween_animation
	dispatch["create_animation_tree"] = create_animation_tree
	dispatch["add_animation_state"] = add_animation_state
	dispatch["add_animation_transition"] = add_animation_transition
	dispatch["get_animation_tree_info"] = get_animation_tree_info
	dispatch["add_animation_blend_node"] = add_animation_blend_node
	dispatch["connect_animation_blend_nodes"] = connect_animation_blend_nodes
	dispatch["remove_animation_blend_node"] = remove_animation_blend_node
	dispatch["configure_animation_track"] = configure_animation_track
	dispatch["list_animation_tracks"] = list_animation_tracks
	dispatch["set_animation_keyframes"] = set_animation_keyframes
	dispatch["remove_animation_keyframe"] = remove_animation_keyframe
	dispatch["remove_animation_track"] = remove_animation_track


static func _get_player(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if not (node is AnimationPlayer):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s is not an AnimationPlayer" % node.get_class()}
	return node


static func _get_or_create_library(player: AnimationPlayer) -> AnimationLibrary:
	if player.has_animation_library(""):
		return player.get_animation_library("")
	var lib := AnimationLibrary.new()
	player.add_animation_library("", lib)
	return lib


static func _get_animation(player: AnimationPlayer, animation_name: String) -> Variant:
	if not player.has_animation(animation_name):
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No animation named '%s'" % animation_name}
	return player.get_animation(animation_name)


static func create_animation(params: Dictionary, ei: EditorInterface) -> Variant:
	var player := _get_player(params, ei)
	if player is Dictionary:
		return player
	var animation_name: String = params.get("animation_name", "")
	if animation_name == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "animation_name is required"}
	if player.has_animation(animation_name):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "Animation '%s' already exists" % animation_name}

	var animation := Animation.new()
	animation.length = float(params.get("length", 1.0))
	var lib := _get_or_create_library(player)
	lib.add_animation(animation_name, animation)
	return {"node_path": params.get("node_path", ""), "animation_name": animation_name, "length": animation.length}


static func list_animations(params: Dictionary, ei: EditorInterface) -> Variant:
	var player := _get_player(params, ei)
	if player is Dictionary:
		return player
	return {"animations": Array(player.get_animation_list())}


static func rename_animation(params: Dictionary, ei: EditorInterface) -> Variant:
	var player := _get_player(params, ei)
	if player is Dictionary:
		return player
	var old_name: String = params.get("old_name", "")
	var new_name: String = params.get("new_name", "")
	if not player.has_animation(old_name):
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No animation named '%s'" % old_name}
	var lib := _get_or_create_library(player)
	lib.rename_animation(old_name, new_name)
	return {"node_path": params.get("node_path", ""), "old_name": old_name, "new_name": new_name}


static func remove_animation(params: Dictionary, ei: EditorInterface) -> Variant:
	var player := _get_player(params, ei)
	if player is Dictionary:
		return player
	var animation_name: String = params.get("animation_name", "")
	if not player.has_animation(animation_name):
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No animation named '%s'" % animation_name}
	var lib := _get_or_create_library(player)
	lib.remove_animation(animation_name)
	return {"node_path": params.get("node_path", ""), "animation_name": animation_name}


static func get_animation_info(params: Dictionary, ei: EditorInterface) -> Variant:
	var player := _get_player(params, ei)
	if player is Dictionary:
		return player
	var animation_name: String = params.get("animation_name", "")
	var animation := _get_animation(player, animation_name)
	if animation is Dictionary:
		return animation
	return {
		"animation_name": animation_name,
		"length": animation.length,
		"loop_mode": animation.loop_mode,
		"track_count": animation.get_track_count(),
	}


static func add_animation_track(params: Dictionary, ei: EditorInterface) -> Variant:
	var player := _get_player(params, ei)
	if player is Dictionary:
		return player
	var animation_name: String = params.get("animation_name", "")
	var animation := _get_animation(player, animation_name)
	if animation is Dictionary:
		return animation

	var track_type_name: String = params.get("track_type", "value")
	if not TRACK_TYPES.has(track_type_name):
		return {
			"__error_code__": "INVALID_PARAMS",
			"__error_message__": "Unknown track_type '%s'. Available: %s" % [track_type_name, ", ".join(TRACK_TYPES.keys())],
		}
	var track_path: String = params.get("track_path", "")
	if track_path == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "track_path is required"}

	var track_index: int = animation.add_track(TRACK_TYPES[track_type_name])
	animation.track_set_path(track_index, NodePath(track_path))
	return {"animation_name": animation_name, "track_index": track_index, "track_path": track_path, "track_type": track_type_name}


static func set_animation_keyframe(params: Dictionary, ei: EditorInterface) -> Variant:
	var player := _get_player(params, ei)
	if player is Dictionary:
		return player
	var animation_name: String = params.get("animation_name", "")
	var animation := _get_animation(player, animation_name)
	if animation is Dictionary:
		return animation

	var track_index: int = int(params.get("track_index", -1))
	if track_index < 0 or track_index >= animation.get_track_count():
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "No track at index %d" % track_index}

	var time: float = float(params.get("time", 0.0))
	var key_index: int = animation.track_insert_key(track_index, time, params.get("value"))
	return {"animation_name": animation_name, "track_index": track_index, "time": time, "key_index": key_index}


## Bakes a simple property interpolation directly into the animation as a
## value track with two keyframes (from_value at t=0, to_value at t=duration)
## — Godot's runtime Tween class is created imperatively in code and has no
## editor-time resource form to author here, so this is the closest
## equivalent achievable through the Animation resource system.
static func add_tween_animation(params: Dictionary, ei: EditorInterface) -> Variant:
	var player := _get_player(params, ei)
	if player is Dictionary:
		return player
	var animation_name: String = params.get("animation_name", "")
	var animation := _get_animation(player, animation_name)
	if animation is Dictionary:
		return animation

	var track_path: String = params.get("track_path", "")
	if track_path == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "track_path is required"}
	var duration: float = float(params.get("duration", 1.0))

	var track_index: int = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track_index, NodePath(track_path))
	animation.track_insert_key(track_index, 0.0, params.get("from_value"))
	animation.track_insert_key(track_index, duration, params.get("to_value"))
	if duration > animation.length:
		animation.length = duration

	return {"animation_name": animation_name, "track_index": track_index, "track_path": track_path, "duration": duration}


## "Creates multi-animation sprite sheet setups": builds a SpriteFrames
## resource from `animations`: {anim_name: {frames: [texture_path, ...], fps: number}}.
static func add_sprite_frames(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "path is required"}
	if FileAccess.file_exists(path):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "A resource already exists at %s" % path}

	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var animations: Dictionary = params.get("animations", {})
	for anim_name in animations.keys():
		var config: Dictionary = animations[anim_name]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, float(config.get("fps", 5.0)))
		frames.set_animation_loop(anim_name, bool(config.get("loop", true)))
		for texture_path in config.get("frames", []):
			var texture: Variant = load(String(texture_path))
			if not (texture is Texture2D):
				return {
					"__error_code__": "RESOURCE_NOT_FOUND",
					"__error_message__": "%s is not a Texture2D resource (loaded as %s)" % [texture_path, texture.get_class() if texture != null else "null"],
				}
			frames.add_frame(anim_name, texture)

	var err: Error = ResourceSaver.save(frames, path)
	if err != OK:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Could not save SpriteFrames: %s" % error_string(err)}
	return {"path": path, "animations": animations.keys()}


# --- AnimationTree / state machines -----------------------------------------

static func create_animation_tree(params: Dictionary, ei: EditorInterface) -> Variant:
	var parent := NodeResolver.resolve(params, ei, "parent_path")
	if parent is Dictionary:
		return parent
	var root: Node = ei.get_edited_scene_root()
	var tree := NodeResolver.add_child_node(parent, root, "AnimationTree", params.get("node_name", ""))
	if tree is Dictionary:
		return tree

	tree.tree_root = AnimationNodeStateMachine.new()
	if params.has("anim_player_path"):
		tree.anim_player = NodePath(String(params["anim_player_path"]))
	tree.active = bool(params.get("active", true))

	return {"node_path": NodeResolver.relative_path(root, tree), "type": "AnimationTree"}


static func _get_state_machine(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if not (node is AnimationTree):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s is not an AnimationTree" % node.get_class()}
	if not (node.tree_root is AnimationNodeStateMachine):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "AnimationTree's tree_root is not an AnimationNodeStateMachine"}
	return node.tree_root


static func add_animation_state(params: Dictionary, ei: EditorInterface) -> Variant:
	var state_machine := _get_state_machine(params, ei)
	if state_machine is Dictionary:
		return state_machine

	var state_name: String = params.get("state_name", "")
	if state_name == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "state_name is required"}

	var state_node := AnimationNodeAnimation.new()
	if params.has("animation_name"):
		state_node.animation = String(params["animation_name"])
	state_machine.add_node(state_name, state_node)
	return {"node_path": params.get("node_path", ""), "state_name": state_name}


static func add_animation_transition(params: Dictionary, ei: EditorInterface) -> Variant:
	var state_machine := _get_state_machine(params, ei)
	if state_machine is Dictionary:
		return state_machine

	var from_state: String = params.get("from_state", "")
	var to_state: String = params.get("to_state", "")
	if from_state == "" or to_state == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "from_state and to_state are required"}

	var transition := AnimationNodeStateMachineTransition.new()
	if params.has("switch_mode"):
		transition.switch_mode = int(params["switch_mode"])
	state_machine.add_transition(from_state, to_state, transition)
	return {"node_path": params.get("node_path", ""), "from_state": from_state, "to_state": to_state}


## AnimationNodeStateMachine has no get_node_list()/get_state_list() method
## (confirmed empirically — has_method() returns false, and calling it
## anyway aborts the function with a silent null return, not a catchable
## error). It does expose each state as a virtual property "states/<name>/
## node" (visible via get_property_list(), the same mechanism the editor's
## own state machine graph UI reads) — parse those instead. Includes the
## built-in "Start"/"End" states alongside any added via add_animation_state.
static func get_animation_tree_info(params: Dictionary, ei: EditorInterface) -> Variant:
	var state_machine := _get_state_machine(params, ei)
	if state_machine is Dictionary:
		return state_machine
	var states: Array = []
	for prop in state_machine.get_property_list():
		var name: String = String(prop.get("name", ""))
		if name.begins_with("states/") and name.ends_with("/node"):
			states.append(name.trim_prefix("states/").trim_suffix("/node"))
	return {"states": states}


## A dict of lambdas (the previous version of this constant) evaluates to an
## empty dict at runtime — confirmed empirically: BLEND_NODE_TYPES.keys() came
## back empty despite the literal listing 11 entries, causing every call here
## to fail with "Unknown blend_node_type" no matter what was passed. GDScript
## static var initializers don't reliably support lambda values in a
## container literal. A plain name list + ClassDB.instantiate (the same
## pattern PRIMITIVE_MESH_TYPES etc. use elsewhere in this addon) sidesteps
## it entirely.
const BLEND_NODE_TYPES := [
	"BlendTree", "BlendSpace1D", "BlendSpace2D", "Add2", "Add3",
	"Blend2", "Blend3", "OneShot", "TimeScale", "TimeSeek", "Transition",
]


static func add_animation_blend_node(params: Dictionary, ei: EditorInterface) -> Variant:
	var state_machine := _get_state_machine(params, ei)
	if state_machine is Dictionary:
		return state_machine
	var blend_node_name: String = params.get("blend_node_name", "")
	var blend_node_type: String = params.get("blend_node_type", "")
	if blend_node_name == "" or blend_node_type == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "blend_node_name and blend_node_type are required"}
	if not BLEND_NODE_TYPES.has(blend_node_type):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "Unknown blend_node_type '%s'. Available: %s" % [blend_node_type, ", ".join(BLEND_NODE_TYPES)]}
	var node: AnimationNode = ClassDB.instantiate("AnimationNode%s" % blend_node_type)
	state_machine.add_node(blend_node_name, node)
	return {"node_path": params.get("node_path", ""), "blend_node_name": blend_node_name, "blend_node_type": blend_node_type}


static func connect_animation_blend_nodes(params: Dictionary, ei: EditorInterface) -> Variant:
	var state_machine := _get_state_machine(params, ei)
	if state_machine is Dictionary:
		return state_machine
	var from_node: String = params.get("from_node", "")
	var to_node: String = params.get("to_node", "")
	if from_node == "" or to_node == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "from_node and to_node are required"}
	var transition := AnimationNodeStateMachineTransition.new()
	state_machine.add_transition(from_node, to_node, transition)
	return {"from_node": from_node, "to_node": to_node}


static func remove_animation_blend_node(params: Dictionary, ei: EditorInterface) -> Variant:
	var state_machine := _get_state_machine(params, ei)
	if state_machine is Dictionary:
		return state_machine
	var blend_node_name: String = params.get("blend_node_name", "")
	if blend_node_name == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "blend_node_name is required"}
	if not state_machine.has_node(blend_node_name):
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No node named '%s'" % blend_node_name}
	state_machine.remove_node(blend_node_name)
	return {"removed": true}


static func configure_animation_track(params: Dictionary, ei: EditorInterface) -> Variant:
	var player := _get_player(params, ei)
	if player is Dictionary:
		return player
	var animation_name: String = params.get("animation_name", "")
	var animation := _get_animation(player, animation_name)
	if animation is Dictionary:
		return animation
	var track_index: int = int(params.get("track_index", -1))
	if track_index < 0 or track_index >= animation.get_track_count():
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "No track at index %d" % track_index}
	if params.has("interpolation_type"):
		animation.track_set_interpolation_type(track_index, int(params["interpolation_type"]))
	if params.has("update_mode"):
		animation.value_track_set_update_mode(track_index, int(params["update_mode"]))
	if params.has("loop_wrap"):
		animation.track_set_interpolation_loop_wrap(track_index, bool(params["loop_wrap"]))
	if params.has("enabled"):
		animation.track_set_enabled(track_index, bool(params["enabled"]))
	return {"track_index": track_index, "configured": true}


static func list_animation_tracks(params: Dictionary, ei: EditorInterface) -> Variant:
	var player := _get_player(params, ei)
	if player is Dictionary:
		return player
	var animation_name: String = params.get("animation_name", "")
	var animation := _get_animation(player, animation_name)
	if animation is Dictionary:
		return animation
	var tracks: Array = []
	for i in range(animation.get_track_count()):
		tracks.append({
			"index": i,
			"path": str(animation.track_get_path(i)),
			"type": animation.track_get_type(i),
			"key_count": animation.track_get_key_count(i),
			"enabled": animation.track_is_enabled(i),
		})
	return {"tracks": tracks}


static func set_animation_keyframes(params: Dictionary, ei: EditorInterface) -> Variant:
	var player := _get_player(params, ei)
	if player is Dictionary:
		return player
	var animation_name: String = params.get("animation_name", "")
	var animation := _get_animation(player, animation_name)
	if animation is Dictionary:
		return animation
	var track_index: int = int(params.get("track_index", -1))
	if track_index < 0 or track_index >= animation.get_track_count():
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "No track at index %d" % track_index}
	var keyframes: Array = params.get("keyframes", [])
	var count := 0
	for kf in keyframes:
		animation.track_insert_key(track_index, float(kf.get("time", 0.0)), kf.get("value"))
		count += 1
	return {"animation_name": animation_name, "track_index": track_index, "keys_inserted": count}


static func remove_animation_keyframe(params: Dictionary, ei: EditorInterface) -> Variant:
	var player := _get_player(params, ei)
	if player is Dictionary:
		return player
	var animation_name: String = params.get("animation_name", "")
	var animation := _get_animation(player, animation_name)
	if animation is Dictionary:
		return animation
	var track_index: int = int(params.get("track_index", -1))
	if track_index < 0 or track_index >= animation.get_track_count():
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "No track at index %d" % track_index}
	var key_index: int = int(params.get("key_index", -1))
	if key_index < 0 or key_index >= animation.track_get_key_count(track_index):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "No key at index %d" % key_index}
	animation.track_remove_key(track_index, key_index)
	return {"removed": true}


static func remove_animation_track(params: Dictionary, ei: EditorInterface) -> Variant:
	var player := _get_player(params, ei)
	if player is Dictionary:
		return player
	var animation_name: String = params.get("animation_name", "")
	var animation := _get_animation(player, animation_name)
	if animation is Dictionary:
		return animation
	var track_index: int = int(params.get("track_index", -1))
	if track_index < 0 or track_index >= animation.get_track_count():
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "No track at index %d" % track_index}
	animation.remove_track(track_index)
	return {"removed": true}
