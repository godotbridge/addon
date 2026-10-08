## Handlers for the project_management tool category.
## Each function takes (params: Dictionary, editor_interface: EditorInterface)
## and returns the tool's `result` payload. Raise errors via `push_error` +
## returning {"__error_code__": ..., "__error_message__": ...}; bridge_server.gd
## translates that into a protocol error response.
class_name GodotMCPProjectManagementHandlers
extends RefCounted


static func register(dispatch: Dictionary) -> void:
	dispatch["get_project_info"] = get_project_info
	dispatch["get_project_settings"] = get_project_settings


static func get_project_info(_params: Dictionary, _ei: EditorInterface) -> Dictionary:
	var autoloads: Array = []
	for setting in ProjectSettings.get_property_list():
		var name: String = setting.get("name", "")
		if name.begins_with("autoload/"):
			autoloads.append(name.trim_prefix("autoload/"))

	return {
		"name": ProjectSettings.get_setting("application/config/name", ""),
		"godot_version": Engine.get_version_info().get("string", ""),
		"main_scene": ProjectSettings.get_setting("application/run/main_scene", ""),
		"autoloads": autoloads,
		"features": ProjectSettings.get_setting("application/config/features", []),
		# Lets the Python server launch the game itself as a subprocess (see
		# game_launch_process) instead of going through EditorInterface's Play
		# action, whose stdout/stderr never reaches GDScript.
		"godot_executable": OS.get_executable_path(),
		"project_path": ProjectSettings.globalize_path("res://"),
		# A game played via EditorInterface.play_custom_scene() (the normal
		# editor Play action) also writes here — confirmed empirically, this is
		# what makes get_debugger_errors possible. The editor's own operations
		# (addon code, run_editor_script, import errors) do NOT write here —
		# confirmed empirically too — so this can't answer get_editor_errors.
		"editor_log_path": ProjectSettings.globalize_path(
			ProjectSettings.get_setting("debug/file_logging/log_path", "user://logs/godot.log")
		),
	}


static func get_project_settings(_params: Dictionary, _ei: EditorInterface) -> Dictionary:
	var settings := {}
	for prop in ProjectSettings.get_property_list():
		var name: String = prop.get("name", "")
		if name == "":
			continue
		settings[name] = ProjectSettings.get_setting(name)
	return {"settings": settings}
