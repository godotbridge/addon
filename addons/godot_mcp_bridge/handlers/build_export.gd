## Handlers for the build_export tool category.
##
## `EditorExport`/`EditorExportPlatform` are not exposed to GDScript scripting
## (they exist in the editor's C++ internals but aren't scriptable classes),
## so this reads presets directly from res://export_presets.cfg (the actual
## file format Godot stores them in) instead of a live API. export_project
## triggers a real export the same way the documented CI workflow does:
## spawning Godot's own executable again with --headless --export-release/
## --export-debug — there's no in-process "just export it" scripting call.
class_name GodotMCPBuildExportHandlers
extends RefCounted

const PRESETS_PATH := "res://export_presets.cfg"


static func register(dispatch: Dictionary) -> void:
	dispatch["list_export_presets"] = list_export_presets
	dispatch["export_project"] = export_project


static func list_export_presets(_params: Dictionary, _ei: EditorInterface) -> Dictionary:
	var presets: Array = []
	if not FileAccess.file_exists(PRESETS_PATH):
		return {"presets": presets}

	var cfg := ConfigFile.new()
	if cfg.load(PRESETS_PATH) != OK:
		return {"presets": presets}

	var i := 0
	while cfg.has_section("preset.%d" % i):
		var section := "preset.%d" % i
		presets.append({
			"index": i,
			"name": cfg.get_value(section, "name", ""),
			"platform": cfg.get_value(section, "platform", ""),
			"export_path": cfg.get_value(section, "export_path", ""),
			"runnable": cfg.get_value(section, "runnable", false),
		})
		i += 1
	return {"presets": presets}


static func export_project(params: Dictionary, _ei: EditorInterface) -> Variant:
	var preset_name: String = params.get("preset_name", "")
	var output_path: String = params.get("output_path", "")
	if preset_name == "" or output_path == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "preset_name and output_path are required"}

	var found := false
	for preset in list_export_presets({}, null).get("presets", []):
		if preset["name"] == preset_name:
			found = true
			break
	if not found:
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No export preset named '%s'" % preset_name}

	var debug: bool = bool(params.get("debug", true))
	var flag := "--export-debug" if debug else "--export-release"
	# Godot's export CLI doesn't create the output directory itself — same
	# "never auto-creates a missing parent directory" gotcha as write_file
	# etc. (confirmed empirically: "The given export path doesn't exist").
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var project_path := ProjectSettings.globalize_path("res://")
	var output = []
	var exit_code := OS.execute(
		OS.get_executable_path(),
		["--headless", "--path", project_path, flag, preset_name, output_path],
		output,
		true
	)

	if exit_code != 0:
		return {
			"__error_code__": "INTERNAL_ERROR",
			"__error_message__": "Export failed (exit %d): %s" % [exit_code, "\n".join(output)],
		}
	return {"preset_name": preset_name, "output_path": output_path, "debug": debug}
