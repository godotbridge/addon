## Handlers for the rigging (3D Models & Rigging) tool category.
class_name GodotMCPRiggingHandlers
extends RefCounted

const NodeResolver = preload("res://addons/godot_mcp_bridge/utils/node_resolver.gd")


static func register(dispatch: Dictionary) -> void:
	dispatch["create_skeleton"] = create_skeleton
	dispatch["add_bone"] = add_bone
	dispatch["set_bone_rest"] = set_bone_rest
	dispatch["get_skeleton_info"] = get_skeleton_info
	dispatch["set_bone_pose"] = set_bone_pose
	dispatch["reset_bone_poses"] = reset_bone_poses
	dispatch["get_mesh_info"] = get_mesh_info
	dispatch["set_blend_shape"] = set_blend_shape
	dispatch["list_model_animations"] = list_model_animations
	dispatch["create_skeleton_2d"] = create_skeleton_2d
	dispatch["create_bone_map"] = create_bone_map
	dispatch["auto_bone_map"] = auto_bone_map
	dispatch["add_look_at_modifier"] = add_look_at_modifier
	dispatch["add_ik_chain"] = add_ik_chain
	dispatch["add_csg_polygon"] = add_csg_polygon
	dispatch["add_occluder_3d"] = add_occluder_3d


static func _create(params: Dictionary, ei: EditorInterface, node_type: String) -> Variant:
	var parent := NodeResolver.resolve(params, ei, "parent_path")
	if parent is Dictionary:
		return parent
	var root: Node = ei.get_edited_scene_root()
	return NodeResolver.add_child_node(parent, root, node_type, params.get("node_name", ""))


static func _describe(ei: EditorInterface, node: Node) -> Dictionary:
	var root: Node = ei.get_edited_scene_root()
	return {"node_path": NodeResolver.relative_path(root, node), "type": node.get_class()}


static func _get_skeleton(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if not (node is Skeleton3D):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s is not a Skeleton3D" % node.get_class()}
	return node


static func create_skeleton(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := _create(params, ei, "Skeleton3D")
	if node is Dictionary:
		return node
	return _describe(ei, node)


static func create_skeleton_2d(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := _create(params, ei, "Skeleton2D")
	if node is Dictionary:
		return node
	return _describe(ei, node)


static func add_bone(params: Dictionary, ei: EditorInterface) -> Variant:
	var skeleton := _get_skeleton(params, ei)
	if skeleton is Dictionary:
		return skeleton

	var bone_name: String = params.get("bone_name", "")
	if bone_name == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "bone_name is required"}

	var index: int = skeleton.add_bone(bone_name)
	if params.has("parent_bone_index"):
		skeleton.set_bone_parent(index, int(params["parent_bone_index"]))
	if params.has("rest_position"):
		var rp: Dictionary = params["rest_position"]
		var t := Transform3D()
		t.origin = Vector3(rp.get("x", 0.0), rp.get("y", 0.0), rp.get("z", 0.0))
		skeleton.set_bone_rest(index, t)

	return {"node_path": params.get("node_path", ""), "bone_name": bone_name, "bone_index": index}


static func set_bone_rest(params: Dictionary, ei: EditorInterface) -> Variant:
	var skeleton := _get_skeleton(params, ei)
	if skeleton is Dictionary:
		return skeleton

	var bone_index: int = int(params.get("bone_index", -1))
	if bone_index < 0 or bone_index >= skeleton.get_bone_count():
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "No bone at index %d" % bone_index}

	var t := Transform3D()
	if params.has("position"):
		var p: Dictionary = params["position"]
		t.origin = Vector3(p.get("x", 0.0), p.get("y", 0.0), p.get("z", 0.0))
	skeleton.set_bone_rest(bone_index, t)
	return {"node_path": params.get("node_path", ""), "bone_index": bone_index}


static func get_skeleton_info(params: Dictionary, ei: EditorInterface) -> Variant:
	var skeleton := _get_skeleton(params, ei)
	if skeleton is Dictionary:
		return skeleton

	var bones: Array = []
	for i in range(skeleton.get_bone_count()):
		bones.append({
			"index": i,
			"name": skeleton.get_bone_name(i),
			"parent": skeleton.get_bone_parent(i),
			"rest_position": {
				"x": skeleton.get_bone_rest(i).origin.x,
				"y": skeleton.get_bone_rest(i).origin.y,
				"z": skeleton.get_bone_rest(i).origin.z,
			},
		})
	return {"bone_count": skeleton.get_bone_count(), "bones": bones}


static func set_bone_pose(params: Dictionary, ei: EditorInterface) -> Variant:
	var skeleton := _get_skeleton(params, ei)
	if skeleton is Dictionary:
		return skeleton

	var bone_index: int = int(params.get("bone_index", -1))
	if bone_index < 0 or bone_index >= skeleton.get_bone_count():
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "No bone at index %d" % bone_index}

	if params.has("position"):
		var p: Dictionary = params["position"]
		skeleton.set_bone_pose_position(bone_index, Vector3(p.get("x", 0.0), p.get("y", 0.0), p.get("z", 0.0)))
	if params.has("rotation"):
		var r: Dictionary = params["rotation"]
		skeleton.set_bone_pose_rotation(bone_index, Quaternion.from_euler(Vector3(
			deg_to_rad(r.get("x", 0.0)), deg_to_rad(r.get("y", 0.0)), deg_to_rad(r.get("z", 0.0))
		)))
	if params.has("scale"):
		var s: Dictionary = params["scale"]
		skeleton.set_bone_pose_scale(bone_index, Vector3(s.get("x", 1.0), s.get("y", 1.0), s.get("z", 1.0)))

	return {"node_path": params.get("node_path", ""), "bone_index": bone_index}


static func reset_bone_poses(params: Dictionary, ei: EditorInterface) -> Variant:
	var skeleton := _get_skeleton(params, ei)
	if skeleton is Dictionary:
		return skeleton

	for i in range(skeleton.get_bone_count()):
		skeleton.set_bone_pose_position(i, Vector3.ZERO)
		skeleton.set_bone_pose_rotation(i, Quaternion.IDENTITY)
		skeleton.set_bone_pose_scale(i, Vector3.ONE)

	return {"node_path": params.get("node_path", ""), "bone_count": skeleton.get_bone_count()}


static func get_mesh_info(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if not (node is MeshInstance3D):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s is not a MeshInstance3D" % node.get_class()}
	if node.mesh == null:
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s has no mesh assigned" % node.get_class()}

	var mesh: Mesh = node.mesh
	var surfaces: Array = []
	for i in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(i)
		var vertex_count: int = 0
		if arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] != null:
			vertex_count = arrays[Mesh.ARRAY_VERTEX].size()
		surfaces.append({"index": i, "vertex_count": vertex_count})

	# Blend shapes are an ArrayMesh-only feature — PrimitiveMesh subclasses
	# (BoxMesh, SphereMesh, ...) don't define get_blend_shape_count() at all.
	var blend_shapes: Array = []
	if mesh is ArrayMesh:
		for i in range(mesh.get_blend_shape_count()):
			blend_shapes.append(mesh.get_blend_shape_name(i))

	return {"surface_count": mesh.get_surface_count(), "surfaces": surfaces, "blend_shapes": blend_shapes}


static func set_blend_shape(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if not (node is MeshInstance3D):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s is not a MeshInstance3D" % node.get_class()}

	if node.mesh == null:
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s has no mesh assigned" % node.get_class()}
	# Blend shapes are an ArrayMesh-only feature — PrimitiveMesh subclasses
	# (BoxMesh, SphereMesh, ...) don't define get_blend_shape_count() at all.
	if not (node.mesh is ArrayMesh):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s does not support blend shapes" % node.mesh.get_class()}

	var mesh: ArrayMesh = node.mesh
	var blend_shape_name: String = params.get("blend_shape_name", "")
	var index: int = mesh.find_blend_shape_by_name(blend_shape_name) if blend_shape_name != "" else int(params.get("blend_shape_index", -1))
	if index < 0 or index >= mesh.get_blend_shape_count():
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "No blend shape named '%s'" % blend_shape_name if blend_shape_name != "" else "Blend shape index %d out of range" % index}

	var value: float = float(params.get("value", 0.0))
	node.set_blend_shape_value(index, value)
	return {"node_path": params.get("node_path", ""), "blend_shape_index": index, "value": value}


## Godot doesn't distinguish "model" animations from any other AnimationPlayer
## animations at the API level (imported glTF/FBX rigs end up as a normal
## AnimationPlayer + AnimationLibrary just like hand-authored ones) — this is
## the same introspection as animation_systems' list_animations.
static func list_model_animations(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if not (node is AnimationPlayer):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s is not an AnimationPlayer" % node.get_class()}
	return {"animations": Array(node.get_animation_list())}


static func create_bone_map(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "path is required"}
	if FileAccess.file_exists(path):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "A resource already exists at %s" % path}

	var bone_map := BoneMap.new()
	bone_map.profile = SkeletonProfileHumanoid.new()

	var err: Error = ResourceSaver.save(bone_map, path)
	if err != OK:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Could not save BoneMap: %s" % error_string(err)}
	return {"path": path}


## Best-effort case-insensitive exact-name matching between the skeleton's
## bones and SkeletonProfileHumanoid's expected bone names — not the editor's
## full fuzzy-matching heuristic (that's editor-UI-only, not scriptable), so
## treat the result as a starting point to review, not a guaranteed-correct map.
static func auto_bone_map(params: Dictionary, ei: EditorInterface) -> Variant:
	var skeleton := _get_skeleton(params, ei)
	if skeleton is Dictionary:
		return skeleton

	var skeleton_names := {}
	for i in range(skeleton.get_bone_count()):
		skeleton_names[skeleton.get_bone_name(i).to_lower()] = skeleton.get_bone_name(i)

	var profile := SkeletonProfileHumanoid.new()
	var bone_map := BoneMap.new()
	bone_map.profile = profile

	var matched := 0
	for i in range(profile.bone_size):
		var profile_bone_name: String = profile.get_bone_name(i)
		var lower: String = profile_bone_name.to_lower()
		if skeleton_names.has(lower):
			bone_map.set_skeleton_bone_name(profile_bone_name, skeleton_names[lower])
			matched += 1

	var path: String = params.get("path", "")
	if path != "":
		if FileAccess.file_exists(path):
			return {"__error_code__": "INVALID_PARAMS", "__error_message__": "A resource already exists at %s" % path}
		var err: Error = ResourceSaver.save(bone_map, path)
		if err != OK:
			return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Could not save BoneMap: %s" % error_string(err)}

	return {"matched_count": matched, "profile_bone_count": profile.bone_size, "path": path}


static func add_look_at_modifier(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := _create(params, ei, "LookAtModifier3D")
	if node is Dictionary:
		return node
	if params.has("bone_name"):
		node.bone_name = String(params["bone_name"])
	return _describe(ei, node)


## Uses SkeletonIK3D — the long-standing scriptable IK node. Godot's newer
## modifier-based IK (SkeletonModifier3D subclasses) exists for some chain
## types but SkeletonIK3D remains the most directly scriptable general-purpose
## option for a two-bone-or-longer chain with a target.
static func add_ik_chain(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := _create(params, ei, "SkeletonIK3D")
	if node is Dictionary:
		return node
	if params.has("root_bone"):
		node.root_bone = String(params["root_bone"])
	if params.has("tip_bone"):
		node.tip_bone = String(params["tip_bone"])
	if params.has("target_node_path"):
		node.target_node = NodePath(String(params["target_node_path"]))
	return _describe(ei, node)


static func add_csg_polygon(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := _create(params, ei, "CSGPolygon3D")
	if node is Dictionary:
		return node

	var points: Array = params.get("points", [])
	var polygon := PackedVector2Array()
	for p in points:
		polygon.append(Vector2(p.get("x", 0.0), p.get("y", 0.0)))
	node.polygon = polygon

	var mode: String = params.get("mode", "depth")
	if mode == "spin":
		node.mode = CSGPolygon3D.MODE_SPIN
	elif mode == "path":
		node.mode = CSGPolygon3D.MODE_PATH
	else:
		node.mode = CSGPolygon3D.MODE_DEPTH
		if params.has("depth"):
			node.depth = float(params["depth"])

	return _describe(ei, node)


static func add_occluder_3d(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := _create(params, ei, "OccluderInstance3D")
	if node is Dictionary:
		return node
	return _describe(ei, node)
