## Handlers for the plugin_management tool category.
##
## search_asset_library and install_addon are implemented Python-side
## (server/src/godot_mcp/tools/plugin_management.py) — they call Godot's
## public Asset Library REST API and write the downloaded addon's files
## directly via the OS filesystem, the same "own the OS-level work in Python
## instead of GDScript" pattern used by game_launch_process. rescan_filesystem
## below is the one small piece that still needs the editor: after
## install_addon writes new files under res://addons/, the editor's own file
## system cache needs to be told to notice them. It's intentionally NOT in
## protocol/tools_manifest.yaml — it's an internal step of install_addon's
## flow, not something meant to be called directly as its own AI-facing tool.
class_name GodotMCPPluginManagementHandlers
extends RefCounted


static func register(dispatch: Dictionary) -> void:
	dispatch["list_plugins"] = list_plugins
	dispatch["enable_plugin"] = enable_plugin
	dispatch["rescan_filesystem"] = rescan_filesystem


static func rescan_filesystem(_params: Dictionary, ei: EditorInterface) -> Dictionary:
	ei.get_resource_filesystem().scan()
	return {"scanned": true}


static func list_plugins(_params: Dictionary, _ei: EditorInterface) -> Dictionary:
	var plugins: Array = []
	var dir := DirAccess.open("res://addons")
	if dir == null:
		return {"plugins": plugins}

	var enabled_list: PackedStringArray = ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray())

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and entry != "." and entry != "..":
			var cfg_path := "res://addons/%s/plugin.cfg" % entry
			if FileAccess.file_exists(cfg_path):
				var cfg := ConfigFile.new()
				if cfg.load(cfg_path) == OK:
					plugins.append({
						"folder": entry,
						"name": cfg.get_value("plugin", "name", entry),
						"description": cfg.get_value("plugin", "description", ""),
						"version": cfg.get_value("plugin", "version", ""),
						"enabled": enabled_list.has(cfg_path),
					})
		entry = dir.get_next()
	dir.list_dir_end()

	return {"plugins": plugins}


static func enable_plugin(params: Dictionary, _ei: EditorInterface) -> Variant:
	var folder: String = params.get("plugin_folder", "")
	var cfg_path := "res://addons/%s/plugin.cfg" % folder
	if not FileAccess.file_exists(cfg_path):
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No plugin at addons/%s" % folder}

	var enabled: PackedStringArray = ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray())
	var list_array: Array = Array(enabled)
	var want_enabled: bool = bool(params.get("enabled", true))

	if want_enabled and not list_array.has(cfg_path):
		list_array.append(cfg_path)
	elif not want_enabled and list_array.has(cfg_path):
		list_array.erase(cfg_path)

	var new_list := PackedStringArray(list_array)
	# No set_initial_value() — see project_configuration.gd's _set_and_save for why.
	ProjectSettings.set_setting("editor_plugins/enabled", new_list)
	ProjectSettings.save()

	return {"plugin_folder": folder, "enabled": want_enabled}
