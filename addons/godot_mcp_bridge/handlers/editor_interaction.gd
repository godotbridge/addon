## Handlers for the editor_interaction tool category.
class_name GodotMCPEditorInteractionHandlers
extends RefCounted

const NodeResolver = preload("res://addons/godot_mcp_bridge/utils/node_resolver.gd")


static func register(dispatch: Dictionary) -> void:
	dispatch["get_scene_tree"] = get_scene_tree
	dispatch["editor_undo"] = editor_undo
	dispatch["editor_redo"] = editor_redo
	dispatch["get_editor_screenshot"] = get_editor_screenshot
	dispatch["get_selection"] = get_selection
	dispatch["select_node"] = select_node
	dispatch["describe_scene_visual"] = describe_scene_visual
	dispatch["get_bridge_status"] = get_bridge_status
	dispatch["get_agent_content_info"] = get_agent_content_info


static func get_scene_tree(_params: Dictionary, ei: EditorInterface) -> Dictionary:
	var root := ei.get_edited_scene_root()
	if root == null:
		return {"root": null}
	return {"root": _describe_node(root, root)}


## `path` is relative to `root` (the scene root itself is "."), matching the
## node_path convention every other handler expects back as input — not the
## live editor's absolute in-tree path, which is an internal implementation
## detail (the edited scene is embedded inside the editor's own dock UI).
static func _describe_node(node: Node, root: Node) -> Dictionary:
	var children: Array = []
	for child in node.get_children():
		children.append(_describe_node(child, root))
	var path: String = NodeResolver.relative_path(root, node)
	return {
		"name": node.name,
		"type": node.get_class(),
		"path": path,
		"children": children,
	}


## EditorUndoRedoManager itself has no undo()/redo() — only the specific
## UndoRedo returned by get_history_undo_redo(id) does. Most in-scene edits
## (moving/renaming/reparenting a node, editor-UI property changes) are
## recorded under that scene's own history, not the global one, since every
## open scene tab keeps an independent undo stack — so resolve the history id
## from the currently edited scene root first, falling back to the global
## history for actions that aren't scene-scoped (e.g. project settings).
static func _current_history_id(ei: EditorInterface) -> int:
	var urm := ei.get_editor_undo_redo()
	var root := ei.get_edited_scene_root()
	if root != null:
		return urm.get_object_history_id(root)
	return EditorUndoRedoManager.GLOBAL_HISTORY


static func editor_undo(_params: Dictionary, ei: EditorInterface) -> Dictionary:
	var urm := ei.get_editor_undo_redo()
	urm.get_history_undo_redo(_current_history_id(ei)).undo()
	return {"success": true}


static func editor_redo(_params: Dictionary, ei: EditorInterface) -> Dictionary:
	var urm := ei.get_editor_undo_redo()
	urm.get_history_undo_redo(_current_history_id(ei)).redo()
	return {"success": true}


## Base64 is the default for backward compatibility, but a full editor
## screenshot easily runs to hundreds of KB of base64 text — copy-pasting
## that through a UI (an MCP client's results panel, the OS clipboard) is
## fragile and prone to silent truncation/corruption. Pass save_path to skip
## all of that and get a real file back instead.
static func get_editor_screenshot(params: Dictionary, ei: EditorInterface) -> Variant:
	var viewport := ei.get_editor_main_screen().get_viewport()
	var texture := viewport.get_texture()
	var img: Image = texture.get_image() if texture != null else null
	if img == null:
		return {
			"__error_code__": "INTERNAL_ERROR",
			"__error_message__": "Editor viewport has no readable texture (no rendering backend available, e.g. under --headless)",
		}
	var result: Dictionary = {"width": img.get_width(), "height": img.get_height()}

	var save_path: String = params.get("save_path", "")
	if save_path != "":
		var err := img.save_png(save_path)
		if err != OK:
			return {
				"__error_code__": "SAVE_FAILED",
				"__error_message__": "Failed to save screenshot to %s: %s" % [save_path, error_string(err)],
			}
		result["path"] = ProjectSettings.globalize_path(save_path)
	else:
		result["image_base64"] = Marshalls.raw_to_base64(img.save_png_to_buffer())

	return result


static func get_selection(_params: Dictionary, ei: EditorInterface) -> Dictionary:
	var selection := ei.get_selection()
	var selected := selection.get_selected_nodes()
	var result: Array = []
	var root := ei.get_edited_scene_root()
	for node in selected:
		result.append({
			"name": node.name,
			"type": node.get_class(),
			"path": NodeResolver.relative_path(root, node) if root else str(node.name),
		})
	return {"selected_nodes": result}


static func select_node(params: Dictionary, ei: EditorInterface) -> Variant:
	var target = NodeResolver.resolve(params, ei)
	if target is Dictionary:
		return target
	var selection := ei.get_selection()
	selection.clear()
	selection.add_node(target)
	return {"selected": true, "node_path": params.get("node_path", "")}


static func describe_scene_visual(params: Dictionary, ei: EditorInterface) -> Variant:
	var root := ei.get_edited_scene_root()
	if root == null:
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No scene is open"}
	var node_path: String = params.get("node_path", "")
	var start: Node = root
	if node_path != "":
		start = NodeResolver.get_node(root, node_path)
		if start == null:
			return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "Node not found: %s" % node_path}
	return {"nodes": _describe_visual_tree(start, root)}


static func _describe_visual_tree(node: Node, root: Node) -> Array:
	var result: Array = []
	var entry: Dictionary = {
		"name": node.name,
		"type": node.get_class(),
		"path": NodeResolver.relative_path(root, node),
		"visible": node.visible if node is CanvasItem or node is Node3D else true,
	}
	if node is Node2D:
		entry["position"] = {"x": node.position.x, "y": node.position.y}
		entry["rotation"] = node.rotation
		entry["scale"] = {"x": node.scale.x, "y": node.scale.y}
		entry["z_index"] = node.z_index
	elif node is Control:
		entry["position"] = {"x": node.position.x, "y": node.position.y}
		entry["size"] = {"x": node.size.x, "y": node.size.y}
		entry["anchors"] = {
			"left": node.anchor_left, "top": node.anchor_top,
			"right": node.anchor_right, "bottom": node.anchor_bottom,
		}
	elif node is Node3D:
		var t: Transform3D = (node as Node3D).transform
		entry["position"] = {"x": t.origin.x, "y": t.origin.y, "z": t.origin.z}
		entry["rotation"] = {"x": node.rotation.x, "y": node.rotation.y, "z": node.rotation.z}
		entry["scale"] = {"x": node.scale.x, "y": node.scale.y, "z": node.scale.z}
	result.append(entry)
	for child in node.get_children():
		result.append_array(_describe_visual_tree(child, root))
	return result


static func get_bridge_status(_params: Dictionary, ei: EditorInterface) -> Dictionary:
	var info: Dictionary = {}
	info["connected"] = true
	info["godot_version"] = Engine.get_version_info().string
	var project_name: String = ProjectSettings.get_setting("application/config/name", "")
	info["project_name"] = project_name
	return info


static func get_agent_content_info(_params: Dictionary, _ei: EditorInterface) -> Dictionary:
	var plugin_cfg := ConfigFile.new()
	var version := "unknown"
	if plugin_cfg.load("res://addons/godot_mcp_bridge/plugin.cfg") == OK:
		version = plugin_cfg.get_value("plugin", "version", "unknown")
	return {
		"version": version,
		"godot_version": Engine.get_version_info().string,
		"capabilities": ["editor_control", "runtime_monitoring", "scene_management", "resource_authoring"],
	}
