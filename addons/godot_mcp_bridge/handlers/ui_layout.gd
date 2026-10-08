## Handlers for the ui_layout tool category.
class_name GodotMCPUiLayoutHandlers
extends RefCounted

const NodeResolver = preload("res://addons/godot_mcp_bridge/utils/node_resolver.gd")

const ANCHOR_PRESETS := {
	"top_left": Control.PRESET_TOP_LEFT,
	"top_right": Control.PRESET_TOP_RIGHT,
	"bottom_left": Control.PRESET_BOTTOM_LEFT,
	"bottom_right": Control.PRESET_BOTTOM_RIGHT,
	"center_left": Control.PRESET_CENTER_LEFT,
	"center_top": Control.PRESET_CENTER_TOP,
	"center_right": Control.PRESET_CENTER_RIGHT,
	"center_bottom": Control.PRESET_CENTER_BOTTOM,
	"center": Control.PRESET_CENTER,
	"top_wide": Control.PRESET_TOP_WIDE,
	"bottom_wide": Control.PRESET_BOTTOM_WIDE,
	"left_wide": Control.PRESET_LEFT_WIDE,
	"right_wide": Control.PRESET_RIGHT_WIDE,
	"vcenter_wide": Control.PRESET_VCENTER_WIDE,
	"hcenter_wide": Control.PRESET_HCENTER_WIDE,
	"full_rect": Control.PRESET_FULL_RECT,
}


static func register(dispatch: Dictionary) -> void:
	dispatch["add_ui_control"] = add_ui_control
	dispatch["set_anchors_preset"] = set_anchors_preset
	dispatch["add_ui_container"] = add_ui_container
	dispatch["set_control_style"] = set_control_style
	dispatch["set_texture_rect"] = set_texture_rect
	dispatch["set_control_icon"] = set_control_icon
	dispatch["add_progress_bar"] = add_progress_bar
	dispatch["wire_button"] = wire_button
	dispatch["load_font"] = load_font
	dispatch["set_camera_limits"] = set_camera_limits
	dispatch["configure_popup_menu"] = configure_popup_menu
	dispatch["configure_menu_bar"] = configure_menu_bar
	dispatch["set_item_list_items"] = set_item_list_items
	dispatch["set_option_button_items"] = set_option_button_items
	dispatch["add_ui_dialog"] = add_ui_dialog


static func _create(params: Dictionary, ei: EditorInterface, node_type: String) -> Variant:
	var parent := NodeResolver.resolve(params, ei, "parent_path")
	if parent is Dictionary:
		return parent
	var root: Node = ei.get_edited_scene_root()
	return NodeResolver.add_child_node(parent, root, node_type, params.get("node_name", ""))


static func _describe(ei: EditorInterface, node: Node) -> Dictionary:
	var root: Node = ei.get_edited_scene_root()
	return {"node_path": NodeResolver.relative_path(root, node), "type": node.get_class()}


static func add_ui_control(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := _create(params, ei, params.get("control_type", "Control"))
	if node is Dictionary:
		return node
	return _describe(ei, node)


static func set_anchors_preset(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if not (node is Control):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s is not a Control" % node.get_class()}

	var preset_name: String = params.get("preset", "")
	if not ANCHOR_PRESETS.has(preset_name):
		return {
			"__error_code__": "INVALID_PARAMS",
			"__error_message__": "Unknown preset '%s'. Available: %s" % [preset_name, ", ".join(ANCHOR_PRESETS.keys())],
		}
	node.set_anchors_preset(ANCHOR_PRESETS[preset_name])
	return {"node_path": params.get("node_path", ""), "preset": preset_name}


static func add_ui_container(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := _create(params, ei, params.get("container_type", "VBoxContainer"))
	if node is Dictionary:
		return node
	return _describe(ei, node)


static func set_control_style(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if not (node is Control):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s is not a Control" % node.get_class()}

	var stylebox_type: String = params.get("stylebox_type", "StyleBoxFlat")
	var stylebox: StyleBox = ClassDB.instantiate(stylebox_type)
	if stylebox == null:
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "Unknown stylebox class %s" % stylebox_type}

	var properties: Dictionary = params.get("properties", {})
	for property in properties.keys():
		var value: Variant = properties[property]
		if typeof(value) == TYPE_DICTIONARY and value.has("r") and value.has("g") and value.has("b"):
			stylebox.set(property, Color(value.get("r", 0.0), value.get("g", 0.0), value.get("b", 0.0), value.get("a", 1.0)))
		else:
			stylebox.set(property, value)

	var stylebox_name: String = params.get("stylebox_name", "panel")
	node.add_theme_stylebox_override(stylebox_name, stylebox)
	return {"node_path": params.get("node_path", ""), "stylebox_name": stylebox_name, "stylebox_type": stylebox_type}


static func set_texture_rect(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if not (node is TextureRect):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s is not a TextureRect" % node.get_class()}

	var texture_path: String = params.get("texture_path", "")
	if texture_path == "" or not FileAccess.file_exists(texture_path):
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No texture at %s" % texture_path}
	# A wrong-but-existing resource type at texture_path would otherwise crash
	# on a hard GDScript type-assignment error, not a catchable one.
	var loaded_tex: Variant = load(texture_path)
	if not (loaded_tex is Texture2D):
		return {
			"__error_code__": "RESOURCE_NOT_FOUND",
			"__error_message__": "%s is not a Texture2D resource (loaded as %s)" % [texture_path, loaded_tex.get_class() if loaded_tex != null else "null"],
		}
	node.texture = loaded_tex
	if params.has("stretch_mode"):
		node.stretch_mode = int(params["stretch_mode"])
	return {"node_path": params.get("node_path", ""), "texture_path": texture_path}


static func set_control_icon(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if not ("icon" in node):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s has no icon property" % node.get_class()}

	var texture_path: String = params.get("texture_path", "")
	if texture_path == "" or not FileAccess.file_exists(texture_path):
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No texture at %s" % texture_path}
	var loaded_tex: Variant = load(texture_path)
	if not (loaded_tex is Texture2D):
		return {
			"__error_code__": "RESOURCE_NOT_FOUND",
			"__error_message__": "%s is not a Texture2D resource (loaded as %s)" % [texture_path, loaded_tex.get_class() if loaded_tex != null else "null"],
		}
	node.icon = loaded_tex
	return {"node_path": params.get("node_path", ""), "texture_path": texture_path}


static func add_progress_bar(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := _create(params, ei, "ProgressBar")
	if node is Dictionary:
		return node
	if params.has("min_value"):
		node.min_value = float(params["min_value"])
	if params.has("max_value"):
		node.max_value = float(params["max_value"])
	if params.has("value"):
		node.value = float(params["value"])
	return _describe(ei, node)


static func wire_button(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if not (node is BaseButton):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s is not a button" % node.get_class()}

	var target_path: String = params.get("target_node_path", "")
	var method: String = params.get("method", "")
	if target_path == "" or method == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "target_node_path and method are required"}

	var target := NodeResolver.get_node(ei.get_edited_scene_root(), target_path)
	if target == null:
		return {"__error_code__": "NODE_NOT_FOUND", "__error_message__": "No node at path %s" % target_path}

	var signal_name: String = params.get("signal_name", "pressed")
	var callable := Callable(target, method)
	if node.is_connected(signal_name, callable):
		return {
			"__error_code__": "INVALID_PARAMS",
			"__error_message__": "%s is already connected to %s.%s" % [signal_name, target_path, method],
		}
	var err: Error = node.connect(signal_name, callable)
	if err != OK:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": error_string(err)}
	return {"node_path": params.get("node_path", ""), "signal_name": signal_name, "target_node_path": target_path, "method": method}


static func load_font(params: Dictionary, ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "" or not FileAccess.file_exists(path):
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No font at %s" % path}
	var loaded_font: Variant = load(path)
	if not (loaded_font is Font):
		return {
			"__error_code__": "RESOURCE_NOT_FOUND",
			"__error_message__": "%s is not a Font resource (loaded as %s)" % [path, loaded_font.get_class() if loaded_font != null else "null"],
		}

	var node_path: String = params.get("node_path", "")
	if node_path == "":
		return {"path": path, "assigned": false}

	var node := NodeResolver.get_node(ei.get_edited_scene_root(), node_path)
	if node == null or not (node is Control):
		return {"__error_code__": "NODE_NOT_FOUND", "__error_message__": "No Control at path %s" % node_path}
	node.add_theme_font_override(params.get("font_property", "font"), loaded_font)
	return {"path": path, "assigned": true, "node_path": node_path}


static func set_camera_limits(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if not (node is Camera2D):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s is not a Camera2D" % node.get_class()}

	if params.has("left"):
		node.limit_left = int(params["left"])
	if params.has("top"):
		node.limit_top = int(params["top"])
	if params.has("right"):
		node.limit_right = int(params["right"])
	if params.has("bottom"):
		node.limit_bottom = int(params["bottom"])
	return {
		"node_path": params.get("node_path", ""),
		"left": node.limit_left,
		"top": node.limit_top,
		"right": node.limit_right,
		"bottom": node.limit_bottom,
	}


static func configure_popup_menu(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if not (node is PopupMenu):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s is not a PopupMenu" % node.get_class()}
	node.clear()
	var items: Array = params.get("items", [])
	for item in items:
		if item.get("separator", false):
			node.add_separator(String(item.get("label", "")))
		else:
			var label: String = String(item.get("label", ""))
			var id: int = int(item.get("id", -1))
			node.add_item(label, id)
			if item.has("icon_path"):
				var icon: Variant = load(String(item["icon_path"]))
				if icon is Texture2D:
					node.set_item_icon(node.get_item_count() - 1, icon)
	return {"node_path": params.get("node_path", ""), "item_count": node.get_item_count()}


static func configure_menu_bar(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if not (node is MenuBar):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s is not a MenuBar" % node.get_class()}
	for child in node.get_children():
		child.queue_free()
	var menus: Array = params.get("menus", [])
	for menu_def in menus:
		var popup := PopupMenu.new()
		popup.name = String(menu_def.get("title", "Menu"))
		for item in menu_def.get("items", []):
			if item.get("separator", false):
				popup.add_separator()
			else:
				popup.add_item(String(item.get("label", "")), int(item.get("id", -1)))
		node.add_child(popup)
		popup.owner = ei.get_edited_scene_root()
	return {"node_path": params.get("node_path", ""), "menu_count": menus.size()}


static func set_item_list_items(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if not (node is ItemList):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s is not an ItemList" % node.get_class()}
	node.clear()
	var items: Array = params.get("items", [])
	for item in items:
		node.add_item(String(item.get("text", "")))
		var idx: int = node.get_item_count() - 1
		if item.has("icon_path"):
			var icon: Variant = load(String(item["icon_path"]))
			if icon is Texture2D:
				node.set_item_icon(idx, icon)
		if item.has("selectable"):
			node.set_item_selectable(idx, bool(item["selectable"]))
	return {"node_path": params.get("node_path", ""), "item_count": node.get_item_count()}


static func set_option_button_items(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if not (node is OptionButton):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s is not an OptionButton" % node.get_class()}
	node.clear()
	var items: Array = params.get("items", [])
	for item in items:
		var text: String = String(item.get("text", ""))
		var id: int = int(item.get("id", -1))
		node.add_item(text, id)
		if item.has("icon_path"):
			var icon: Variant = load(String(item["icon_path"]))
			if icon is Texture2D:
				node.set_item_icon(node.get_item_count() - 1, icon)
	return {"node_path": params.get("node_path", ""), "item_count": node.get_item_count()}


static func add_ui_dialog(params: Dictionary, ei: EditorInterface) -> Variant:
	var dialog_type: String = params.get("dialog_type", "AcceptDialog")
	var node := _create(params, ei, dialog_type)
	if node is Dictionary:
		return node
	if params.has("title"):
		node.title = String(params["title"])
	if params.has("size"):
		var sz: Dictionary = params["size"]
		node.size = Vector2i(int(sz.get("x", 200)), int(sz.get("y", 100)))
	return {"node_path": NodeResolver.relative_path(ei.get_edited_scene_root(), node), "dialog_type": dialog_type}
