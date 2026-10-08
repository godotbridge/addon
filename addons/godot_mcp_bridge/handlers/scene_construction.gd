## Handlers for the scene_construction tool category — the largest category:
## building and editing scenes in the editor's currently open scene. All
## node_path params are relative to the scene root ("." means the root
## itself), matching every other handler's convention (see NodeResolver).
class_name GodotMCPSceneConstructionHandlers
extends RefCounted

const NodeResolver = preload("res://addons/godot_mcp_bridge/utils/node_resolver.gd")


static func register(dispatch: Dictionary) -> void:
	dispatch["open_scene"] = open_scene
	dispatch["create_scene"] = create_scene
	dispatch["save_scene"] = save_scene
	dispatch["save_branch_as_scene"] = save_branch_as_scene
	dispatch["add_node"] = add_node
	dispatch["add_timer"] = add_timer
	dispatch["instance_scene"] = instance_scene
	dispatch["duplicate_node"] = duplicate_node
	dispatch["delete_node"] = delete_node
	dispatch["rename_node"] = rename_node
	dispatch["reparent_node"] = reparent_node
	dispatch["replace_node_type"] = replace_node_type
	dispatch["set_unique_name"] = set_unique_name
	dispatch["connect_signal"] = connect_signal
	dispatch["find_nodes"] = find_nodes
	dispatch["get_node_properties"] = get_node_properties
	dispatch["set_node_property"] = set_node_property
	dispatch["set_node_properties"] = set_node_properties
	dispatch["batch_set_property"] = batch_set_property
	dispatch["batch_get_properties"] = batch_get_properties
	dispatch["set_property_across_scenes"] = set_property_across_scenes


# --- Scene lifecycle -------------------------------------------------------

static func open_scene(params: Dictionary, ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "" or not FileAccess.file_exists(path):
		return {"__error_code__": "SCENE_NOT_FOUND", "__error_message__": "No scene at %s" % path}

	# open_scene_from_path() doesn't synchronously update
	# get_edited_scene_root(), and — under --headless specifically — has been
	# observed to sometimes not switch at all on the first call (root cause
	# not pinned down after testing several theories: dirty-scene dialogs,
	# main_scene special-casing, autoload registration, stale UID cache —
	# none of them were it). Rather than chase the exact cause further, retry
	# the call itself: wait a few frames for the switch, and if it hasn't
	# landed, call open_scene_from_path() again. Empirically reliable even
	# though the root cause of the first-attempt failure isn't understood.
	var tree := Engine.get_main_loop() as SceneTree
	for attempt in range(5):
		ei.open_scene_from_path(path)
		for _i in range(30):
			var root := ei.get_edited_scene_root()
			if root != null and root.scene_file_path == path:
				return {"path": path}
			await tree.process_frame
	return {"path": path}


static func create_scene(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	var root_type: String = params.get("root_type", "Node")
	if path == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "path is required"}
	if FileAccess.file_exists(path):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "A scene already exists at %s" % path}

	var root: Node = ClassDB.instantiate(root_type)
	if root == null:
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "Unknown node class %s" % root_type}
	root.name = path.get_file().get_basename()

	var packed := PackedScene.new()
	packed.pack(root)
	var err: Error = ResourceSaver.save(packed, path)
	root.free()
	if err != OK:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Could not save scene: %s" % error_string(err)}
	return {"path": path, "root_type": root_type}


static func save_scene(_params: Dictionary, ei: EditorInterface) -> Variant:
	var root: Node = ei.get_edited_scene_root()
	if root == null:
		return {"__error_code__": "SCENE_NOT_FOUND", "__error_message__": "No scene is currently open in the editor"}
	var path: String = root.scene_file_path
	if path == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "The edited scene has never been saved to a path"}

	var packed := PackedScene.new()
	var pack_err: Error = packed.pack(root)
	if pack_err != OK:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Could not pack scene: %s" % error_string(pack_err)}
	var save_err: Error = ResourceSaver.save(packed, path)
	if save_err != OK:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Could not save scene: %s" % error_string(save_err)}
	return {"path": path}


## Writes the subtree at node_path to a new scene file at `path`. This exports
## a copy for reuse — unlike the editor's own "Save Branch as Scene" command it
## does NOT replace the original node in the current scene with an instance of
## the new file; that in-place-replace behavior is a possible future addition.
static func save_branch_as_scene(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	var path: String = params.get("path", "")
	if path == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "path is required"}
	if FileAccess.file_exists(path):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "A scene already exists at %s" % path}

	var branch: Node = node.duplicate()
	branch.owner = null
	NodeResolver.set_owner_recursive(branch, branch)

	var packed := PackedScene.new()
	var pack_err: Error = packed.pack(branch)
	branch.free()
	if pack_err != OK:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Could not pack branch: %s" % error_string(pack_err)}

	var save_err: Error = ResourceSaver.save(packed, path)
	if save_err != OK:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Could not save scene: %s" % error_string(save_err)}
	return {"path": path}


# --- Node creation / structure ----------------------------------------------

static func add_node(params: Dictionary, ei: EditorInterface) -> Variant:
	var parent := NodeResolver.resolve(params, ei, "parent_path")
	if parent is Dictionary:
		return parent

	var node_type: String = params.get("node_type", "")
	if node_type == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "node_type is required"}

	var root: Node = ei.get_edited_scene_root()
	var new_node := NodeResolver.add_child_node(parent, root, node_type, params.get("node_name", ""))
	if new_node is Dictionary:
		return new_node
	return {"node_path": NodeResolver.relative_path(root, new_node)}


static func add_timer(params: Dictionary, ei: EditorInterface) -> Variant:
	var parent := NodeResolver.resolve(params, ei, "parent_path")
	if parent is Dictionary:
		return parent

	var timer := Timer.new()
	timer.name = params.get("node_name", "Timer")
	timer.wait_time = float(params.get("wait_time", 1.0))
	timer.one_shot = bool(params.get("one_shot", false))
	timer.autostart = bool(params.get("autostart", false))

	parent.add_child(timer)
	timer.owner = ei.get_edited_scene_root()
	return {"node_path": NodeResolver.relative_path(ei.get_edited_scene_root(), timer)}


static func instance_scene(params: Dictionary, ei: EditorInterface) -> Variant:
	var parent := NodeResolver.resolve(params, ei, "parent_path")
	if parent is Dictionary:
		return parent

	var scene_path: String = params.get("scene_path", "")
	if scene_path == "" or not FileAccess.file_exists(scene_path):
		return {"__error_code__": "SCENE_NOT_FOUND", "__error_message__": "No scene at %s" % scene_path}

	var packed: Variant = load(scene_path)
	if not (packed is PackedScene):
		return {
			"__error_code__": "SCENE_NOT_FOUND",
			"__error_message__": "%s is not a scene (loaded as %s)" % [scene_path, packed.get_class() if packed != null else "null"],
		}
	var instance: Node = packed.instantiate()
	if params.has("node_name"):
		instance.name = params["node_name"]

	parent.add_child(instance)
	instance.owner = ei.get_edited_scene_root()
	return {"node_path": NodeResolver.relative_path(ei.get_edited_scene_root(), instance)}


static func duplicate_node(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if node == ei.get_edited_scene_root():
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "Cannot duplicate the scene root"}

	var dup: Node = node.duplicate()
	if params.has("node_name"):
		dup.name = params["node_name"]
	node.get_parent().add_child(dup)
	var root: Node = ei.get_edited_scene_root()
	dup.owner = root
	NodeResolver.set_owner_recursive(dup, root)
	return {"node_path": NodeResolver.relative_path(root, dup)}


static func delete_node(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if node == ei.get_edited_scene_root():
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "Cannot delete the scene root"}
	var deleted_path: String = NodeResolver.relative_path(ei.get_edited_scene_root(), node)
	node.get_parent().remove_child(node)
	node.queue_free()
	return {"node_path": deleted_path}


static func rename_node(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	var new_name: String = params.get("new_name", "")
	if new_name == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "new_name is required"}
	node.name = new_name
	return {"node_path": NodeResolver.relative_path(ei.get_edited_scene_root(), node)}


static func reparent_node(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if node == ei.get_edited_scene_root():
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "Cannot reparent the scene root"}

	var new_parent := NodeResolver.resolve(params, ei, "new_parent_path")
	if new_parent is Dictionary:
		return new_parent
	if new_parent == node or node.is_ancestor_of(new_parent):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "Cannot reparent a node under its own descendant"}

	node.get_parent().remove_child(node)
	new_parent.add_child(node)
	var root: Node = ei.get_edited_scene_root()
	node.owner = root
	NodeResolver.set_owner_recursive(node, root)
	return {"node_path": NodeResolver.relative_path(root, node)}


## Swaps a node's class while preserving its children and name, and copying
## over any property values the new type also declares. Properties unique to
## the old type are dropped; this is a best-effort migration, not a lossless one.
static func replace_node_type(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if node == ei.get_edited_scene_root():
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "Cannot replace the scene root's type"}

	var new_type: String = params.get("new_type", "")
	if new_type == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "new_type is required"}
	var replacement: Node = ClassDB.instantiate(new_type)
	if replacement == null:
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "Unknown node class %s" % new_type}

	replacement.name = node.name
	for prop in node.get_property_list():
		var name: String = prop.get("name", "")
		if name == "" or not (prop.get("usage", 0) & PROPERTY_USAGE_STORAGE):
			continue
		if name in ["script"]:
			continue
		var current_value: Variant = node.get(name)
		# Silently skip properties the new type doesn't declare — Godot logs a
		# warning for unknown properties but does not raise an error.
		replacement.set(name, current_value)

	var parent: Node = node.get_parent()
	var index: int = node.get_index()
	for child in node.get_children():
		node.remove_child(child)
		replacement.add_child(child)

	parent.remove_child(node)
	parent.add_child(replacement)
	parent.move_child(replacement, index)
	var root: Node = ei.get_edited_scene_root()
	replacement.owner = root
	NodeResolver.set_owner_recursive(replacement, root)
	node.queue_free()

	return {"node_path": NodeResolver.relative_path(root, replacement), "new_type": new_type}


static func set_unique_name(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	node.unique_name_in_owner = bool(params.get("enabled", true))
	return {"node_path": params.get("node_path", ""), "enabled": node.unique_name_in_owner}


static func connect_signal(params: Dictionary, ei: EditorInterface) -> Variant:
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
	if node.is_connected(signal_name, callable):
		return {
			"__error_code__": "INVALID_PARAMS",
			"__error_message__": "%s is already connected to %s.%s" % [signal_name, target_path, method],
		}
	var err: Error = node.connect(signal_name, callable)
	if err != OK:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": error_string(err)}
	return {"signal_name": signal_name, "target_node_path": target_path, "method": method}


static func find_nodes(params: Dictionary, ei: EditorInterface) -> Variant:
	var root: Node = ei.get_edited_scene_root()
	if root == null:
		return {"__error_code__": "SCENE_NOT_FOUND", "__error_message__": "No scene is currently open in the editor"}

	var class_filter: String = params.get("class_name", "")
	var name_pattern: String = params.get("name_pattern", "")

	var matches: Array = []
	_find_nodes_recursive(root, root, class_filter, name_pattern, matches)
	return {"nodes": matches}


static func _find_nodes_recursive(node: Node, root: Node, class_filter: String, name_pattern: String, out: Array) -> void:
	var class_ok: bool = class_filter == "" or node.is_class(class_filter)
	var name_ok: bool = name_pattern == "" or String(node.name).matchn(name_pattern)
	if class_ok and name_ok:
		out.append({
			"node_path": NodeResolver.relative_path(root, node),
			"type": node.get_class(),
			"name": node.name,
		})
	for child in node.get_children():
		_find_nodes_recursive(child, root, class_filter, name_pattern, out)


# --- Properties --------------------------------------------------------------

static func get_node_properties(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node

	var requested: Array = params.get("properties", [])
	var result := {}
	if requested.is_empty():
		for prop in node.get_property_list():
			var name: String = prop.get("name", "")
			if name != "" and (prop.get("usage", 0) & PROPERTY_USAGE_STORAGE):
				result[name] = node.get(name)
	else:
		for name in requested:
			result[name] = node.get(name)
	return {"properties": result}


static func set_node_property(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	var property: String = params.get("property", "")
	if property == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "property is required"}
	node.set(property, params.get("value"))
	return {"node_path": params.get("node_path", ""), "property": property, "value": node.get(property)}


static func set_node_properties(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	var properties: Dictionary = params.get("properties", {})
	for property in properties.keys():
		node.set(property, properties[property])
	return {"node_path": params.get("node_path", ""), "properties": properties.keys()}


static func batch_set_property(params: Dictionary, ei: EditorInterface) -> Variant:
	var node_paths: Array = params.get("node_paths", [])
	var property: String = params.get("property", "")
	if property == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "property is required"}
	var root: Node = ei.get_edited_scene_root()
	if root == null:
		return {"__error_code__": "SCENE_NOT_FOUND", "__error_message__": "No scene is currently open in the editor"}

	var updated: Array = []
	var errors: Array = []
	for node_path in node_paths:
		var node := NodeResolver.get_node(root, node_path)
		if node == null:
			errors.append({"node_path": node_path, "error": "NODE_NOT_FOUND"})
			continue
		node.set(property, params.get("value"))
		updated.append(node_path)
	return {"updated": updated, "errors": errors}


static func batch_get_properties(params: Dictionary, ei: EditorInterface) -> Variant:
	var node_paths: Array = params.get("node_paths", [])
	var property: String = params.get("property", "")
	if property == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "property is required"}
	var root: Node = ei.get_edited_scene_root()
	if root == null:
		return {"__error_code__": "SCENE_NOT_FOUND", "__error_message__": "No scene is currently open in the editor"}

	var values := {}
	var errors: Array = []
	for node_path in node_paths:
		var node := NodeResolver.get_node(root, node_path)
		if node == null:
			errors.append({"node_path": node_path, "error": "NODE_NOT_FOUND"})
			continue
		values[node_path] = node.get(property)
	return {"values": values, "errors": errors}


## Unlike every other scene_construction tool, this operates directly on
## scene *files* rather than the editor's currently open scene — it loads
## each scene, applies the property, and re-saves it.
static func set_property_across_scenes(params: Dictionary, _ei: EditorInterface) -> Variant:
	var scene_paths: Array = params.get("scene_paths", [])
	var node_path: String = params.get("node_path", "")
	var property: String = params.get("property", "")
	if node_path == "" or property == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "node_path and property are required"}

	var updated: Array = []
	var errors: Array = []
	for scene_path in scene_paths:
		if not FileAccess.file_exists(scene_path):
			errors.append({"scene_path": scene_path, "error": "SCENE_NOT_FOUND"})
			continue
		var packed: Variant = load(scene_path)
		if not (packed is PackedScene):
			errors.append({"scene_path": scene_path, "error": "SCENE_NOT_FOUND"})
			continue
		var instance: Node = packed.instantiate()
		var target := NodeResolver.get_node(instance, node_path)
		if target == null:
			errors.append({"scene_path": scene_path, "error": "NODE_NOT_FOUND"})
			instance.free()
			continue

		target.set(property, params.get("value"))
		var new_packed := PackedScene.new()
		new_packed.pack(instance)
		var err: Error = ResourceSaver.save(new_packed, scene_path)
		instance.free()
		if err != OK:
			errors.append({"scene_path": scene_path, "error": error_string(err)})
			continue
		updated.append(scene_path)

	return {"updated": updated, "errors": errors}
