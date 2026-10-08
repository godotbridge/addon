## Handlers for the physics_configuration tool category.
class_name GodotMCPPhysicsConfigurationHandlers
extends RefCounted

const NodeResolver = preload("res://addons/godot_mcp_bridge/utils/node_resolver.gd")


static func register(dispatch: Dictionary) -> void:
	dispatch["add_body_2d"] = add_body_2d
	dispatch["add_body_3d"] = add_body_3d
	dispatch["add_collision_shape"] = add_collision_shape
	dispatch["add_collision_polygon"] = add_collision_polygon
	dispatch["add_mesh_collision"] = add_mesh_collision
	dispatch["add_shape_cast"] = add_shape_cast
	dispatch["add_raycast"] = add_raycast
	dispatch["set_physics_material"] = set_physics_material
	dispatch["set_collision_layers"] = set_collision_layers
	dispatch["set_collision_layers_by_name"] = set_collision_layers_by_name
	dispatch["get_collision_info"] = get_collision_info


static func _create(params: Dictionary, ei: EditorInterface, node_type: String) -> Variant:
	var parent := NodeResolver.resolve(params, ei, "parent_path")
	if parent is Dictionary:
		return parent
	var root: Node = ei.get_edited_scene_root()
	return NodeResolver.add_child_node(parent, root, node_type, params.get("node_name", ""))


static func _describe(ei: EditorInterface, node: Node) -> Dictionary:
	var root: Node = ei.get_edited_scene_root()
	return {"node_path": NodeResolver.relative_path(root, node), "type": node.get_class()}


## Scaffolds a body with a ready-to-use collision shape child, since a bare
## body with no shape has nothing to collide with.
static func add_body_2d(params: Dictionary, ei: EditorInterface) -> Variant:
	var body_type: String = params.get("body_type", "CharacterBody2D")
	var body := _create(params, ei, body_type)
	if body is Dictionary:
		return body

	var root: Node = ei.get_edited_scene_root()
	var shape := RectangleShape2D.new()
	var size: Dictionary = params.get("size", {"x": 32.0, "y": 32.0})
	shape.size = Vector2(size.get("x", 32.0), size.get("y", 32.0))

	var shape_node := NodeResolver.add_child_node(body, root, "CollisionShape2D", "CollisionShape2D")
	if shape_node is Dictionary:
		return shape_node
	shape_node.shape = shape

	return {
		"node_path": NodeResolver.relative_path(root, body),
		"type": body_type,
		"collision_shape_path": NodeResolver.relative_path(root, shape_node),
	}


static func add_body_3d(params: Dictionary, ei: EditorInterface) -> Variant:
	var body_type: String = params.get("body_type", "CharacterBody3D")
	var body := _create(params, ei, body_type)
	if body is Dictionary:
		return body

	var root: Node = ei.get_edited_scene_root()
	var shape := BoxShape3D.new()
	var size: Dictionary = params.get("size", {"x": 1.0, "y": 1.0, "z": 1.0})
	shape.size = Vector3(size.get("x", 1.0), size.get("y", 1.0), size.get("z", 1.0))

	var shape_node := NodeResolver.add_child_node(body, root, "CollisionShape3D", "CollisionShape3D")
	if shape_node is Dictionary:
		return shape_node
	shape_node.shape = shape

	return {
		"node_path": NodeResolver.relative_path(root, body),
		"type": body_type,
		"collision_shape_path": NodeResolver.relative_path(root, shape_node),
	}


static func add_collision_shape(params: Dictionary, ei: EditorInterface) -> Variant:
	var dimension: String = params.get("dimension", "2d")
	var node_type := "CollisionShape3D" if dimension == "3d" else "CollisionShape2D"
	var node := _create(params, ei, node_type)
	if node is Dictionary:
		return node

	var shape_type: String = params.get("shape_type", "RectangleShape2D" if dimension != "3d" else "BoxShape3D")
	var shape: Resource = ClassDB.instantiate(shape_type)
	if shape == null:
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "Unknown shape class %s" % shape_type}

	var properties: Dictionary = params.get("shape_properties", {})
	for property in properties.keys():
		var value: Variant = properties[property]
		if typeof(value) == TYPE_DICTIONARY:
			if value.has("z"):
				shape.set(property, Vector3(value.get("x", 0.0), value.get("y", 0.0), value.get("z", 0.0)))
			elif value.has("x"):
				shape.set(property, Vector2(value.get("x", 0.0), value.get("y", 0.0)))
			else:
				shape.set(property, value)
		else:
			shape.set(property, value)

	node.shape = shape
	return _describe(ei, node)


static func add_collision_polygon(params: Dictionary, ei: EditorInterface) -> Variant:
	var dimension: String = params.get("dimension", "2d")
	var node_type := "CollisionPolygon3D" if dimension == "3d" else "CollisionPolygon2D"
	var node := _create(params, ei, node_type)
	if node is Dictionary:
		return node

	var points: Array = params.get("points", [])
	var polygon := PackedVector2Array()
	for p in points:
		polygon.append(Vector2(p.get("x", 0.0), p.get("y", 0.0)))
	node.polygon = polygon
	return _describe(ei, node)


## Auto-generates collision geometry for a MeshInstance3D — a thin wrapper
## over the engine's own create_convex_collision()/create_trimesh_collision().
static func add_mesh_collision(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if not (node is MeshInstance3D):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s is not a MeshInstance3D" % node.get_class()}

	if bool(params.get("convex", false)):
		node.create_convex_collision()
	else:
		node.create_trimesh_collision()
	return {"node_path": params.get("node_path", ""), "convex": bool(params.get("convex", false))}


static func add_shape_cast(params: Dictionary, ei: EditorInterface) -> Variant:
	var dimension: String = params.get("dimension", "2d")
	var node_type := "ShapeCast3D" if dimension == "3d" else "ShapeCast2D"
	var node := _create(params, ei, node_type)
	if node is Dictionary:
		return node
	return _describe(ei, node)


static func add_raycast(params: Dictionary, ei: EditorInterface) -> Variant:
	var dimension: String = params.get("dimension", "2d")
	var node_type := "RayCast3D" if dimension == "3d" else "RayCast2D"
	var node := _create(params, ei, node_type)
	if node is Dictionary:
		return node

	if params.has("target_position"):
		var tp: Dictionary = params["target_position"]
		if dimension == "3d":
			node.target_position = Vector3(tp.get("x", 0.0), tp.get("y", 0.0), tp.get("z", 0.0))
		else:
			node.target_position = Vector2(tp.get("x", 0.0), tp.get("y", 0.0))
	return _describe(ei, node)


static func set_physics_material(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if not ("physics_material_override" in node):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s has no physics_material_override property" % node.get_class()}

	var material := PhysicsMaterial.new()
	if params.has("friction"):
		material.friction = float(params["friction"])
	if params.has("bounce"):
		material.bounce = float(params["bounce"])
	if params.has("rough"):
		material.rough = bool(params["rough"])
	if params.has("absorbent"):
		material.absorbent = bool(params["absorbent"])
	node.physics_material_override = material
	return {
		"node_path": params.get("node_path", ""),
		"friction": material.friction,
		"bounce": material.bounce,
	}


## `layer`/`mask` accept either a raw 32-bit int bitmask, or an Array of
## 1-indexed layer numbers (e.g. [1, 3]) to set as active bits.
static func _resolve_bitmask(value: Variant, current: int) -> int:
	if typeof(value) == TYPE_ARRAY:
		var mask := 0
		for n in value:
			mask |= 1 << (int(n) - 1)
		return mask
	if value == null:
		return current
	return int(value)


static func set_collision_layers(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if not ("collision_layer" in node):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s is not a collision object" % node.get_class()}

	node.collision_layer = _resolve_bitmask(params.get("layer"), node.collision_layer)
	node.collision_mask = _resolve_bitmask(params.get("mask"), node.collision_mask)
	return {"node_path": params.get("node_path", ""), "collision_layer": node.collision_layer, "collision_mask": node.collision_mask}


## Resolves names against the project's named physics layers
## (Project Settings > Layer Names > 2D/3D Physics) instead of raw bit numbers.
static func set_collision_layers_by_name(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if not ("collision_layer" in node):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s is not a collision object" % node.get_class()}

	var dimension: String = params.get("dimension", "2d")
	var prefix := "layer_names/%s_physics/layer_" % dimension

	var layer_names: Array = params.get("layers", [])
	var mask_names: Array = params.get("mask_layers", [])
	var layer_bits := _names_to_bits(layer_names, prefix)
	var mask_bits := _names_to_bits(mask_names, prefix)
	if layer_bits is Dictionary:
		return layer_bits
	if mask_bits is Dictionary:
		return mask_bits

	if not layer_names.is_empty():
		node.collision_layer = layer_bits
	if not mask_names.is_empty():
		node.collision_mask = mask_bits
	return {"node_path": params.get("node_path", ""), "collision_layer": node.collision_layer, "collision_mask": node.collision_mask}


static func _names_to_bits(names: Array, prefix: String) -> Variant:
	var mask := 0
	for name in names:
		var found := -1
		for i in range(1, 33):
			if ProjectSettings.has_setting(prefix + str(i)) and ProjectSettings.get_setting(prefix + str(i)) == name:
				found = i
				break
		if found == -1:
			return {"__error_code__": "INVALID_PARAMS", "__error_message__": "No physics layer named '%s'" % name}
		mask |= 1 << (found - 1)
	return mask


static func get_collision_info(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if not ("collision_layer" in node):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s is not a collision object" % node.get_class()}

	var shape_count := 0
	for child in node.get_children():
		if child is CollisionShape2D or child is CollisionShape3D or child is CollisionPolygon2D or child is CollisionPolygon3D:
			shape_count += 1

	return {
		"type": node.get_class(),
		"collision_layer": node.collision_layer,
		"collision_mask": node.collision_mask,
		"has_physics_material": ("physics_material_override" in node) and node.physics_material_override != null,
		"shape_count": shape_count,
	}
