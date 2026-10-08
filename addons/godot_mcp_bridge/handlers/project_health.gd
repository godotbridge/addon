## Handlers for the project_health tool category.
##
## NOT implemented: get_editor_errors, get_debugger_errors. Same wall as
## runtime_monitoring's game_get_errors/game_get_output — there is no public
## API to read the editor's (or a past debug run's) console/error log history
## from within a script. Documented here rather than faked.
class_name GodotMCPProjectHealthHandlers
extends RefCounted

const FsWalk = preload("res://addons/godot_mcp_bridge/utils/fs_walk.gd")
const DependencyGraph = preload("res://addons/godot_mcp_bridge/utils/dependency_graph.gd")
const ProjectStatisticsHandlers = preload("res://addons/godot_mcp_bridge/handlers/project_statistics.gd")


static func register(dispatch: Dictionary) -> void:
	dispatch["check_all_scripts"] = check_all_scripts
	dispatch["get_node_warnings"] = get_node_warnings
	dispatch["project_health_report"] = project_health_report


static func check_all_scripts(_params: Dictionary, _ei: EditorInterface) -> Dictionary:
	var results: Array = []
	var passed := 0
	var failed := 0
	for path in FsWalk.list_files("res://", PackedStringArray(["gd"])):
		if path.begins_with("res://addons/godot_mcp_bridge/"):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var script := GDScript.new()
		script.source_code = file.get_as_text()
		var err: Error = script.reload(false)
		var ok: bool = err == OK
		results.append({"path": path, "valid": ok, "error_code": error_string(err) if not ok else ""})
		if ok:
			passed += 1
		else:
			failed += 1
	return {"passed": passed, "failed": failed, "results": results}


## _get_configuration_warnings() is a GDVirtual extension point. Two things
## have to both be true for it to be safely callable in the editor process:
##   1. The node needs an attached *tool* script that overrides it — a
##      regular (non-@tool) script attached in the editor is only a
##      "placeholder instance" (real methods aren't callable until the scene
##      actually runs), and calling through one raises a script error instead
##      of returning normally.
##   2. Built-in engine nodes implement their warnings in C++ (e.g.
##      CollisionShape2D's "no shape assigned"), which isn't reachable
##      through GDScript reflection on a native instance at all.
## node.has_method(...) is NOT a reliable guard here — it reports true even
## for placeholder instances that then fail on .call(). Check the *script's*
## own declared methods instead, which is accurate.
static func _collect_warnings(node: Node, root: Node, out: Array) -> void:
	if _script_overrides_warnings(node):
		var warnings: PackedStringArray = node.call("_get_configuration_warnings")
		if not warnings.is_empty():
			out.append({
				"node_path": "." if node == root else str(root.get_path_to(node)),
				"type": node.get_class(),
				"warnings": Array(warnings),
			})
	for child in node.get_children():
		_collect_warnings(child, root, out)


static func _script_overrides_warnings(node: Node) -> bool:
	var script: Script = node.get_script()
	if script == null or not script.is_tool():
		return false
	for method in script.get_script_method_list():
		if method.get("name", "") == "_get_configuration_warnings":
			return true
	return false


static func get_node_warnings(params: Dictionary, ei: EditorInterface) -> Variant:
	var root: Node = ei.get_edited_scene_root()
	if root == null:
		return {"__error_code__": "SCENE_NOT_FOUND", "__error_message__": "No scene is currently open in the editor"}

	var node_path: String = params.get("node_path", "")
	var scope: Node = root
	if node_path != "" and node_path != ".":
		scope = root.get_node_or_null(NodePath(node_path))
		if scope == null:
			return {"__error_code__": "NODE_NOT_FOUND", "__error_message__": "No node at path %s" % node_path}

	var out: Array = []
	_collect_warnings(scope, root, out)
	return {"nodes": out}


## Composite audit combining project_statistics' checks with script
## validation and (if a scene is open) node configuration warnings — one call
## for a full-project sanity pass instead of chaining several tools by hand.
static func project_health_report(params: Dictionary, ei: EditorInterface) -> Dictionary:
	var stats: Dictionary = ProjectStatisticsHandlers.get_project_statistics(params, ei)
	var unused: Dictionary = ProjectStatisticsHandlers.find_unused_resources(params, ei)
	var cycles: Dictionary = ProjectStatisticsHandlers.detect_circular_dependencies(params, ei)
	var scripts: Dictionary = check_all_scripts(params, ei)

	var warnings_result: Variant = get_node_warnings({}, ei)
	var node_warnings: Array = warnings_result.get("nodes", []) if warnings_result is Dictionary and not warnings_result.has("__error_code__") else []

	return {
		"statistics": stats,
		"unused_resource_count": unused.get("unused_resources", []).size(),
		"circular_dependency_count": cycles.get("cycles", []).size(),
		"scripts": {"passed": scripts["passed"], "failed": scripts["failed"]},
		"nodes_with_warnings": node_warnings.size(),
	}
