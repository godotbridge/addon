## Handlers for the execution_testing tool category.
class_name GodotMCPExecutionTestingHandlers
extends RefCounted


static func register(dispatch: Dictionary) -> void:
	dispatch["play_project"] = play_project
	dispatch["play_scene"] = play_scene
	dispatch["stop_playing"] = stop_playing
	dispatch["is_playing"] = is_playing
	dispatch["run_gdscript_test"] = run_gdscript_test
	dispatch["get_export_status"] = get_export_status


static func play_project(_params: Dictionary, ei: EditorInterface) -> Dictionary:
	ei.play_main_scene()
	return {"playing": true}


static func play_scene(params: Dictionary, ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "":
		# EditorInterface.play_current_scene() depends on which scene tab the
		# editor UI considers "active", which is unreliable to rely on for
		# automation (headless or not) — derive the path from the actually
		# edited scene root instead and always go through play_custom_scene().
		var root := ei.get_edited_scene_root()
		if root == null or root.scene_file_path == "":
			return {
				"__error_code__": "SCENE_NOT_FOUND",
				"__error_message__": "No scene is currently open in the editor to play",
			}
		path = root.scene_file_path
	if not FileAccess.file_exists(path):
		return {"__error_code__": "SCENE_NOT_FOUND", "__error_message__": "No scene at %s" % path}
	ei.play_custom_scene(path)
	return {"playing": true}


static func stop_playing(_params: Dictionary, ei: EditorInterface) -> Dictionary:
	ei.stop_playing_scene()
	return {"playing": false}


static func is_playing(_params: Dictionary, ei: EditorInterface) -> Dictionary:
	return {"playing": ei.is_playing_scene()}


## GDScript has no exceptions/try-catch, so there's no way to intercept an
## `assert()` failure and keep running. Test functions (named test_*) signal
## failure by convention instead: return `false`, or a non-empty String to use
## as the failure message. Any other return value (including no return) counts
## as a pass. Runs in the editor process, not the running game.
static func run_gdscript_test(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	var source: String = params.get("content", "")
	if source == "":
		if path == "" or not FileAccess.file_exists(path):
			return {"__error_code__": "INVALID_PARAMS", "__error_message__": "Provide either path or content"}
		var file := FileAccess.open(path, FileAccess.READ)
		source = file.get_as_text()

	var script := GDScript.new()
	script.source_code = source
	var compile_err: Error = script.reload(false)
	if compile_err != OK:
		return {
			"__error_code__": "INVALID_PARAMS",
			"__error_message__": "Script failed to compile: %s" % error_string(compile_err),
		}

	var instance: Object = script.new()
	var results: Array = []
	var passed := 0
	var failed := 0

	for method in script.get_script_method_list():
		var name: String = method.get("name", "")
		if not name.begins_with("test_"):
			continue
		var outcome := {"name": name, "passed": true, "message": ""}
		var result: Variant = instance.call(name)
		if typeof(result) == TYPE_BOOL and result == false:
			outcome["passed"] = false
			outcome["message"] = "assertion failed"
		elif typeof(result) == TYPE_STRING and result != "":
			outcome["passed"] = false
			outcome["message"] = result
		results.append(outcome)
		if outcome["passed"]:
			passed += 1
		else:
			failed += 1

	return {"passed": passed, "failed": failed, "results": results}


static func get_export_status(_params: Dictionary, _ei: EditorInterface) -> Variant:
	# Export runs as a subprocess (see build_export.gd), so there's no live
	# status to query inside the editor. Return a basic check.
	return {"status": "idle", "message": "No export is currently in progress"}
