## Handlers for the 2D scene building tool category.
class_name GodotMCPScene2DHandlers
extends RefCounted

const NodeResolver = preload("res://addons/godot_mcp_bridge/utils/node_resolver.gd")


static func register(dispatch: Dictionary) -> void:
	dispatch["add_sprite"] = add_sprite
	dispatch["add_animated_sprite"] = add_animated_sprite
	dispatch["add_camera_2d"] = add_camera_2d
	dispatch["add_line2d"] = add_line2d
	dispatch["add_canvas_modulate"] = add_canvas_modulate
	dispatch["add_light_2d"] = add_light_2d
	dispatch["add_light_occluder_2d"] = add_light_occluder_2d
	dispatch["add_parallax"] = add_parallax
	dispatch["add_polygon_2d"] = add_polygon_2d
	dispatch["set_node_transform_2d"] = set_node_transform_2d
	dispatch["create_placeholder_texture"] = create_placeholder_texture
	dispatch["set_sprite_texture"] = set_sprite_texture


static func _vec2(d: Dictionary) -> Vector2:
	return Vector2(d.get("x", 0.0), d.get("y", 0.0))


static func _color(d: Dictionary) -> Color:
	return Color(d.get("r", 1.0), d.get("g", 1.0), d.get("b", 1.0), d.get("a", 1.0))


static func _points(arr: Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p in arr:
		pts.append(_vec2(p))
	return pts


## Creates node_type under parent_path, describing it the same way as every
## other "add_<type>" tool (node_path + type). Callers that need to set extra
## properties before responding should call NodeResolver directly instead.
static func _create(params: Dictionary, ei: EditorInterface, node_type: String) -> Variant:
	var parent := NodeResolver.resolve(params, ei, "parent_path")
	if parent is Dictionary:
		return parent
	var root: Node = ei.get_edited_scene_root()
	return NodeResolver.add_child_node(parent, root, node_type, params.get("node_name", ""))


static func _describe(ei: EditorInterface, node: Node) -> Dictionary:
	var root: Node = ei.get_edited_scene_root()
	return {"node_path": NodeResolver.relative_path(root, node), "type": node.get_class()}


static func add_sprite(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := _create(params, ei, "Sprite2D")
	if node is Dictionary:
		return node
	var texture_path: String = params.get("texture_path", "")
	if texture_path != "":
		var tex: Variant = load(texture_path)
		if not (tex is Texture2D):
			return {
				"__error_code__": "RESOURCE_NOT_FOUND",
				"__error_message__": "%s is not a Texture2D resource (loaded as %s)" % [texture_path, tex.get_class() if tex != null else "null"],
			}
		node.texture = tex
	return _describe(ei, node)


static func add_animated_sprite(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := _create(params, ei, "AnimatedSprite2D")
	if node is Dictionary:
		return node
	var frames_path: String = params.get("sprite_frames_path", "")
	if frames_path != "":
		var frames: Variant = load(frames_path)
		if not (frames is SpriteFrames):
			return {
				"__error_code__": "RESOURCE_NOT_FOUND",
				"__error_message__": "%s is not a SpriteFrames resource (loaded as %s)" % [frames_path, frames.get_class() if frames != null else "null"],
			}
		node.sprite_frames = frames
	return _describe(ei, node)


static func add_camera_2d(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := _create(params, ei, "Camera2D")
	if node is Dictionary:
		return node
	node.enabled = bool(params.get("current", true))
	return _describe(ei, node)


static func add_line2d(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := _create(params, ei, "Line2D")
	if node is Dictionary:
		return node
	if params.has("points"):
		node.points = _points(params["points"])
	if params.has("width"):
		node.width = float(params["width"])
	if params.has("color"):
		node.default_color = _color(params["color"])
	return _describe(ei, node)


static func add_canvas_modulate(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := _create(params, ei, "CanvasModulate")
	if node is Dictionary:
		return node
	if params.has("color"):
		node.color = _color(params["color"])
	return _describe(ei, node)


static func add_light_2d(params: Dictionary, ei: EditorInterface) -> Variant:
	var light_type: String = params.get("light_type", "point")
	var node_type := "DirectionalLight2D" if light_type == "directional" else "PointLight2D"
	var node := _create(params, ei, node_type)
	if node is Dictionary:
		return node
	if params.has("energy"):
		node.energy = float(params["energy"])
	if params.has("color"):
		node.color = _color(params["color"])
	return _describe(ei, node)


static func add_light_occluder_2d(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := _create(params, ei, "LightOccluder2D")
	if node is Dictionary:
		return node
	if params.has("points"):
		var polygon := OccluderPolygon2D.new()
		polygon.polygon = _points(params["points"])
		node.occluder = polygon
	return _describe(ei, node)


## `layer: true` adds a ParallaxLayer (a child of an existing ParallaxBackground
## at parent_path) instead of the ParallaxBackground container itself.
static func add_parallax(params: Dictionary, ei: EditorInterface) -> Variant:
	var node_type := "ParallaxLayer" if bool(params.get("layer", false)) else "ParallaxBackground"
	var node := _create(params, ei, node_type)
	if node is Dictionary:
		return node
	if node_type == "ParallaxLayer" and params.has("motion_scale"):
		node.motion_scale = _vec2(params["motion_scale"])
	return _describe(ei, node)


static func add_polygon_2d(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := _create(params, ei, "Polygon2D")
	if node is Dictionary:
		return node
	if params.has("points"):
		node.polygon = _points(params["points"])
	if params.has("color"):
		node.color = _color(params["color"])
	return _describe(ei, node)


static func set_node_transform_2d(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if not (node is Node2D):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s is not a Node2D" % node.get_class()}
	if params.has("position"):
		node.position = _vec2(params["position"])
	if params.has("rotation"):
		node.rotation = float(params["rotation"])
	if params.has("scale"):
		node.scale = _vec2(params["scale"])
	return {
		"node_path": params.get("node_path", ""),
		"position": {"x": node.position.x, "y": node.position.y},
		"rotation": node.rotation,
		"scale": {"x": node.scale.x, "y": node.scale.y},
	}


static func create_placeholder_texture(params: Dictionary, ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "path is required"}
	if FileAccess.file_exists(path):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "A file already exists at %s" % path}

	var width: int = int(params.get("width", 64))
	var height: int = int(params.get("height", 64))
	var color := _color(params.get("color", {"r": 1.0, "g": 0.0, "b": 1.0, "a": 1.0}))

	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(color)
	var err: Error = image.save_png(path)
	if err != OK:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Could not save image: %s" % error_string(err)}

	# Unlike scripts/scenes/resources, raw asset files (images, audio, ...)
	# only become load()-able after Godot's import pipeline processes them —
	# writing the bytes isn't enough. Force that here so callers can
	# immediately load(path) in a follow-up call.
	var fs := ei.get_resource_filesystem()
	fs.update_file(path)
	fs.reimport_files([path])

	return {"path": path, "width": width, "height": height}


static func set_sprite_texture(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if not ("texture" in node):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s has no texture property" % node.get_class()}

	var texture_path: String = params.get("texture_path", "")
	if texture_path == "" or not FileAccess.file_exists(texture_path):
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No texture at %s" % texture_path}
	var texture: Variant = load(texture_path)
	if not (texture is Texture2D):
		return {
			"__error_code__": "RESOURCE_NOT_FOUND",
			"__error_message__": "%s is not a Texture2D resource (loaded as %s)" % [texture_path, texture.get_class() if texture != null else "null"],
		}
	node.texture = texture
	return {"node_path": params.get("node_path", ""), "texture_path": texture_path}
