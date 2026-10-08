## Shared resource-dependency graph builder + cycle detection, used by the
## project_statistics category (find_unused_resources, detect_circular_dependencies).
class_name GodotMCPDependencyGraph
extends RefCounted

const FsWalk = preload("res://addons/godot_mcp_bridge/utils/fs_walk.gd")


## Maps every tracked project file to the list of resource paths it depends on
## (via ResourceLoader.get_dependencies). Excludes this addon's own files,
## project.godot, and Godot's .import/.uid sidecar files, none of which are
## meaningful nodes in a "what references what" graph.
static func build(root: String = "res://") -> Dictionary:
	var graph := {}
	for path in FsWalk.list_files(root):
		if path.begins_with("res://addons/godot_mcp_bridge/"):
			continue
		if path == "res://project.godot":
			continue
		var ext: String = path.get_extension()
		if ext == "import" or ext == "uid":
			continue
		# Non-resource files (.gitignore, .gitattributes, .editorconfig, ...)
		# aren't nodes in a "what references what" Godot resource graph at
		# all — including them just produces permanent, meaningless
		# "unused resource" noise since nothing could ever reference them
		# via ResourceLoader in the first place.
		if not ResourceLoader.exists(path):
			continue
		var deps: Array = []
		for dep in ResourceLoader.get_dependencies(path):
			deps.append(_clean_dependency_path(dep))
		graph[path] = deps
	return graph


## get_dependencies() returns a plain "res://..." path only for the rare
## dependency saved without a UID. Godot 4.4+ saves resource references by
## UID by default (every scene made through the normal editor UI does this),
## and for those the returned string is instead a compound
## "uid://<id>::<type_hint>::res://actual/path" — comparing that raw string
## against plain res:// paths elsewhere in the graph never matches, which
## silently broke "is this resource referenced" for virtually every
## real-world project. Pull the real res:// path back out of it.
static func _clean_dependency_path(raw: String) -> String:
	if raw.begins_with("res://"):
		return raw
	for part in raw.split("::"):
		if part.begins_with("res://"):
			return part
	return raw


## Depth-first search over `graph` (path -> Array[String] of dependency paths).
## Returns each cycle found as an ordered Array of paths, first == last.
static func find_cycles(graph: Dictionary) -> Array:
	var cycles: Array = []
	var visited := {}
	var on_stack := {}
	var path_stack: Array = []

	for start in graph.keys():
		if not visited.has(start):
			_visit(start, graph, visited, on_stack, path_stack, cycles)

	return cycles


static func _visit(node: String, graph: Dictionary, visited: Dictionary, on_stack: Dictionary, path_stack: Array, cycles: Array) -> void:
	visited[node] = true
	on_stack[node] = true
	path_stack.append(node)

	for dep in graph.get(node, []):
		if not graph.has(dep):
			continue  # dependency outside the tracked set (e.g. a builtin/engine resource)
		if on_stack.has(dep):
			var idx: int = path_stack.find(dep)
			cycles.append(path_stack.slice(idx) + [dep])
		elif not visited.has(dep):
			_visit(dep, graph, visited, on_stack, path_stack, cycles)

	on_stack.erase(node)
	path_stack.pop_back()
