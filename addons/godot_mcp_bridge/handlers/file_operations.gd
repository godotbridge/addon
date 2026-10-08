## Handlers for the file_operations tool category.
class_name GodotMCPFileOperationsHandlers
extends RefCounted

const FsWalk = preload("res://addons/godot_mcp_bridge/utils/fs_walk.gd")


static func register(dispatch: Dictionary) -> void:
	dispatch["list_project_files"] = list_project_files
	dispatch["read_file"] = read_file
	dispatch["write_file"] = write_file
	dispatch["copy_file"] = copy_file
	dispatch["delete_file"] = delete_file
	dispatch["move_file"] = move_file
	dispatch["find_files"] = find_files
	dispatch["search_in_files"] = search_in_files
	dispatch["create_directory"] = create_directory


static func list_project_files(params: Dictionary, _ei: EditorInterface) -> Dictionary:
	var start_path: String = params.get("path", "res://")
	return {"files": FsWalk.list_files(start_path)}


static func read_file(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "" or not FileAccess.file_exists(path):
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No file at %s" % path}
	var file := FileAccess.open(path, FileAccess.READ)
	var content := file.get_as_text()
	return {"content": content}


static func write_file(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	var content: String = params.get("content", "")
	if path == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "path is required"}
	# FileAccess.open() fails silently (returns null) if the parent directory
	# doesn't exist yet — it never auto-creates it, unlike most file-write
	# APIs. Create it first so writing into a brand-new subdirectory works.
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Could not open %s for writing" % path}
	file.store_string(content)
	file.close()
	return {"bytes_written": content.to_utf8_buffer().size()}


static func copy_file(params: Dictionary, ei: EditorInterface) -> Variant:
	var source: String = params.get("source", "")
	var destination: String = params.get("destination", "")
	if source == "" or destination == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "source and destination are required"}
	if not FileAccess.file_exists(source):
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No file at %s" % source}
	var src := FileAccess.open(source, FileAccess.READ)
	var data := src.get_buffer(src.get_length())
	src.close()
	var dst := FileAccess.open(destination, FileAccess.WRITE)
	if dst == null:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Could not open %s for writing" % destination}
	dst.store_buffer(data)
	dst.close()
	ei.get_resource_filesystem().scan()
	return {"bytes_copied": data.size()}


static func delete_file(params: Dictionary, ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "path is required"}
	if not FileAccess.file_exists(path):
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No file at %s" % path}
	var err := DirAccess.remove_absolute(path)
	if err != OK:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Failed to delete %s: %s" % [path, error_string(err)]}
	ei.get_resource_filesystem().scan()
	return {"deleted": true}


static func move_file(params: Dictionary, ei: EditorInterface) -> Variant:
	var source: String = params.get("source", "")
	var destination: String = params.get("destination", "")
	if source == "" or destination == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "source and destination are required"}
	if not FileAccess.file_exists(source):
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No file at %s" % source}
	var err := DirAccess.rename_absolute(source, destination)
	if err != OK:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Failed to move %s: %s" % [source, error_string(err)]}
	ei.get_resource_filesystem().scan()
	return {"moved": true}


static func find_files(params: Dictionary, _ei: EditorInterface) -> Dictionary:
	var pattern: String = params.get("pattern", "*")
	var start_path: String = params.get("path", "res://")
	var all_files: Array = FsWalk.list_files(start_path)
	var matched: Array = []
	for f in all_files:
		if f.match(pattern) or f.get_file().match(pattern):
			matched.append(f)
	return {"files": matched}


static func search_in_files(params: Dictionary, _ei: EditorInterface) -> Dictionary:
	var query: String = params.get("query", "")
	var file_pattern: String = params.get("file_pattern", "")
	var start_path: String = params.get("path", "res://")
	if query == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "query is required"}
	var all_files: Array = FsWalk.list_files(start_path)
	var matches: Array = []
	var regex := RegEx.new()
	var use_regex := regex.compile(query) == OK
	for f in all_files:
		if file_pattern != "" and not f.get_file().match(file_pattern):
			continue
		if not FileAccess.file_exists(f):
			continue
		var file := FileAccess.open(f, FileAccess.READ)
		if file == null:
			continue
		var line_num := 0
		while not file.eof_reached():
			line_num += 1
			var line := file.get_line()
			var found := false
			if use_regex:
				found = regex.search(line) != null
			else:
				found = line.contains(query)
			if found:
				matches.append({"file": f, "line": line_num, "text": line.strip_edges()})
		file.close()
	return {"matches": matches}


static func create_directory(params: Dictionary, ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "path is required"}
	var err := DirAccess.make_dir_recursive_absolute(path)
	if err != OK:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Failed to create %s: %s" % [path, error_string(err)]}
	ei.get_resource_filesystem().scan()
	return {"created": true}
