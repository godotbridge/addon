## Handlers for the shader_authoring tool category.
class_name GodotMCPShaderAuthoringHandlers
extends RefCounted

const NodeResolver = preload("res://addons/godot_mcp_bridge/utils/node_resolver.gd")

## A small starting set of ready-made canvas_item shaders, not an exhaustive
## library — add more entries here as real usage calls for them.
const PRESETS := {
	"grayscale": "shader_type canvas_item;\n\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV);\n\tfloat gray = dot(c.rgb, vec3(0.299, 0.587, 0.114));\n\tCOLOR = vec4(vec3(gray), c.a);\n}\n",
	"outline": "shader_type canvas_item;\n\nuniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);\nuniform float outline_width : hint_range(0.0, 10.0) = 1.0;\n\nvoid fragment() {\n\tvec2 size = TEXTURE_PIXEL_SIZE * outline_width;\n\tfloat alpha = texture(TEXTURE, UV).a;\n\tif (alpha < 1.0) {\n\t\tfloat a = texture(TEXTURE, UV + vec2(size.x, 0.0)).a;\n\t\ta += texture(TEXTURE, UV + vec2(-size.x, 0.0)).a;\n\t\ta += texture(TEXTURE, UV + vec2(0.0, size.y)).a;\n\t\ta += texture(TEXTURE, UV + vec2(0.0, -size.y)).a;\n\t\tif (a > 0.0) {\n\t\t\tCOLOR = outline_color;\n\t\t\treturn;\n\t\t}\n\t}\n\tCOLOR = texture(TEXTURE, UV);\n}\n",
	"dissolve": "shader_type canvas_item;\n\nuniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;\nuniform vec4 edge_color : source_color = vec4(1.0, 0.5, 0.0, 1.0);\n\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV);\n\tfloat noise = fract(sin(dot(UV, vec2(12.9898, 78.233))) * 43758.5453);\n\tif (noise < dissolve_amount) {\n\t\tdiscard;\n\t}\n\tif (noise < dissolve_amount + 0.05) {\n\t\tCOLOR = edge_color;\n\t} else {\n\t\tCOLOR = c;\n\t}\n}\n",
}


static func register(dispatch: Dictionary) -> void:
	dispatch["add_shader_preset"] = add_shader_preset
	dispatch["create_shader"] = create_shader
	dispatch["read_shader"] = read_shader
	dispatch["edit_shader"] = edit_shader
	dispatch["assign_shader"] = assign_shader
	dispatch["set_shader_parameter"] = set_shader_parameter
	dispatch["get_shader_parameters"] = get_shader_parameters
	dispatch["create_visual_shader"] = create_visual_shader
	dispatch["add_visual_shader_node"] = add_visual_shader_node
	dispatch["connect_visual_shader_nodes"] = connect_visual_shader_nodes
	dispatch["disconnect_visual_shader_nodes"] = disconnect_visual_shader_nodes
	dispatch["remove_visual_shader_node"] = remove_visual_shader_node
	dispatch["set_visual_shader_node_property"] = set_visual_shader_node_property
	dispatch["get_visual_shader_info"] = get_visual_shader_info


static func add_shader_preset(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	var preset: String = params.get("preset", "")
	if not PRESETS.has(preset):
		return {
			"__error_code__": "INVALID_PARAMS",
			"__error_message__": "Unknown preset '%s'. Available: %s" % [preset, ", ".join(PRESETS.keys())],
		}
	if not ("material" in node):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s has no material property" % node.get_class()}

	var shader := Shader.new()
	shader.code = PRESETS[preset]
	var material := ShaderMaterial.new()
	material.shader = shader
	node.material = material
	return {"node_path": params.get("node_path", ""), "preset": preset}


static func create_shader(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "path is required"}
	if FileAccess.file_exists(path):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "A shader already exists at %s" % path}

	var shader_type: String = params.get("shader_type", "canvas_item")
	var code: String = params.get("code", "shader_type %s;\n" % shader_type)

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Could not open %s for writing" % path}
	file.store_string(code)
	file.close()
	return {"path": path}


static func read_shader(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "" or not FileAccess.file_exists(path):
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No shader at %s" % path}
	var file := FileAccess.open(path, FileAccess.READ)
	return {"code": file.get_as_text()}


static func edit_shader(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	var code: String = params.get("code", "")
	if path == "" or not FileAccess.file_exists(path):
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No shader at %s" % path}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Could not open %s for writing" % path}
	file.store_string(code)
	file.close()
	return {"bytes_written": code.to_utf8_buffer().size()}


static func assign_shader(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if not ("material" in node):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s has no material property" % node.get_class()}

	var shader_path: String = params.get("shader_path", "")
	if shader_path == "" or not FileAccess.file_exists(shader_path):
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No shader at %s" % shader_path}
	# Same reasoning as attach_script's fix: a wrong-but-existing resource
	# type at shader_path would otherwise crash on static assignment below.
	var loaded: Variant = load(shader_path)
	if not (loaded is Shader):
		return {
			"__error_code__": "INVALID_PARAMS",
			"__error_message__": "%s is not a shader (loaded as %s)" % [shader_path, loaded.get_class() if loaded != null else "null"],
		}
	var shader: Shader = loaded

	var material := ShaderMaterial.new()
	material.shader = shader
	node.material = material
	return {"node_path": params.get("node_path", ""), "shader_path": shader_path}


static func set_shader_parameter(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	var material := _get_shader_material(node)
	if material is Dictionary:
		return material

	var parameter: String = params.get("parameter", "")
	if parameter == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "parameter is required"}
	material.set_shader_parameter(parameter, params.get("value"))
	return {"node_path": params.get("node_path", ""), "parameter": parameter, "value": material.get_shader_parameter(parameter)}


static func get_shader_parameters(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	var material := _get_shader_material(node)
	if material is Dictionary:
		return material

	var shader: Shader = material.shader
	var parameters: Array = []
	for uniform in shader.get_shader_uniform_list():
		var name: String = uniform.get("name", "")
		parameters.append({
			"name": name,
			"type": uniform.get("type", 0),
			"value": material.get_shader_parameter(name),
		})
	return {"parameters": parameters}


static func create_visual_shader(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "path is required"}
	if FileAccess.file_exists(path):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "A resource already exists at %s" % path}

	var shader := VisualShader.new()
	var shader_type: String = params.get("shader_type", "spatial")
	match shader_type:
		"spatial":
			shader.mode = Shader.MODE_SPATIAL
		"canvas_item":
			shader.mode = Shader.MODE_CANVAS_ITEM
		"particles":
			shader.mode = Shader.MODE_PARTICLES
		"sky":
			shader.mode = Shader.MODE_SKY
		"fog":
			shader.mode = Shader.MODE_FOG
		_:
			return {"__error_code__": "INVALID_PARAMS", "__error_message__": "Unknown shader_type '%s'. Use: spatial, canvas_item, particles, sky, fog" % shader_type}

	var err: Error = ResourceSaver.save(shader, path)
	if err != OK:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Could not save VisualShader: %s" % error_string(err)}
	return {"path": path, "shader_type": shader_type}


static func _load_visual_shader(path: String) -> Variant:
	if path == "" or not FileAccess.file_exists(path):
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No resource at %s" % path}
	var res: Resource = load(path)
	if not (res is VisualShader):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "Resource at %s is not a VisualShader" % path}
	return res


static func add_visual_shader_node(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	var shader := _load_visual_shader(path)
	if shader is Dictionary:
		return shader

	var node_type: String = params.get("node_type", "")
	if node_type == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "node_type is required"}

	var vs_node: VisualShaderNode = ClassDB.instantiate(node_type)
	if vs_node == null:
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "Unknown VisualShader node class '%s'" % node_type}

	var pos_data: Dictionary = params.get("position", {})
	var position := Vector2(float(pos_data.get("x", 0.0)), float(pos_data.get("y", 0.0)))

	var node_id: int = int(params.get("id", -1))
	if node_id < 0:
		node_id = shader.get_valid_node_id(VisualShader.TYPE_FRAGMENT)

	shader.add_node(VisualShader.TYPE_FRAGMENT, vs_node, position, node_id)
	ResourceSaver.save(shader, path)
	return {"path": path, "node_id": node_id, "node_type": node_type}


static func connect_visual_shader_nodes(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	var shader := _load_visual_shader(path)
	if shader is Dictionary:
		return shader

	var from_node: int = int(params.get("from_node", -1))
	var from_port: int = int(params.get("from_port", 0))
	var to_node: int = int(params.get("to_node", -1))
	var to_port: int = int(params.get("to_port", 0))

	var err: Error = shader.connect_nodes(VisualShader.TYPE_FRAGMENT, from_node, from_port, to_node, to_port)
	if err != OK:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Could not connect nodes: %s" % error_string(err)}
	ResourceSaver.save(shader, path)
	return {"connected": true, "from_node": from_node, "from_port": from_port, "to_node": to_node, "to_port": to_port}


static func disconnect_visual_shader_nodes(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	var shader := _load_visual_shader(path)
	if shader is Dictionary:
		return shader

	var from_node: int = int(params.get("from_node", -1))
	var from_port: int = int(params.get("from_port", 0))
	var to_node: int = int(params.get("to_node", -1))
	var to_port: int = int(params.get("to_port", 0))

	shader.disconnect_nodes(VisualShader.TYPE_FRAGMENT, from_node, from_port, to_node, to_port)
	ResourceSaver.save(shader, path)
	return {"disconnected": true, "from_node": from_node, "from_port": from_port, "to_node": to_node, "to_port": to_port}


static func remove_visual_shader_node(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	var shader := _load_visual_shader(path)
	if shader is Dictionary:
		return shader

	var node_id: int = int(params.get("node_id", -1))
	if node_id < 0:
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "node_id is required"}
	if node_id == 0:
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "Cannot remove the output node (id 0)"}

	shader.remove_node(VisualShader.TYPE_FRAGMENT, node_id)
	ResourceSaver.save(shader, path)
	return {"removed": true, "node_id": node_id}


static func set_visual_shader_node_property(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	var shader := _load_visual_shader(path)
	if shader is Dictionary:
		return shader

	var node_id: int = int(params.get("node_id", -1))
	if node_id < 0:
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "node_id is required"}

	var vs_node: VisualShaderNode = shader.get_node(VisualShader.TYPE_FRAGMENT, node_id)
	if vs_node == null:
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No node with id %d" % node_id}

	var property: String = params.get("property", "")
	if property == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "property is required"}

	vs_node.set(property, params.get("value"))
	ResourceSaver.save(shader, path)
	return {"node_id": node_id, "property": property}


static func get_visual_shader_info(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	var shader := _load_visual_shader(path)
	if shader is Dictionary:
		return shader

	var mode_name: String
	match shader.mode:
		Shader.MODE_SPATIAL: mode_name = "spatial"
		Shader.MODE_CANVAS_ITEM: mode_name = "canvas_item"
		Shader.MODE_PARTICLES: mode_name = "particles"
		Shader.MODE_SKY: mode_name = "sky"
		Shader.MODE_FOG: mode_name = "fog"
		_: mode_name = "unknown"

	var nodes: Array = []
	var node_list: PackedInt32Array = shader.get_node_list(VisualShader.TYPE_FRAGMENT)
	for nid in node_list:
		var vs_node: VisualShaderNode = shader.get_node(VisualShader.TYPE_FRAGMENT, nid)
		var pos: Vector2 = shader.get_node_position(VisualShader.TYPE_FRAGMENT, nid)
		nodes.append({
			"id": nid,
			"type": vs_node.get_class(),
			"position": {"x": pos.x, "y": pos.y},
		})

	var connections: Array = []
	for conn in shader.get_node_connections(VisualShader.TYPE_FRAGMENT):
		connections.append({
			"from_node": conn["from_node"],
			"from_port": conn["from_port"],
			"to_node": conn["to_node"],
			"to_port": conn["to_port"],
		})

	return {"path": path, "shader_type": mode_name, "nodes": nodes, "connections": connections}


static func _get_shader_material(node: Node) -> Variant:
	if not ("material" in node):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s has no material property" % node.get_class()}
	var material: Material = node.material
	if not (material is ShaderMaterial):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s does not have a ShaderMaterial assigned" % node.get_class()}
	return material
