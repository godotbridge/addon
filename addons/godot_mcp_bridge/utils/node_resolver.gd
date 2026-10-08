## Shared node_path resolution, plus node-creation helpers, for handlers that
## operate on the currently edited scene. Every node_path is relative to the
## scene root ("." means the root itself) — this is the one convention every
## handler in the addon uses, both for input params and for paths returned in
## results.
class_name GodotMCPNodeResolver
extends RefCounted


## Resolves params[key] against the currently edited scene. Returns the Node
## on success, or an error Dictionary (check `result is Dictionary`) suitable
## for returning directly from a handler.
static func resolve(params: Dictionary, ei: EditorInterface, key: String = "node_path") -> Variant:
	var node_path: String = params.get(key, "")
	if node_path == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s is required" % key}
	var root: Node = ei.get_edited_scene_root()
	if root == null:
		return {"__error_code__": "SCENE_NOT_FOUND", "__error_message__": "No scene is currently open in the editor"}
	var node := get_node(root, node_path)
	if node == null:
		return {"__error_code__": "NODE_NOT_FOUND", "__error_message__": "No node at path %s" % node_path}
	return node


static func get_node(root: Node, node_path: String) -> Node:
	if node_path == ".":
		return root
	return root.get_node_or_null(NodePath(node_path))


static func relative_path(root: Node, node: Node) -> String:
	return "." if node == root else str(root.get_path_to(node))


## After adding/duplicating nodes directly into the edited scene tree, every
## new descendant needs `owner` set to the scene root or it won't be
## serialized by save_scene/PackedScene.pack().
static func set_owner_recursive(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		set_owner_recursive(child, owner)


## Instantiates `node_type`, names it, adds it under `parent`, and sets owner
## so it serializes with the scene. Returns the new Node, or an error
## Dictionary if node_type is unknown (check `result is Dictionary`). Shared
## by every "add_<specific node type>" convenience tool across categories —
## scene_construction.gd's generic add_node included.
static func add_child_node(parent: Node, root: Node, node_type: String, node_name: String = "") -> Variant:
	var new_node: Node = ClassDB.instantiate(node_type)
	if new_node == null:
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "Unknown node class %s" % node_type}
	new_node.name = node_name if node_name != "" else node_type
	parent.add_child(new_node)
	new_node.owner = root
	return new_node
