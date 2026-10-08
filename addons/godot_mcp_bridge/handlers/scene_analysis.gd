## Handlers for the scene_analysis tool category.
class_name GodotMCPSceneAnalysisHandlers
extends RefCounted

const FsWalk = preload("res://addons/godot_mcp_bridge/utils/fs_walk.gd")


static func register(dispatch: Dictionary) -> void:
	dispatch["list_scenes"] = list_scenes
	dispatch["get_scene_dependencies"] = get_scene_dependencies
	dispatch["list_scripts"] = list_scripts


static func list_scenes(_params: Dictionary, _ei: EditorInterface) -> Dictionary:
	var scenes: Array = []
	for path in FsWalk.list_files("res://", PackedStringArray(["tscn"])):
		var entry := {"path": path, "root_name": "", "root_type": ""}
		var packed: PackedScene = load(path)
		if packed != null:
			var state := packed.get_state()
			if state.get_node_count() > 0:
				entry["root_name"] = str(state.get_node_name(0))
				entry["root_type"] = str(state.get_node_type(0))
		scenes.append(entry)
	return {"scenes": scenes}


static func get_scene_dependencies(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "" or not FileAccess.file_exists(path):
		return {"__error_code__": "SCENE_NOT_FOUND", "__error_message__": "No scene at %s" % path}
	return {"dependencies": Array(ResourceLoader.get_dependencies(path))}


static func list_scripts(_params: Dictionary, _ei: EditorInterface) -> Dictionary:
	var scripts: Array = []
	for path in FsWalk.list_files("res://", PackedStringArray(["gd", "cs"])):
		var entry := {"path": path, "extends": "", "class_name": ""}
		if path.ends_with(".gd"):
			var script: Script = load(path)
			if script != null:
				entry["extends"] = script.get_instance_base_type()
				entry["class_name"] = str(script.get_global_name())
		scripts.append(entry)
	return {"scripts": scripts}
