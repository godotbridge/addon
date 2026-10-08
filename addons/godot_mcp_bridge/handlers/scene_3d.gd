## Handlers for the 3D scene building tool category — the largest category.
## Anything that assigns a Resource-typed property (mesh, material) does so
## via an explicit load()/create()+assign in the handler itself, never through
## a generic property setter — see the project's known limitation notes for
## why (Object.set() can't auto-load a resource from a plain JSON value).
class_name GodotMCPScene3DHandlers
extends RefCounted

const NodeResolver = preload("res://addons/godot_mcp_bridge/utils/node_resolver.gd")

const MATERIAL_PRESETS := ["metal", "plastic", "glass", "matte"]


static func register(dispatch: Dictionary) -> void:
	dispatch["add_camera_3d"] = add_camera_3d
	dispatch["add_light_3d"] = add_light_3d
	dispatch["add_mesh_instance"] = add_mesh_instance
	dispatch["set_mesh_material"] = set_mesh_material
	dispatch["create_material"] = create_material
	dispatch["create_material_preset"] = create_material_preset
	dispatch["set_material_property"] = set_material_property
	dispatch["add_csg_shape"] = add_csg_shape
	dispatch["set_csg_operation"] = set_csg_operation
	dispatch["add_decal"] = add_decal
	dispatch["add_reflection_probe"] = add_reflection_probe
	dispatch["add_subviewport"] = add_subviewport
	dispatch["add_bone_attachment_3d"] = add_bone_attachment_3d
	dispatch["add_gridmap"] = add_gridmap
	dispatch["gridmap_set_cell"] = gridmap_set_cell
	dispatch["add_text_mesh"] = add_text_mesh
	dispatch["create_terrain"] = create_terrain
	dispatch["scatter_multimesh"] = scatter_multimesh
	dispatch["add_spring_arm"] = add_spring_arm
	dispatch["add_global_illumination"] = add_global_illumination
	dispatch["add_environment"] = add_environment
	dispatch["set_environment_effects"] = set_environment_effects
	dispatch["look_at_node"] = look_at_node
	dispatch["set_node_transform_3d"] = set_node_transform_3d


# --- shared helpers ------------------------------------------------------

static func _vec3(d: Dictionary, default_val: float = 0.0) -> Vector3:
	return Vector3(d.get("x", default_val), d.get("y", default_val), d.get("z", default_val))


static func _vec3_to_dict(v: Vector3) -> Dictionary:
	return {"x": v.x, "y": v.y, "z": v.z}


static func _vec3i(d: Dictionary) -> Vector3i:
	return Vector3i(int(d.get("x", 0)), int(d.get("y", 0)), int(d.get("z", 0)))


static func _color(d: Dictionary) -> Color:
	return Color(d.get("r", 1.0), d.get("g", 1.0), d.get("b", 1.0), d.get("a", 1.0))


static func _create(params: Dictionary, ei: EditorInterface, node_type: String) -> Variant:
	var parent := NodeResolver.resolve(params, ei, "parent_path")
	if parent is Dictionary:
		return parent
	var root: Node = ei.get_edited_scene_root()
	return NodeResolver.add_child_node(parent, root, node_type, params.get("node_name", ""))


static func _describe(ei: EditorInterface, node: Node) -> Dictionary:
	var root: Node = ei.get_edited_scene_root()
	return {"node_path": NodeResolver.relative_path(root, node), "type": node.get_class()}


## Applies `properties` to a Resource, converting {r,g,b[,a]}-shaped dicts to
## Color and {x,y,z}-shaped dicts to Vector3 along the way (JSON has neither
## type natively).
static func _apply_properties(target: Object, properties: Dictionary) -> void:
	for property in properties.keys():
		var value: Variant = properties[property]
		if typeof(value) == TYPE_DICTIONARY:
			if value.has("r") and value.has("g") and value.has("b"):
				target.set(property, _color(value))
			elif value.has("x") and value.has("y") and value.has("z"):
				target.set(property, _vec3(value))
			else:
				target.set(property, value)
		else:
			target.set(property, value)


# --- camera / light --------------------------------------------------------

static func add_camera_3d(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := _create(params, ei, "Camera3D")
	if node is Dictionary:
		return node
	node.current = bool(params.get("current", true))
	return _describe(ei, node)


static func add_light_3d(params: Dictionary, ei: EditorInterface) -> Variant:
	var light_type: String = params.get("light_type", "directional")
	var node_type := "OmniLight3D"
	if light_type == "directional":
		node_type = "DirectionalLight3D"
	elif light_type == "spot":
		node_type = "SpotLight3D"
	var node := _create(params, ei, node_type)
	if node is Dictionary:
		return node
	if params.has("energy"):
		node.light_energy = float(params["energy"])
	if params.has("color"):
		node.light_color = _color(params["color"])
	return _describe(ei, node)


# --- mesh / material ---------------------------------------------------------

const PRIMITIVE_MESH_TYPES := {
	"box": "BoxMesh",
	"sphere": "SphereMesh",
	"capsule": "CapsuleMesh",
	"cylinder": "CylinderMesh",
	"plane": "PlaneMesh",
	"prism": "PrismMesh",
	"torus": "TorusMesh",
}


static func add_mesh_instance(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := _create(params, ei, "MeshInstance3D")
	if node is Dictionary:
		return node

	var mesh_type: String = params.get("mesh_type", "box")
	if not PRIMITIVE_MESH_TYPES.has(mesh_type):
		return {
			"__error_code__": "INVALID_PARAMS",
			"__error_message__": "Unknown mesh_type '%s'. Available: %s" % [mesh_type, ", ".join(PRIMITIVE_MESH_TYPES.keys())],
		}
	var mesh: PrimitiveMesh = ClassDB.instantiate(PRIMITIVE_MESH_TYPES[mesh_type])
	_apply_properties(mesh, params.get("mesh_properties", {}))
	node.mesh = mesh

	return {"node_path": NodeResolver.relative_path(ei.get_edited_scene_root(), node), "type": "MeshInstance3D", "mesh_type": mesh_type}


static func set_mesh_material(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if not (node is MeshInstance3D):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s is not a MeshInstance3D" % node.get_class()}

	var material_path: String = params.get("material_path", "")
	if material_path == "" or not FileAccess.file_exists(material_path):
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No material at %s" % material_path}
	# A wrong-but-existing resource type at material_path would otherwise crash
	# on the assignment below — see set_material_property's identical guard.
	var loaded: Variant = load(material_path)
	if not (loaded is Material):
		return {
			"__error_code__": "RESOURCE_NOT_FOUND",
			"__error_message__": "%s is not a Material resource (loaded as %s)" % [material_path, loaded.get_class() if loaded != null else "null"],
		}
	var material: Material = loaded

	node.set_surface_override_material(int(params.get("surface_index", 0)), material)
	return {"node_path": params.get("node_path", ""), "material_path": material_path}


static func create_material(params: Dictionary, ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "path is required"}
	if FileAccess.file_exists(path):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "A material already exists at %s" % path}

	var material := StandardMaterial3D.new()
	_apply_properties(material, params.get("properties", {}))

	var err: Error = ResourceSaver.save(material, path)
	if err != OK:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Could not save material: %s" % error_string(err)}
	return {"path": path}


static func create_material_preset(params: Dictionary, ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	var preset: String = params.get("preset", "")
	if not MATERIAL_PRESETS.has(preset):
		return {
			"__error_code__": "INVALID_PARAMS",
			"__error_message__": "Unknown preset '%s'. Available: %s" % [preset, ", ".join(MATERIAL_PRESETS)],
		}
	if path == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "path is required"}
	if FileAccess.file_exists(path):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "A material already exists at %s" % path}

	var material := StandardMaterial3D.new()
	match preset:
		"metal":
			material.metallic = 1.0
			material.roughness = 0.2
		"plastic":
			material.metallic = 0.0
			material.roughness = 0.4
		"glass":
			material.metallic = 0.0
			material.roughness = 0.05
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color = Color(1, 1, 1, 0.3)
		"matte":
			material.metallic = 0.0
			material.roughness = 1.0

	var err: Error = ResourceSaver.save(material, path)
	if err != OK:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Could not save material: %s" % error_string(err)}
	return {"path": path, "preset": preset}


static func set_material_property(params: Dictionary, ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "" or not FileAccess.file_exists(path):
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No material at %s" % path}
	# A wrong-but-existing resource type at path (e.g. a .tscn) would otherwise
	# crash on a hard GDScript type-assignment error, not a catchable one.
	var loaded: Variant = load(path)
	if not (loaded is Material):
		return {
			"__error_code__": "RESOURCE_NOT_FOUND",
			"__error_message__": "%s is not a Material resource (loaded as %s)" % [path, loaded.get_class() if loaded != null else "null"],
		}
	var material: Material = loaded

	var properties: Dictionary = params.get("properties", {})
	_apply_properties(material, properties)

	var err: Error = ResourceSaver.save(material, path)
	if err != OK:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Could not save material: %s" % error_string(err)}
	return {"path": path, "properties": properties.keys()}


# --- CSG ----------------------------------------------------------------------

const CSG_SHAPE_TYPES := {
	"box": "CSGBox3D",
	"sphere": "CSGSphere3D",
	"cylinder": "CSGCylinder3D",
	"torus": "CSGTorus3D",
}

const CSG_OPERATIONS := {
	"union": CSGShape3D.OPERATION_UNION,
	"intersection": CSGShape3D.OPERATION_INTERSECTION,
	"subtraction": CSGShape3D.OPERATION_SUBTRACTION,
}


static func add_csg_shape(params: Dictionary, ei: EditorInterface) -> Variant:
	var shape_type: String = params.get("shape_type", "box")
	if not CSG_SHAPE_TYPES.has(shape_type):
		return {
			"__error_code__": "INVALID_PARAMS",
			"__error_message__": "Unknown shape_type '%s'. Available: %s" % [shape_type, ", ".join(CSG_SHAPE_TYPES.keys())],
		}
	var node := _create(params, ei, CSG_SHAPE_TYPES[shape_type])
	if node is Dictionary:
		return node
	if params.has("operation") and CSG_OPERATIONS.has(params["operation"]):
		node.operation = CSG_OPERATIONS[params["operation"]]
	return _describe(ei, node)


static func set_csg_operation(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if not (node is CSGShape3D):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s is not a CSGShape3D" % node.get_class()}

	var operation: String = params.get("operation", "")
	if not CSG_OPERATIONS.has(operation):
		return {
			"__error_code__": "INVALID_PARAMS",
			"__error_message__": "Unknown operation '%s'. Available: %s" % [operation, ", ".join(CSG_OPERATIONS.keys())],
		}
	node.operation = CSG_OPERATIONS[operation]
	return {"node_path": params.get("node_path", ""), "operation": operation}


# --- misc 3D nodes -------------------------------------------------------------

static func add_decal(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := _create(params, ei, "Decal")
	if node is Dictionary:
		return node
	var texture_path: String = params.get("texture_path", "")
	if texture_path != "":
		if not FileAccess.file_exists(texture_path):
			return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No texture at %s" % texture_path}
		node.texture_albedo = load(texture_path)
	return _describe(ei, node)


static func add_reflection_probe(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := _create(params, ei, "ReflectionProbe")
	if node is Dictionary:
		return node
	return _describe(ei, node)


static func add_subviewport(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := _create(params, ei, "SubViewport")
	if node is Dictionary:
		return node
	if params.has("size"):
		var s: Dictionary = params["size"]
		node.size = Vector2i(int(s.get("x", 512)), int(s.get("y", 512)))
	return _describe(ei, node)


static func add_bone_attachment_3d(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := _create(params, ei, "BoneAttachment3D")
	if node is Dictionary:
		return node
	if params.has("bone_name"):
		node.bone_name = String(params["bone_name"])
	return _describe(ei, node)


static func add_gridmap(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := _create(params, ei, "GridMap")
	if node is Dictionary:
		return node
	if params.has("cell_size"):
		node.cell_size = _vec3(params["cell_size"], 1.0)
	var mesh_library_path: String = params.get("mesh_library_path", "")
	if mesh_library_path != "":
		if not FileAccess.file_exists(mesh_library_path):
			return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No MeshLibrary at %s" % mesh_library_path}
		node.mesh_library = load(mesh_library_path)
	return _describe(ei, node)


static func gridmap_set_cell(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if not (node is GridMap):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s is not a GridMap" % node.get_class()}

	var coords := _vec3i(params.get("coords", {}))
	var item: int = int(params.get("item", -1))
	var orientation: int = int(params.get("orientation", 0))
	node.set_cell_item(coords, item, orientation)
	return {"node_path": params.get("node_path", ""), "coords": {"x": coords.x, "y": coords.y, "z": coords.z}, "item": item}


static func add_text_mesh(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := _create(params, ei, "MeshInstance3D")
	if node is Dictionary:
		return node

	var text_mesh := TextMesh.new()
	text_mesh.text = String(params.get("text", "Text"))
	if params.has("font_size"):
		text_mesh.font_size = int(params["font_size"])
	if params.has("depth"):
		text_mesh.depth = float(params["depth"])
	node.mesh = text_mesh

	return {"node_path": NodeResolver.relative_path(ei.get_edited_scene_root(), node), "type": "MeshInstance3D"}


## Generates a noise-displaced grid mesh via SurfaceTool — a real (if simple)
## procedural heightmap, not a flat placeholder.
static func create_terrain(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := _create(params, ei, "MeshInstance3D")
	if node is Dictionary:
		return node

	var width: int = max(int(params.get("width", 10)), 1)
	var depth: int = max(int(params.get("depth", 10)), 1)
	var cell_size: float = float(params.get("cell_size", 1.0))
	var height_scale: float = float(params.get("height_scale", 2.0))

	var noise := FastNoiseLite.new()
	noise.seed = int(params.get("seed", 0))
	noise.frequency = float(params.get("frequency", 0.1))

	var heights := {}
	var h := func(x: int, z: int) -> float:
		var key := "%d_%d" % [x, z]
		if not heights.has(key):
			heights[key] = noise.get_noise_2d(x, z) * height_scale
		return heights[key]

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(depth):
		for x in range(width):
			var x0 := x * cell_size
			var x1 := (x + 1) * cell_size
			var z0 := z * cell_size
			var z1 := (z + 1) * cell_size
			var p00 := Vector3(x0, h.call(x, z), z0)
			var p10 := Vector3(x1, h.call(x + 1, z), z0)
			var p01 := Vector3(x0, h.call(x, z + 1), z1)
			var p11 := Vector3(x1, h.call(x + 1, z + 1), z1)
			st.add_vertex(p00)
			st.add_vertex(p10)
			st.add_vertex(p01)
			st.add_vertex(p10)
			st.add_vertex(p11)
			st.add_vertex(p01)
	st.generate_normals()
	node.mesh = st.commit()

	return {"node_path": NodeResolver.relative_path(ei.get_edited_scene_root(), node), "type": "MeshInstance3D", "width": width, "depth": depth}


static func scatter_multimesh(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := _create(params, ei, "MultiMeshInstance3D")
	if node is Dictionary:
		return node

	var mesh_type: String = params.get("mesh_type", "box")
	if not PRIMITIVE_MESH_TYPES.has(mesh_type):
		return {
			"__error_code__": "INVALID_PARAMS",
			"__error_message__": "Unknown mesh_type '%s'. Available: %s" % [mesh_type, ", ".join(PRIMITIVE_MESH_TYPES.keys())],
		}
	var mesh: PrimitiveMesh = ClassDB.instantiate(PRIMITIVE_MESH_TYPES[mesh_type])
	_apply_properties(mesh, params.get("mesh_properties", {}))

	var count: int = max(int(params.get("count", 10)), 0)
	var area := _vec3(params.get("area", {"x": 10.0, "y": 0.0, "z": 10.0}))

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = count

	var rng := RandomNumberGenerator.new()
	rng.seed = int(params.get("seed", 0))
	for i in range(count):
		var pos := Vector3(
			rng.randf_range(-area.x / 2.0, area.x / 2.0),
			rng.randf_range(-area.y / 2.0, area.y / 2.0),
			rng.randf_range(-area.z / 2.0, area.z / 2.0)
		)
		multimesh.set_instance_transform(i, Transform3D(Basis(), pos))

	node.multimesh = multimesh
	return {"node_path": NodeResolver.relative_path(ei.get_edited_scene_root(), node), "type": "MultiMeshInstance3D", "count": count}


static func add_spring_arm(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := _create(params, ei, "SpringArm3D")
	if node is Dictionary:
		return node
	if params.has("length"):
		node.spring_length = float(params["length"])
	return _describe(ei, node)


## Adds a VoxelGI node (the classic discrete "GI probe"). SDFGI is a
## WorldEnvironment-level setting, not a node — configure it through
## set_environment_effects instead if that's what's wanted.
static func add_global_illumination(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := _create(params, ei, "VoxelGI")
	if node is Dictionary:
		return node
	return _describe(ei, node)


static func add_environment(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "path is required"}
	if FileAccess.file_exists(path):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "An environment already exists at %s" % path}

	var environment := Environment.new()
	_apply_properties(environment, params.get("properties", {}))

	var err: Error = ResourceSaver.save(environment, path)
	if err != OK:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Could not save environment: %s" % error_string(err)}
	return {"path": path}


static func set_environment_effects(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if not (node is WorldEnvironment):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s is not a WorldEnvironment" % node.get_class()}

	var environment: Environment = node.environment
	if environment == null:
		environment = Environment.new()
		node.environment = environment

	_apply_properties(environment, params.get("properties", {}))
	return {"node_path": params.get("node_path", ""), "properties": params.get("properties", {}).keys()}


static func look_at_node(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if not (node is Node3D):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s is not a Node3D" % node.get_class()}

	var target_path: String = params.get("target_node_path", "")
	var target := NodeResolver.get_node(ei.get_edited_scene_root(), target_path)
	if target == null or not (target is Node3D):
		return {"__error_code__": "NODE_NOT_FOUND", "__error_message__": "No Node3D at path %s" % target_path}

	var up := _vec3(params.get("up", {"x": 0.0, "y": 1.0, "z": 0.0}))
	if up == Vector3.ZERO:
		up = Vector3.UP
	node.look_at(target.global_position, up)
	return {"node_path": params.get("node_path", ""), "target_node_path": target_path}


static func set_node_transform_3d(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if not (node is Node3D):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s is not a Node3D" % node.get_class()}

	if params.has("position"):
		node.position = _vec3(params["position"])
	if params.has("rotation_degrees"):
		node.rotation_degrees = _vec3(params["rotation_degrees"])
	if params.has("scale"):
		node.scale = _vec3(params["scale"], 1.0)

	return {
		"node_path": params.get("node_path", ""),
		"position": _vec3_to_dict(node.position),
		"rotation_degrees": _vec3_to_dict(node.rotation_degrees),
		"scale": _vec3_to_dict(node.scale),
	}
