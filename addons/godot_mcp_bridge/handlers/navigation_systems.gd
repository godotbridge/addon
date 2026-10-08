## Handlers for the navigation_systems tool category.
class_name GodotMCPNavigationSystemsHandlers
extends RefCounted

const NodeResolver = preload("res://addons/godot_mcp_bridge/utils/node_resolver.gd")


static func register(dispatch: Dictionary) -> void:
	dispatch["add_navigation_region"] = add_navigation_region
	dispatch["add_navigation_agent"] = add_navigation_agent
	dispatch["add_navigation_obstacle"] = add_navigation_obstacle
	dispatch["add_navigation_link"] = add_navigation_link
	dispatch["get_navigation_info"] = get_navigation_info
	dispatch["bake_navigation"] = bake_navigation
	dispatch["set_navigation_layers"] = set_navigation_layers


static func _create(params: Dictionary, ei: EditorInterface, node_type: String) -> Variant:
	var parent := NodeResolver.resolve(params, ei, "parent_path")
	if parent is Dictionary:
		return parent
	var root: Node = ei.get_edited_scene_root()
	return NodeResolver.add_child_node(parent, root, node_type, params.get("node_name", ""))


static func _describe(ei: EditorInterface, node: Node) -> Dictionary:
	var root: Node = ei.get_edited_scene_root()
	return {"node_path": NodeResolver.relative_path(root, node), "type": node.get_class()}


static func _dim(params: Dictionary, type_2d: String, type_3d: String) -> String:
	return type_3d if String(params.get("dimension", "2d")) == "3d" else type_2d


static func add_navigation_region(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := _create(params, ei, _dim(params, "NavigationRegion2D", "NavigationRegion3D"))
	if node is Dictionary:
		return node
	return _describe(ei, node)


static func add_navigation_agent(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := _create(params, ei, _dim(params, "NavigationAgent2D", "NavigationAgent3D"))
	if node is Dictionary:
		return node
	if params.has("radius"):
		node.radius = float(params["radius"])
	if params.has("max_speed"):
		node.max_speed = float(params["max_speed"])
	return _describe(ei, node)


static func add_navigation_obstacle(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := _create(params, ei, _dim(params, "NavigationObstacle2D", "NavigationObstacle3D"))
	if node is Dictionary:
		return node
	if params.has("radius"):
		node.radius = float(params["radius"])
	return _describe(ei, node)


static func add_navigation_link(params: Dictionary, ei: EditorInterface) -> Variant:
	var dimension: String = params.get("dimension", "2d")
	var node := _create(params, ei, _dim(params, "NavigationLink2D", "NavigationLink3D"))
	if node is Dictionary:
		return node
	if params.has("start_position"):
		var sp: Dictionary = params["start_position"]
		node.start_position = Vector3(sp.get("x", 0.0), sp.get("y", 0.0), sp.get("z", 0.0)) if dimension == "3d" else Vector2(sp.get("x", 0.0), sp.get("y", 0.0))
	if params.has("end_position"):
		var ep: Dictionary = params["end_position"]
		node.end_position = Vector3(ep.get("x", 0.0), ep.get("y", 0.0), ep.get("z", 0.0)) if dimension == "3d" else Vector2(ep.get("x", 0.0), ep.get("y", 0.0))
	return _describe(ei, node)


static func get_navigation_info(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node

	if node is NavigationRegion2D or node is NavigationRegion3D:
		var has_geometry: bool = (node is NavigationRegion2D and node.navigation_polygon != null) or (node is NavigationRegion3D and node.navigation_mesh != null)
		return {"type": node.get_class(), "enabled": node.enabled, "navigation_layers": node.navigation_layers, "has_geometry": has_geometry}
	if node is NavigationAgent2D or node is NavigationAgent3D:
		return {"type": node.get_class(), "radius": node.radius, "max_speed": node.max_speed}
	if node is NavigationObstacle2D or node is NavigationObstacle3D:
		return {"type": node.get_class(), "radius": node.radius}
	if node is NavigationLink2D or node is NavigationLink3D:
		return {"type": node.get_class(), "enabled": node.enabled, "navigation_layers": node.navigation_layers}
	return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s is not a navigation node" % node.get_class()}


static func bake_navigation(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node

	if node is NavigationRegion3D:
		if node.navigation_mesh == null:
			node.navigation_mesh = NavigationMesh.new()
		node.bake_navigation_mesh(false)
		return {"node_path": params.get("node_path", ""), "baked": true}
	if node is NavigationRegion2D:
		if node.navigation_polygon == null:
			node.navigation_polygon = NavigationPolygon.new()
		node.bake_navigation_polygon(false)
		return {"node_path": params.get("node_path", ""), "baked": true}
	return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s is not a NavigationRegion2D/3D" % node.get_class()}


static func _resolve_bitmask(value: Variant, current: int) -> int:
	if typeof(value) == TYPE_ARRAY:
		var mask := 0
		for n in value:
			mask |= 1 << (int(n) - 1)
		return mask
	if value == null:
		return current
	return int(value)


static func set_navigation_layers(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if not ("navigation_layers" in node):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s has no navigation_layers property" % node.get_class()}
	node.navigation_layers = _resolve_bitmask(params.get("layers"), node.navigation_layers)
	return {"node_path": params.get("node_path", ""), "navigation_layers": node.navigation_layers}
