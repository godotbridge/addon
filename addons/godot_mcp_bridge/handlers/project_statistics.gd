## Handlers for the project_statistics tool category.
class_name GodotMCPProjectStatisticsHandlers
extends RefCounted

const FsWalk = preload("res://addons/godot_mcp_bridge/utils/fs_walk.gd")
const DependencyGraph = preload("res://addons/godot_mcp_bridge/utils/dependency_graph.gd")


static func register(dispatch: Dictionary) -> void:
	dispatch["get_project_statistics"] = get_project_statistics
	dispatch["find_unused_resources"] = find_unused_resources
	dispatch["detect_circular_dependencies"] = detect_circular_dependencies


static func get_project_statistics(_params: Dictionary, _ei: EditorInterface) -> Dictionary:
	var files_by_extension := {}
	var script_line_total := 0
	var total_files := 0

	for path in FsWalk.list_files("res://"):
		total_files += 1
		var ext: String = path.get_extension()
		if ext == "":
			ext = "(none)"
		files_by_extension[ext] = files_by_extension.get(ext, 0) + 1

		if ext == "gd" or ext == "cs":
			var file := FileAccess.open(path, FileAccess.READ)
			if file != null:
				script_line_total += file.get_as_text().split("\n").size()

	return {
		"total_files": total_files,
		"files_by_extension": files_by_extension,
		"script_line_total": script_line_total,
	}


## Heuristic: a file is "unused" if no other tracked file's dependency list
## points at it and it isn't an entry point (main scene or an autoload).
## Cannot see references from code that doesn't go through ResourceLoader
## (e.g. a dynamically built res:// path string), so treat results as leads
## to review, not a guaranteed-safe deletion list.
static func find_unused_resources(_params: Dictionary, _ei: EditorInterface) -> Dictionary:
	var graph := DependencyGraph.build()

	var referenced := {}
	for deps in graph.values():
		for dep in deps:
			referenced[dep] = true

	var entry_points := {}
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene", "")
	if main_scene != "":
		entry_points[main_scene] = true
	for prop in ProjectSettings.get_property_list():
		var name: String = prop.get("name", "")
		if name.begins_with("autoload/"):
			var raw := str(ProjectSettings.get_setting(name))
			entry_points[raw.trim_prefix("*")] = true

	# Single-resource-path project settings — referenced only from
	# project.godot itself, never from another tracked resource's own
	# dependency list, so the dependency graph alone would never mark these
	# as "referenced" without checking for them explicitly here.
	var single_resource_settings := [
		"application/config/icon",
		"application/config/macos_native_icon",
		"application/config/windows_native_icon",
		"application/boot_splash/image",
	]
	for setting in single_resource_settings:
		var value: String = str(ProjectSettings.get_setting(setting, ""))
		if value != "":
			entry_points[value] = true

	var unused: Array = []
	for path in graph.keys():
		if referenced.has(path) or entry_points.has(path):
			continue
		unused.append(path)

	return {"unused_resources": unused}


static func detect_circular_dependencies(_params: Dictionary, _ei: EditorInterface) -> Dictionary:
	var graph := DependencyGraph.build()
	return {"cycles": DependencyGraph.find_cycles(graph)}
