## Handlers for the script_management tool category.
class_name GodotMCPScriptManagementHandlers
extends RefCounted


static func register(dispatch: Dictionary) -> void:
	dispatch["read_script"] = read_script
	dispatch["create_script"] = create_script
	dispatch["edit_script"] = edit_script
	dispatch["validate_script"] = validate_script
	dispatch["attach_script"] = attach_script
	dispatch["add_state_machine_script"] = add_state_machine_script


static func read_script(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "" or not FileAccess.file_exists(path):
		return {"__error_code__": "SCRIPT_NOT_FOUND", "__error_message__": "No script at %s" % path}
	var file := FileAccess.open(path, FileAccess.READ)
	return {"content": file.get_as_text()}


static func create_script(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "path is required"}
	if FileAccess.file_exists(path):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "A script already exists at %s" % path}

	var base_type: String = params.get("base_type", "Node")
	var content: String = params.get("content", "extends %s\n" % base_type)

	# See write_file's identical fix — FileAccess.open() never auto-creates
	# a missing parent directory.
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Could not open %s for writing" % path}
	file.store_string(content)
	file.close()
	return {"path": path}


static func edit_script(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	var content: String = params.get("content", "")
	if path == "" or not FileAccess.file_exists(path):
		return {"__error_code__": "SCRIPT_NOT_FOUND", "__error_message__": "No script at %s" % path}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Could not open %s for writing" % path}
	file.store_string(content)
	file.close()
	return {"bytes_written": content.to_utf8_buffer().size()}


## Compile-checks GDScript source without running it. Only reports whether the
## parse/compile step succeeded and, if not, the engine's Error code — GDScript
## has no public API to retrieve full diagnostic text (line/column) outside the
## editor's own script editor, only what it prints to the console.
static func validate_script(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	var source: String = params.get("content", "")
	if source == "":
		if path == "" or not FileAccess.file_exists(path):
			return {"__error_code__": "INVALID_PARAMS", "__error_message__": "Provide either path or content"}
		var file := FileAccess.open(path, FileAccess.READ)
		source = file.get_as_text()

	var script := GDScript.new()
	script.source_code = source
	var err: int = script.reload(false)

	return {"valid": err == OK, "error_code": error_string(err)}


static func attach_script(params: Dictionary, ei: EditorInterface) -> Variant:
	var node_path: String = params.get("node_path", "")
	var script_path: String = params.get("script_path", "")
	if node_path == "" or script_path == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "node_path and script_path are required"}

	var root := ei.get_edited_scene_root()
	if root == null:
		return {"__error_code__": "SCENE_NOT_FOUND", "__error_message__": "No scene is currently open in the editor"}

	var node := root.get_node_or_null(NodePath(node_path))
	if node == null:
		return {"__error_code__": "NODE_NOT_FOUND", "__error_message__": "No node at path %s" % node_path}

	if not FileAccess.file_exists(script_path):
		return {"__error_code__": "SCRIPT_NOT_FOUND", "__error_message__": "No script at %s" % script_path}

	# load() succeeding with the wrong resource type (e.g. a .tscn path)
	# would otherwise crash the whole dispatch on the assignment below —
	# "Trying to assign value of type 'PackedScene' to a variable of type
	# 'Script'" is a hard GDScript type error, not a catchable one.
	var loaded: Variant = load(script_path)
	if not (loaded is Script):
		return {
			"__error_code__": "INVALID_PARAMS",
			"__error_message__": "%s is not a script (loaded as %s)" % [script_path, loaded.get_class() if loaded != null else "null"],
		}
	node.set_script(loaded)
	return {"node_path": node_path, "script_path": script_path}


static func add_state_machine_script(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "path is required"}
	if FileAccess.file_exists(path):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "A script already exists at %s" % path}

	var states: Array = params.get("states", ["Idle"])
	var base_type: String = params.get("base_type", "Node")
	var content := _state_machine_template(base_type, states)

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Could not open %s for writing" % path}
	file.store_string(content)
	file.close()
	return {"path": path, "states": states}


static func _state_machine_template(base_type: String, states: Array) -> String:
	var lines: Array = ["extends %s" % base_type, "", "enum State {"]
	for state in states:
		lines.append("\t%s," % String(state).to_upper())
	lines.append("}")
	lines.append("")
	lines.append("var current_state: State = State.%s" % String(states[0]).to_upper())
	lines.append("")
	lines.append("func transition_to(new_state: State) -> void:")
	lines.append("\tcurrent_state = new_state")
	lines.append("")
	return "\n".join(lines)
