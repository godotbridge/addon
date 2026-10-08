## Handlers for the resource_authoring tool category (basic subset for Phase 1).
class_name GodotMCPResourceAuthoringHandlers
extends RefCounted


static func register(dispatch: Dictionary) -> void:
	dispatch["create_resource"] = create_resource
	dispatch["edit_resource"] = edit_resource
	dispatch["read_resource"] = read_resource
	dispatch["add_curve"] = add_curve
	dispatch["add_gradient"] = add_gradient
	dispatch["set_curve_points"] = set_curve_points
	dispatch["set_gradient_points"] = set_gradient_points
	dispatch["configure_sprite_frames"] = configure_sprite_frames
	dispatch["get_curve_info"] = get_curve_info
	dispatch["get_gradient_info"] = get_gradient_info
	dispatch["get_sprite_frames_info"] = get_sprite_frames_info
	dispatch["get_tileset_info"] = get_tileset_info


static func create_resource(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	var resource_type: String = params.get("resource_type", "")
	if path == "" or resource_type == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "path and resource_type are required"}
	if FileAccess.file_exists(path):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "A resource already exists at %s" % path}

	var res: Resource = ClassDB.instantiate(resource_type)
	if res == null:
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "Unknown resource class %s" % resource_type}

	var properties: Dictionary = params.get("properties", {})
	for property in properties.keys():
		res.set(property, properties[property])

	var err: Error = ResourceSaver.save(res, path)
	if err != OK:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Could not save resource: %s" % error_string(err)}
	return {"path": path, "type": resource_type}


static func edit_resource(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "" or not FileAccess.file_exists(path):
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No resource at %s" % path}
	var res: Resource = load(path)
	if res == null:
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "Could not load resource at %s" % path}

	var properties: Dictionary = params.get("properties", {})
	for property in properties.keys():
		res.set(property, properties[property])

	var err: Error = ResourceSaver.save(res, path)
	if err != OK:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Could not save resource: %s" % error_string(err)}
	return {"path": path, "properties": properties.keys()}


static func read_resource(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "" or not FileAccess.file_exists(path):
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No resource at %s" % path}
	var res: Resource = load(path)
	if res == null:
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "Could not load resource at %s" % path}

	var properties := {}
	for prop in res.get_property_list():
		var name: String = prop.get("name", "")
		if name != "" and (prop.get("usage", 0) & PROPERTY_USAGE_STORAGE):
			properties[name] = res.get(name)

	return {"path": path, "type": res.get_class(), "properties": properties}


static func add_curve(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "path is required"}
	var curve := Curve.new()
	var points: Array = params.get("points", [])
	for p in points:
		curve.add_point(
			Vector2(float(p.get("position", 0.0)), float(p.get("value", 0.0))),
			float(p.get("left_tangent", 0.0)),
			float(p.get("right_tangent", 0.0))
		)
	var err := ResourceSaver.save(curve, path)
	if err != OK:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Could not save Curve: %s" % error_string(err)}
	return {"path": path}


## Gradient has no clear_points() and always keeps at least one point — a
## naive "remove until count == 0" loop never terminates once exactly one
## point is left, hanging the whole editor process (confirmed empirically:
## set_gradient_points's old version of this same pattern froze the entire
## bridge, not just that one call, since Godot's main thread never got back
## to polling the WebSocket). Reduce to exactly one point instead, repurpose
## it as the first new point, then append the rest. Shared by add_gradient
## and set_gradient_points.
static func _replace_gradient_points(gradient: Gradient, points: Array) -> void:
	while gradient.get_point_count() > 1:
		gradient.remove_point(gradient.get_point_count() - 1)
	if points.is_empty():
		return
	var first: Dictionary = points[0]
	gradient.set_offset(0, float(first.get("offset", 0.0)))
	gradient.set_color(0, Color(String(first.get("color", "#ffffff"))))
	for i in range(1, points.size()):
		var p: Dictionary = points[i]
		gradient.add_point(float(p.get("offset", 0.0)), Color(String(p.get("color", "#ffffff"))))


static func add_gradient(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "path is required"}
	var gradient := Gradient.new()
	var points: Array = params.get("points", [])
	_replace_gradient_points(gradient, points)
	var err := ResourceSaver.save(gradient, path)
	if err != OK:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Could not save Gradient: %s" % error_string(err)}
	return {"path": path}


static func set_curve_points(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "" or not FileAccess.file_exists(path):
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No resource at %s" % path}
	var res: Resource = load(path)
	if not (res is Curve):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "Resource at %s is not a Curve" % path}
	var curve: Curve = res
	curve.clear_points()
	var points: Array = params.get("points", [])
	for p in points:
		curve.add_point(
			Vector2(float(p.get("position", 0.0)), float(p.get("value", 0.0))),
			float(p.get("left_tangent", 0.0)),
			float(p.get("right_tangent", 0.0))
		)
	ResourceSaver.save(curve, path)
	return {"path": path, "point_count": curve.point_count}


static func set_gradient_points(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "" or not FileAccess.file_exists(path):
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No resource at %s" % path}
	var res: Resource = load(path)
	if not (res is Gradient):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "Resource at %s is not a Gradient" % path}
	var gradient: Gradient = res
	var points: Array = params.get("points", [])
	_replace_gradient_points(gradient, points)
	ResourceSaver.save(gradient, path)
	return {"path": path, "point_count": gradient.get_point_count()}


static func configure_sprite_frames(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "" or not FileAccess.file_exists(path):
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No resource at %s" % path}
	var res: Resource = load(path)
	if not (res is SpriteFrames):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "Resource at %s is not a SpriteFrames" % path}
	var frames: SpriteFrames = res

	var remove_anims: Array = params.get("remove_animations", [])
	for anim_name in remove_anims:
		if frames.has_animation(String(anim_name)):
			frames.remove_animation(String(anim_name))

	var add_anims: Array = params.get("add_animations", [])
	for config in add_anims:
		var anim_name: String = String(config.get("name", ""))
		if anim_name == "":
			continue
		if not frames.has_animation(anim_name):
			frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, float(config.get("fps", 5.0)))
		frames.set_animation_loop(anim_name, bool(config.get("loop", true)))
		for texture_path in config.get("frames", []):
			var texture: Variant = load(String(texture_path))
			if texture is Texture2D:
				frames.add_frame(anim_name, texture)

	var set_fps: Dictionary = params.get("set_fps", {})
	for anim_name in set_fps.keys():
		if frames.has_animation(String(anim_name)):
			frames.set_animation_speed(String(anim_name), float(set_fps[anim_name]))

	ResourceSaver.save(frames, path)
	return {"path": path, "animations": Array(frames.get_animation_names())}


static func get_curve_info(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "" or not FileAccess.file_exists(path):
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No resource at %s" % path}
	var res: Resource = load(path)
	if not (res is Curve):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "Resource at %s is not a Curve" % path}
	var curve: Curve = res
	var points: Array = []
	for i in range(curve.point_count):
		points.append({
			"position": curve.get_point_position(i).x,
			"value": curve.get_point_position(i).y,
			"left_tangent": curve.get_point_left_tangent(i),
			"right_tangent": curve.get_point_right_tangent(i),
		})
	return {"path": path, "point_count": curve.point_count, "points": points}


static func get_gradient_info(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "" or not FileAccess.file_exists(path):
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No resource at %s" % path}
	var res: Resource = load(path)
	if not (res is Gradient):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "Resource at %s is not a Gradient" % path}
	var gradient: Gradient = res
	var stops: Array = []
	for i in range(gradient.get_point_count()):
		stops.append({
			"offset": gradient.get_offset(i),
			"color": gradient.get_color(i).to_html(),
		})
	return {"path": path, "point_count": gradient.get_point_count(), "stops": stops}


static func get_sprite_frames_info(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "" or not FileAccess.file_exists(path):
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No resource at %s" % path}
	var res: Resource = load(path)
	if not (res is SpriteFrames):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "Resource at %s is not a SpriteFrames" % path}
	var frames: SpriteFrames = res
	var animations: Array = []
	for anim_name in frames.get_animation_names():
		animations.append({
			"name": anim_name,
			"frame_count": frames.get_frame_count(anim_name),
			"fps": frames.get_animation_speed(anim_name),
			"loop": frames.get_animation_loop(anim_name),
		})
	return {"path": path, "animations": animations}


static func get_tileset_info(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "" or not FileAccess.file_exists(path):
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No resource at %s" % path}
	var res: Resource = load(path)
	if not (res is TileSet):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "Resource at %s is not a TileSet" % path}
	var tileset: TileSet = res
	var sources: Array = []
	for i in range(tileset.get_source_count()):
		var source_id: int = tileset.get_source_id(i)
		var source: TileSetSource = tileset.get_source(source_id)
		sources.append({
			"source_id": source_id,
			"type": source.get_class(),
		})
	var layers: Array = []
	for i in range(tileset.get_physics_layers_count()):
		layers.append({"index": i, "type": "physics"})
	for i in range(tileset.get_terrain_sets_count()):
		layers.append({"index": i, "type": "terrain_set"})
	return {
		"path": path,
		"tile_size": {"x": tileset.tile_size.x, "y": tileset.tile_size.y},
		"source_count": tileset.get_source_count(),
		"sources": sources,
		"layers": layers,
	}
