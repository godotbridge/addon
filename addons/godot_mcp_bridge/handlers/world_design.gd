## Handlers for the world_design tool category.
class_name GodotMCPWorldDesignHandlers
extends RefCounted

const NodeResolver = preload("res://addons/godot_mcp_bridge/utils/node_resolver.gd")

const EXPORT_PRESETS_PATH := "res://export_presets.cfg"


static func register(dispatch: Dictionary) -> void:
	dispatch["tilemap_paint_terrain"] = tilemap_paint_terrain
	dispatch["paint_gridmap_region"] = paint_gridmap_region
	dispatch["add_day_night_cycle"] = add_day_night_cycle
	dispatch["add_minimap"] = add_minimap
	dispatch["create_export_preset"] = create_export_preset
	dispatch["add_translation"] = add_translation
	dispatch["set_locale"] = set_locale
	dispatch["align_nodes"] = align_nodes
	dispatch["distribute_nodes"] = distribute_nodes
	dispatch["import_external_asset"] = import_external_asset


static func _vec2i(d: Dictionary) -> Vector2i:
	return Vector2i(int(d.get("x", 0)), int(d.get("y", 0)))


static func _vec3i(d: Dictionary) -> Vector3i:
	return Vector3i(int(d.get("x", 0)), int(d.get("y", 0)), int(d.get("z", 0)))


static func tilemap_paint_terrain(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if not (node is TileMap):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s is not a TileMap" % node.get_class()}

	var layer: int = int(params.get("layer", 0))
	var terrain_set: int = int(params.get("terrain_set", 0))
	var terrain: int = int(params.get("terrain", 0))
	var cells: Array[Vector2i] = []
	for c in params.get("cells", []):
		cells.append(_vec2i(c))

	node.set_cells_terrain_connect(layer, cells, terrain_set, terrain, true)
	return {"node_path": params.get("node_path", ""), "layer": layer, "painted": cells.size()}


static func paint_gridmap_region(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if not (node is GridMap):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s is not a GridMap" % node.get_class()}

	var from := _vec3i(params.get("from", {}))
	var to := _vec3i(params.get("to", {}))
	var item: int = int(params.get("item", -1))

	var painted := 0
	for x in range(min(from.x, to.x), max(from.x, to.x) + 1):
		for y in range(min(from.y, to.y), max(from.y, to.y) + 1):
			for z in range(min(from.z, to.z), max(from.z, to.z) + 1):
				node.set_cell_item(Vector3i(x, y, z), item)
				painted += 1
	return {"node_path": params.get("node_path", ""), "painted": painted}


## Scaffolds a rotating DirectionalLight3D + an AnimationPlayer looping its
## rotation over `duration` seconds — the simplest real "day/night" rig
## (swap in a WorldEnvironment/sky gradient separately for visual polish).
static func add_day_night_cycle(params: Dictionary, ei: EditorInterface) -> Variant:
	var parent := NodeResolver.resolve(params, ei, "parent_path")
	if parent is Dictionary:
		return parent
	var root: Node = ei.get_edited_scene_root()

	var light := NodeResolver.add_child_node(parent, root, "DirectionalLight3D", params.get("light_name", "Sun"))
	if light is Dictionary:
		return light
	var player := NodeResolver.add_child_node(parent, root, "AnimationPlayer", params.get("node_name", "DayNightCycle"))
	if player is Dictionary:
		return player

	var duration: float = float(params.get("duration", 60.0))
	var animation := Animation.new()
	animation.length = duration
	animation.loop_mode = Animation.LOOP_LINEAR
	var track: int = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath("%s:rotation_degrees:y" % light.name))
	animation.track_insert_key(track, 0.0, 0.0)
	animation.track_insert_key(track, duration, 360.0)

	var lib := AnimationLibrary.new()
	lib.add_animation("day_night_cycle", animation)
	player.add_animation_library("", lib)

	return {
		"light_path": NodeResolver.relative_path(root, light),
		"player_path": NodeResolver.relative_path(root, player),
		"duration": duration,
	}


## A real (if basic) minimap rig: a small SubViewport rendering a top-down
## Camera2D, displayed via a TextureRect. Point the camera's parent at
## whatever the caller wants centered (e.g. reparent it under the player).
static func add_minimap(params: Dictionary, ei: EditorInterface) -> Variant:
	var parent := NodeResolver.resolve(params, ei, "parent_path")
	if parent is Dictionary:
		return parent
	var root: Node = ei.get_edited_scene_root()

	var size: Dictionary = params.get("size", {"x": 200, "y": 200})
	var viewport_size := Vector2i(int(size.get("x", 200)), int(size.get("y", 200)))

	var container := NodeResolver.add_child_node(parent, root, "SubViewportContainer", params.get("node_name", "Minimap"))
	if container is Dictionary:
		return container
	# stretch=true makes the child SubViewport's size follow the container's
	# own rect automatically — setting viewport.size directly afterward
	# fights that and logs "Can't change the size of a SubViewport with a
	# SubViewportContainer parent that has stretch enabled" (confirmed via a
	# real add_minimap call). Size the container itself instead; stretch
	# propagates it to the viewport.
	container.custom_minimum_size = Vector2(viewport_size)
	container.stretch = true

	var viewport := NodeResolver.add_child_node(container, root, "SubViewport", "Viewport")
	if viewport is Dictionary:
		return viewport

	var camera := NodeResolver.add_child_node(viewport, root, "Camera2D", "MinimapCamera")
	if camera is Dictionary:
		return camera
	camera.zoom = Vector2(float(params.get("zoom", 0.2)), float(params.get("zoom", 0.2)))

	return {
		"container_path": NodeResolver.relative_path(root, container),
		"camera_path": NodeResolver.relative_path(root, camera),
	}


static func create_export_preset(params: Dictionary, _ei: EditorInterface) -> Variant:
	var preset_name: String = params.get("name", "")
	var platform: String = params.get("platform", "")
	if preset_name == "" or platform == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "name and platform are required"}

	var cfg := ConfigFile.new()
	if FileAccess.file_exists(EXPORT_PRESETS_PATH):
		cfg.load(EXPORT_PRESETS_PATH)

	var index := 0
	while cfg.has_section("preset.%d" % index):
		index += 1

	var section := "preset.%d" % index
	cfg.set_value(section, "name", preset_name)
	cfg.set_value(section, "platform", platform)
	cfg.set_value(section, "runnable", true)
	cfg.set_value(section, "export_path", params.get("export_path", ""))
	# Godot's own export code reads this with no fallback default and
	# ERRORs (loudly, though not always fatally) if it's absent — confirmed
	# empirically via a real export attempt against a preset this tool created
	# without it. "all_resources" is the universal, always-valid default.
	cfg.set_value(section, "export_filter", "all_resources")
	cfg.set_value(section, "include_filter", "")
	cfg.set_value(section, "exclude_filter", "")

	# Every platform preset the editor itself creates also has a matching
	# "<section>.options" section — the editor reads it unconditionally on
	# startup (get_section_keys with no has_section guard) and logs "Cannot
	# get keys from nonexistent section" if it's missing entirely. There's no
	# scriptable API to enumerate a platform's real per-platform export
	# options (see build_export.gd's notes on this), but custom_template/debug
	# and custom_template/release exist across every platform and are enough
	# to make the section exist and silence the startup error.
	var options_section := "%s.options" % section
	cfg.set_value(options_section, "custom_template/debug", "")
	cfg.set_value(options_section, "custom_template/release", "")

	var err: Error = cfg.save(EXPORT_PRESETS_PATH)
	if err != OK:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Could not save export_presets.cfg: %s" % error_string(err)}
	return {"index": index, "name": preset_name, "platform": platform}


static func add_translation(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "" or not FileAccess.file_exists(path):
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No translation resource at %s" % path}

	var current: PackedStringArray = ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray())
	var list_array: Array = Array(current)
	if not list_array.has(path):
		list_array.append(path)
	var new_list := PackedStringArray(list_array)
	ProjectSettings.set_setting("internationalization/locale/translations", new_list)
	ProjectSettings.save()
	return {"path": path, "translations": Array(new_list)}


static func set_locale(params: Dictionary, _ei: EditorInterface) -> Variant:
	var locale: String = params.get("locale", "")
	if locale == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "locale is required"}

	ProjectSettings.set_setting("internationalization/locale/locale", locale)
	ProjectSettings.save()
	TranslationServer.set_locale(locale)
	return {"locale": TranslationServer.get_locale()}


static func _resolve_many(params: Dictionary, ei: EditorInterface) -> Variant:
	var root: Node = ei.get_edited_scene_root()
	if root == null:
		return {"__error_code__": "SCENE_NOT_FOUND", "__error_message__": "No scene is currently open in the editor"}
	var node_paths: Array = params.get("node_paths", [])
	if node_paths.size() < 2:
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "node_paths needs at least 2 nodes"}

	var nodes: Array = []
	for node_path in node_paths:
		var node := NodeResolver.get_node(root, node_path)
		if node == null:
			return {"__error_code__": "NODE_NOT_FOUND", "__error_message__": "No node at path %s" % node_path}
		if not (node is Node2D or node is Control):
			return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s is not a Node2D or Control" % node.get_class()}
		nodes.append(node)
	return nodes


static func _get_axis_value(node: Node, axis: String) -> float:
	var pos: Vector2 = node.position
	return pos.x if axis == "x" else pos.y


static func _set_axis_value(node: Node, axis: String, value: float) -> void:
	if axis == "x":
		node.position.x = value
	else:
		node.position.y = value


static func align_nodes(params: Dictionary, ei: EditorInterface) -> Variant:
	var nodes := _resolve_many(params, ei)
	if nodes is Dictionary:
		return nodes

	var axis: String = params.get("axis", "x")
	var align_to: String = params.get("align_to", "first")

	var values: Array = []
	for node in nodes:
		values.append(_get_axis_value(node, axis))

	var target: float
	match align_to:
		"min":
			target = values.min()
		"max":
			target = values.max()
		"average":
			var total := 0.0
			for v in values:
				total += v
			target = total / values.size()
		_:
			target = values[0]

	for node in nodes:
		_set_axis_value(node, axis, target)

	return {"axis": axis, "align_to": align_to, "value": target, "count": nodes.size()}


static func distribute_nodes(params: Dictionary, ei: EditorInterface) -> Variant:
	var nodes := _resolve_many(params, ei)
	if nodes is Dictionary:
		return nodes

	var axis: String = params.get("axis", "x")
	nodes.sort_custom(func(a, b): return _get_axis_value(a, axis) < _get_axis_value(b, axis))

	var start: float = _get_axis_value(nodes[0], axis)
	var spacing: float
	if params.has("spacing"):
		spacing = float(params["spacing"])
	else:
		var end: float = _get_axis_value(nodes[-1], axis)
		spacing = (end - start) / (nodes.size() - 1) if nodes.size() > 1 else 0.0

	for i in range(nodes.size()):
		_set_axis_value(nodes[i], axis, start + spacing * i)

	return {"axis": axis, "spacing": spacing, "count": nodes.size()}


static func import_external_asset(params: Dictionary, ei: EditorInterface) -> Variant:
	var source_path: String = params.get("source_path", "")
	var dest_path: String = params.get("dest_path", "")
	if source_path == "" or dest_path == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "source_path and dest_path are required"}
	if not FileAccess.file_exists(source_path):
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No file at %s" % source_path}
	if FileAccess.file_exists(dest_path):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "A file already exists at %s" % dest_path}

	var err: Error = DirAccess.copy_absolute(ProjectSettings.globalize_path(source_path), ProjectSettings.globalize_path(dest_path))
	if err != OK:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Could not copy file: %s" % error_string(err)}

	var fs := ei.get_resource_filesystem()
	fs.update_file(dest_path)
	fs.reimport_files([dest_path])

	return {"dest_path": dest_path}
