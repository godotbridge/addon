## Handlers for the signal & group management tool category. All node_path
## params are resolved relative to the currently edited scene's root ("." means
## the root itself).
class_name GodotMCPSignalsGroupsHandlers
extends RefCounted

const NodeResolver = preload("res://addons/godot_mcp_bridge/utils/node_resolver.gd")


static func register(dispatch: Dictionary) -> void:
	dispatch["list_signals"] = list_signals
	dispatch["list_connections"] = list_connections
	dispatch["disconnect_signal"] = disconnect_signal
	dispatch["list_groups"] = list_groups
	dispatch["add_to_group"] = add_to_group
	dispatch["remove_from_group"] = remove_from_group
	dispatch["list_nodes_in_group"] = list_nodes_in_group


static func list_signals(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	var signals: Array = []
	for sig in node.get_signal_list():
		var arg_names: Array = []
		for arg in sig.get("args", []):
			arg_names.append(arg.get("name", ""))
		signals.append({"name": sig.get("name", ""), "args": arg_names})
	return {"signals": signals}


static func list_connections(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	var root: Node = ei.get_edited_scene_root()
	var connections: Array = []
	for sig in node.get_signal_list():
		var signal_name: String = sig.get("name", "")
		for conn in node.get_signal_connection_list(signal_name):
			var callable: Callable = conn.get("callable")
			var target: Object = callable.get_object()
			# A target outside the edited scene (e.g. an editor-internal
			# listener) has no meaningful relative path, so it's reported
			# as an absolute one instead.
			var target_path := ""
			if target is Node:
				var target_in_scene: bool = root != null and (target == root or root.is_ancestor_of(target))
				target_path = NodeResolver.relative_path(root, target) if target_in_scene else str(target.get_path())
			connections.append({
				"signal": signal_name,
				"target": target_path,
				"method": str(callable.get_method()),
			})
	return {"connections": connections}


static func disconnect_signal(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node

	var signal_name: String = params.get("signal_name", "")
	var target_path: String = params.get("target_node_path", "")
	var method: String = params.get("method", "")
	if signal_name == "" or target_path == "" or method == "":
		return {
			"__error_code__": "INVALID_PARAMS",
			"__error_message__": "signal_name, target_node_path, and method are required",
		}

	var target := NodeResolver.get_node(ei.get_edited_scene_root(), target_path)
	if target == null:
		return {"__error_code__": "NODE_NOT_FOUND", "__error_message__": "No node at path %s" % target_path}

	var callable := Callable(target, method)
	if not node.is_connected(signal_name, callable):
		return {
			"__error_code__": "INVALID_PARAMS",
			"__error_message__": "%s is not connected to %s.%s" % [signal_name, target_path, method],
		}
	node.disconnect(signal_name, callable)
	return {"signal_name": signal_name, "target_node_path": target_path, "method": method}


static func list_groups(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	var groups: Array = []
	for g in node.get_groups():
		groups.append(str(g))
	return {"groups": groups}


static func add_to_group(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	var group_name: String = params.get("group_name", "")
	if group_name == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "group_name is required"}
	node.add_to_group(group_name)
	return {"node_path": params.get("node_path", ""), "group_name": group_name}


static func remove_from_group(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	var group_name: String = params.get("group_name", "")
	if group_name == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "group_name is required"}
	node.remove_from_group(group_name)
	return {"node_path": params.get("node_path", ""), "group_name": group_name}


static func list_nodes_in_group(params: Dictionary, ei: EditorInterface) -> Variant:
	var group_name: String = params.get("group_name", "")
	if group_name == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "group_name is required"}
	var root: Node = ei.get_edited_scene_root()
	if root == null:
		return {"__error_code__": "SCENE_NOT_FOUND", "__error_message__": "No scene is currently open in the editor"}
	var matches: Array = []
	_collect_group_members(root, root, group_name, matches)
	return {"nodes": matches}


static func _collect_group_members(node: Node, root: Node, group_name: String, out: Array) -> void:
	if node.is_in_group(group_name):
		out.append(NodeResolver.relative_path(root, node))
	for child in node.get_children():
		_collect_group_members(child, root, group_name, out)
