## Handlers for the project_configuration tool category.
class_name GodotMCPProjectConfigurationHandlers
extends RefCounted


static func register(dispatch: Dictionary) -> void:
	dispatch["set_window_settings"] = set_window_settings
	dispatch["set_main_scene"] = set_main_scene
	dispatch["get_project_setting"] = get_project_setting
	dispatch["set_project_setting"] = set_project_setting
	dispatch["add_autoload"] = add_autoload
	dispatch["remove_autoload"] = remove_autoload


## Deliberately does NOT call ProjectSettings.set_initial_value(key, value) —
## that declares what a setting's *default* is, and setting it to the same
## value we just assigned makes Godot think the setting is unchanged from
## default, so save() silently skips writing it to project.godot at all.
static func _set_and_save(key: String, value: Variant) -> void:
	ProjectSettings.set_setting(key, value)
	ProjectSettings.save()


static func set_window_settings(params: Dictionary, _ei: EditorInterface) -> Dictionary:
	if params.has("width"):
		_set_and_save("display/window/size/viewport_width", int(params["width"]))
	if params.has("height"):
		_set_and_save("display/window/size/viewport_height", int(params["height"]))
	if params.has("resizable"):
		_set_and_save("display/window/size/resizable", bool(params["resizable"]))
	if params.has("mode"):
		_set_and_save("display/window/size/mode", int(params["mode"]))
	return {
		"width": ProjectSettings.get_setting("display/window/size/viewport_width", 0),
		"height": ProjectSettings.get_setting("display/window/size/viewport_height", 0),
	}


static func set_main_scene(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "" or not FileAccess.file_exists(path):
		return {"__error_code__": "SCENE_NOT_FOUND", "__error_message__": "No scene at %s" % path}
	_set_and_save("application/run/main_scene", path)
	return {"path": path}


static func get_project_setting(params: Dictionary, _ei: EditorInterface) -> Variant:
	var key: String = params.get("key", "")
	if not ProjectSettings.has_setting(key):
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No project setting '%s'" % key}
	return {"key": key, "value": ProjectSettings.get_setting(key)}


static func set_project_setting(params: Dictionary, _ei: EditorInterface) -> Variant:
	var key: String = params.get("key", "")
	if key == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "key is required"}
	_set_and_save(key, params.get("value"))
	return {"key": key, "value": ProjectSettings.get_setting(key)}


## Mirrors the project.godot [autoload] entry format EditorPlugin.add_autoload_singleton
## itself writes ("*res://path" = a Node-type autoload) — handlers only have
## EditorInterface, not the EditorPlugin instance that owns that method.
static func add_autoload(params: Dictionary, _ei: EditorInterface) -> Variant:
	var autoload_name: String = params.get("name", "")
	var path: String = params.get("path", "")
	if autoload_name == "" or path == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "name and path are required"}
	if not FileAccess.file_exists(path):
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No file at %s" % path}

	var key := "autoload/%s" % autoload_name
	if ProjectSettings.has_setting(key):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "Autoload '%s' already exists" % autoload_name}
	_set_and_save(key, "*%s" % path)
	return {"name": autoload_name, "path": path}


static func remove_autoload(params: Dictionary, _ei: EditorInterface) -> Variant:
	var autoload_name: String = params.get("name", "")
	var key := "autoload/%s" % autoload_name
	if not ProjectSettings.has_setting(key):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "No such autoload '%s'" % autoload_name}
	ProjectSettings.clear(key)
	ProjectSettings.save()
	return {"name": autoload_name}
