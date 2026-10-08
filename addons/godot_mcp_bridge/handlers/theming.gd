## Handlers for the theming tool category. Every tool except assign_theme
## operates on a Theme resource file at `path` (loading, mutating, and
## re-saving it), not on a live node.
class_name GodotMCPThemingHandlers
extends RefCounted

const NodeResolver = preload("res://addons/godot_mcp_bridge/utils/node_resolver.gd")


static func register(dispatch: Dictionary) -> void:
	dispatch["create_theme"] = create_theme
	dispatch["set_theme_color"] = set_theme_color
	dispatch["set_theme_constant"] = set_theme_constant
	dispatch["set_theme_font_size"] = set_theme_font_size
	dispatch["get_theme_info"] = get_theme_info
	dispatch["assign_theme"] = assign_theme
	dispatch["set_theme_stylebox"] = set_theme_stylebox
	dispatch["configure_theme"] = configure_theme
	dispatch["merge_theme"] = merge_theme


static func _color(d: Dictionary) -> Color:
	return Color(d.get("r", 0.0), d.get("g", 0.0), d.get("b", 0.0), d.get("a", 1.0))


static func _color_to_dict(c: Color) -> Dictionary:
	return {"r": c.r, "g": c.g, "b": c.b, "a": c.a}


static func _load_theme(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No theme at %s" % path}
	# A wrong-but-existing resource type at path (e.g. a .tscn) would
	# otherwise crash every caller of this helper on static assignment —
	# "Trying to assign value of type 'PackedScene' to a variable of type
	# 'Theme'" is a hard GDScript type error, not a catchable one.
	var loaded: Variant = load(path)
	if not (loaded is Theme):
		return {
			"__error_code__": "RESOURCE_NOT_FOUND",
			"__error_message__": "%s is not a Theme resource (loaded as %s)" % [path, loaded.get_class() if loaded != null else "null"],
		}
	return loaded


static func _save_theme(theme: Theme, path: String) -> Variant:
	var err: Error = ResourceSaver.save(theme, path)
	if err != OK:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Could not save theme: %s" % error_string(err)}
	return null


static func create_theme(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "path is required"}
	if FileAccess.file_exists(path):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "A theme already exists at %s" % path}
	var theme := Theme.new()
	var save_err := _save_theme(theme, path)
	if save_err != null:
		return save_err
	return {"path": path}


static func set_theme_color(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	var theme := _load_theme(path)
	if theme is Dictionary:
		return theme
	var color_name: String = params.get("color_name", "")
	var node_type: String = params.get("node_type", "")
	theme.set_color(color_name, node_type, _color(params.get("color", {})))
	var save_err := _save_theme(theme, path)
	if save_err != null:
		return save_err
	return {"path": path, "color_name": color_name, "node_type": node_type}


static func set_theme_constant(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	var theme := _load_theme(path)
	if theme is Dictionary:
		return theme
	var constant_name: String = params.get("constant_name", "")
	var node_type: String = params.get("node_type", "")
	theme.set_constant(constant_name, node_type, int(params.get("value", 0)))
	var save_err := _save_theme(theme, path)
	if save_err != null:
		return save_err
	return {"path": path, "constant_name": constant_name, "node_type": node_type}


static func set_theme_font_size(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	var theme := _load_theme(path)
	if theme is Dictionary:
		return theme
	var font_size_name: String = params.get("font_size_name", "")
	var node_type: String = params.get("node_type", "")
	theme.set_font_size(font_size_name, node_type, int(params.get("size", 16)))
	var save_err := _save_theme(theme, path)
	if save_err != null:
		return save_err
	return {"path": path, "font_size_name": font_size_name, "node_type": node_type}


static func set_theme_stylebox(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	var theme := _load_theme(path)
	if theme is Dictionary:
		return theme

	var stylebox_type: String = params.get("stylebox_type", "StyleBoxFlat")
	var stylebox: StyleBox = ClassDB.instantiate(stylebox_type)
	if stylebox == null:
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "Unknown stylebox class %s" % stylebox_type}

	var properties: Dictionary = params.get("properties", {})
	for property in properties.keys():
		var value: Variant = properties[property]
		# Color-shaped properties (e.g. StyleBoxFlat.bg_color) arrive as
		# {r,g,b,a} dicts over JSON; convert them rather than assigning a
		# raw Dictionary to a Color-typed property.
		if typeof(value) == TYPE_DICTIONARY and value.has("r") and value.has("g") and value.has("b"):
			stylebox.set(property, _color(value))
		else:
			stylebox.set(property, value)

	var stylebox_name: String = params.get("stylebox_name", "")
	var node_type: String = params.get("node_type", "")
	theme.set_stylebox(stylebox_name, node_type, stylebox)
	var save_err := _save_theme(theme, path)
	if save_err != null:
		return save_err
	return {"path": path, "stylebox_name": stylebox_name, "node_type": node_type, "stylebox_type": stylebox_type}


static func get_theme_info(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	var theme := _load_theme(path)
	if theme is Dictionary:
		return theme

	var types := {}
	for node_type in theme.get_type_list():
		types[node_type] = {
			"colors": Array(theme.get_color_list(node_type)),
			"constants": Array(theme.get_constant_list(node_type)),
			"font_sizes": Array(theme.get_font_size_list(node_type)),
			"styleboxes": Array(theme.get_stylebox_list(node_type)),
		}
	return {"path": path, "types": types}


static func configure_theme(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "path is required"}

	var theme: Variant
	if FileAccess.file_exists(path):
		theme = _load_theme(path)
		if theme is Dictionary:
			return theme
	else:
		theme = Theme.new()

	# Type variations: {child_type: base_type}
	var type_variations: Dictionary = params.get("type_variations", {})
	for child_type in type_variations.keys():
		theme.set_type_variation(String(child_type), String(type_variations[child_type]))

	# Colors: {node_type: {color_name: {r,g,b,a}}}
	var colors: Dictionary = params.get("colors", {})
	for node_type in colors.keys():
		var entries: Dictionary = colors[node_type]
		for color_name in entries.keys():
			theme.set_color(String(color_name), String(node_type), _color(entries[color_name]))

	# Constants: {node_type: {constant_name: value}}
	var constants: Dictionary = params.get("constants", {})
	for node_type in constants.keys():
		var entries: Dictionary = constants[node_type]
		for constant_name in entries.keys():
			theme.set_constant(String(constant_name), String(node_type), int(entries[constant_name]))

	# Font sizes: {node_type: {font_size_name: size}}
	var font_sizes: Dictionary = params.get("font_sizes", {})
	for node_type in font_sizes.keys():
		var entries: Dictionary = font_sizes[node_type]
		for font_size_name in entries.keys():
			theme.set_font_size(String(font_size_name), String(node_type), int(entries[font_size_name]))

	# Styleboxes: {node_type: {stylebox_name: {type: "StyleBoxFlat", properties: {...}}}}
	var styleboxes: Dictionary = params.get("styleboxes", {})
	for node_type in styleboxes.keys():
		var entries: Dictionary = styleboxes[node_type]
		for sb_name in entries.keys():
			var sb_config: Dictionary = entries[sb_name]
			var sb_type: String = sb_config.get("type", "StyleBoxFlat")
			var stylebox: StyleBox = ClassDB.instantiate(sb_type)
			if stylebox == null:
				continue
			var properties: Dictionary = sb_config.get("properties", {})
			for prop in properties.keys():
				var value: Variant = properties[prop]
				if typeof(value) == TYPE_DICTIONARY and value.has("r") and value.has("g") and value.has("b"):
					stylebox.set(prop, _color(value))
				else:
					stylebox.set(prop, value)
			theme.set_stylebox(String(sb_name), String(node_type), stylebox)

	var save_err := _save_theme(theme, path)
	if save_err != null:
		return save_err
	return {"path": path}


static func merge_theme(params: Dictionary, _ei: EditorInterface) -> Variant:
	var target_path: String = params.get("target_path", "")
	var source_path: String = params.get("source_path", "")
	if target_path == "" or source_path == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "target_path and source_path are required"}

	var target := _load_theme(target_path)
	if target is Dictionary:
		return target
	var source := _load_theme(source_path)
	if source is Dictionary:
		return source

	target.merge_with(source)
	var save_err := _save_theme(target, target_path)
	if save_err != null:
		return save_err
	return {"target_path": target_path, "source_path": source_path}


static func assign_theme(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if not (node is Control or node is Window):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s cannot have a theme (expected a Control or Window)" % node.get_class()}

	var theme_path: String = params.get("theme_path", "")
	if theme_path == "" or not FileAccess.file_exists(theme_path):
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No theme at %s" % theme_path}
	var theme: Variant = _load_theme(theme_path)
	if theme is Dictionary:
		return theme
	node.theme = theme
	return {"node_path": params.get("node_path", ""), "theme_path": theme_path}
