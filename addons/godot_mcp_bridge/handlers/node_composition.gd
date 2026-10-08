## Handlers for the node_composition tool category — thin, semantically-named
## wrappers over NodeResolver.add_child_node so callers don't need to know
## exact Godot class names. Each accepts an optional `dimension` ("2d" or
## "3d", default "2d") where Godot has separate 2D/3D classes for the concept.
class_name GodotMCPNodeCompositionHandlers
extends RefCounted

const NodeResolver = preload("res://addons/godot_mcp_bridge/utils/node_resolver.gd")


static func register(dispatch: Dictionary) -> void:
	dispatch["add_marker"] = add_marker
	dispatch["add_remote_transform"] = add_remote_transform
	dispatch["add_path"] = add_path
	dispatch["add_path_follow"] = add_path_follow
	dispatch["add_visibility_notifier"] = add_visibility_notifier


static func add_marker(params: Dictionary, ei: EditorInterface) -> Variant:
	return _add_and_describe(params, ei, _dim(params, "Marker2D", "Marker3D"))


static func add_remote_transform(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := _create(params, ei, _dim(params, "RemoteTransform2D", "RemoteTransform3D"))
	if node is Dictionary:
		return node
	if params.has("remote_path"):
		node.remote_path = NodePath(String(params["remote_path"]))
	return _result(ei, node)


static func add_path(params: Dictionary, ei: EditorInterface) -> Variant:
	return _add_and_describe(params, ei, _dim(params, "Path2D", "Path3D"))


static func add_path_follow(params: Dictionary, ei: EditorInterface) -> Variant:
	return _add_and_describe(params, ei, _dim(params, "PathFollow2D", "PathFollow3D"))


static func add_visibility_notifier(params: Dictionary, ei: EditorInterface) -> Variant:
	return _add_and_describe(params, ei, _dim(params, "VisibleOnScreenNotifier2D", "VisibleOnScreenNotifier3D"))


static func _dim(params: Dictionary, node_type_2d: String, node_type_3d: String) -> String:
	return node_type_3d if String(params.get("dimension", "2d")) == "3d" else node_type_2d


## Instantiates node_type under parent_path. Returns the raw Node (for callers
## that need to set extra properties before describing it) or an error
## Dictionary — never the final result shape; use _add_and_describe or wrap
## with _result yourself.
static func _create(params: Dictionary, ei: EditorInterface, node_type: String) -> Variant:
	var parent := NodeResolver.resolve(params, ei, "parent_path")
	if parent is Dictionary:
		return parent
	var root: Node = ei.get_edited_scene_root()
	return NodeResolver.add_child_node(parent, root, node_type, params.get("node_name", ""))


static func _add_and_describe(params: Dictionary, ei: EditorInterface, node_type: String) -> Variant:
	var node := _create(params, ei, node_type)
	if node is Dictionary:
		return node
	return _result(ei, node)


static func _result(ei: EditorInterface, node: Node) -> Dictionary:
	var root: Node = ei.get_edited_scene_root()
	return {"node_path": NodeResolver.relative_path(root, node), "type": node.get_class()}
