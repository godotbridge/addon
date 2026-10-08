## Handlers for the game_templates tool category.
class_name GodotMCPGameTemplatesHandlers
extends RefCounted


static func register(dispatch: Dictionary) -> void:
	dispatch["create_main_menu"] = create_main_menu
	dispatch["create_pause_menu"] = create_pause_menu
	dispatch["create_settings_menu"] = create_settings_menu
	dispatch["create_save_system"] = create_save_system
	dispatch["play_multiplayer"] = play_multiplayer


static func _build_child(parent: Node, node_type: String, node_name: String, root: Node) -> Node:
	var node: Node = ClassDB.instantiate(node_type)
	node.name = node_name
	parent.add_child(node)
	node.owner = root
	return node


static func _save_new_scene(root: Node, path: String) -> Error:
	var packed := PackedScene.new()
	var pack_err: Error = packed.pack(root)
	if pack_err != OK:
		return pack_err
	# ResourceSaver.save() never auto-creates missing parent directories
	# (unlike most file-write APIs) — callers pass paths like res://scenes/x
	# that don't exist yet, so create it first or save fails with "Can't open".
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	return ResourceSaver.save(packed, path)


static func create_main_menu(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "path is required"}
	if FileAccess.file_exists(path):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "A scene already exists at %s" % path}

	var root := Control.new()
	root.name = "MainMenu"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)

	var vbox := _build_child(root, "VBoxContainer", "VBoxContainer", root)
	vbox.set_anchors_preset(Control.PRESET_CENTER)

	var title := _build_child(vbox, "Label", "Title", root)
	title.text = String(params.get("title", "My Game"))

	_build_child(vbox, "Button", "PlayButton", root).text = "Play"
	_build_child(vbox, "Button", "QuitButton", root).text = "Quit"

	var err := _save_new_scene(root, path)
	root.free()
	if err != OK:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Could not save scene: %s" % error_string(err)}
	return {"path": path}


static func create_pause_menu(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "path is required"}
	if FileAccess.file_exists(path):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "A scene already exists at %s" % path}

	var root := CanvasLayer.new()
	root.name = "PauseMenu"

	var panel := _build_child(root, "Control", "Panel", root)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.process_mode = Node.PROCESS_MODE_ALWAYS

	var vbox := _build_child(panel, "VBoxContainer", "VBoxContainer", root)
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.process_mode = Node.PROCESS_MODE_ALWAYS

	_build_child(vbox, "Button", "ResumeButton", root).text = "Resume"
	_build_child(vbox, "Button", "QuitButton", root).text = "Quit to Menu"

	var err := _save_new_scene(root, path)
	root.free()
	if err != OK:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Could not save scene: %s" % error_string(err)}
	return {"path": path}


static func create_settings_menu(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "path is required"}
	if FileAccess.file_exists(path):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "A scene already exists at %s" % path}

	var root := Control.new()
	root.name = "SettingsMenu"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)

	var vbox := _build_child(root, "VBoxContainer", "VBoxContainer", root)
	vbox.set_anchors_preset(Control.PRESET_CENTER)

	_build_child(vbox, "Label", "VolumeLabel", root).text = "Volume"
	var slider := _build_child(vbox, "HSlider", "VolumeSlider", root)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.value = 1.0

	_build_child(vbox, "CheckBox", "FullscreenCheckBox", root).text = "Fullscreen"
	_build_child(vbox, "Button", "BackButton", root).text = "Back"

	var err := _save_new_scene(root, path)
	root.free()
	if err != OK:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Could not save scene: %s" % error_string(err)}
	return {"path": path}


static func create_save_system(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "res://save_system.gd")
	if FileAccess.file_exists(path):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "A script already exists at %s" % path}

	var save_path: String = params.get("save_path", "user://savegame.save")
	var code := "extends Node\n\nconst SAVE_PATH := \"%s\"\n\n\nfunc save_game(data: Dictionary) -> void:\n\tvar file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)\n\tfile.store_string(JSON.stringify(data))\n\tfile.close()\n\n\nfunc load_game() -> Dictionary:\n\tif not FileAccess.file_exists(SAVE_PATH):\n\t\treturn {}\n\tvar file := FileAccess.open(SAVE_PATH, FileAccess.READ)\n\tvar parsed = JSON.parse_string(file.get_as_text())\n\tfile.close()\n\treturn parsed if typeof(parsed) == TYPE_DICTIONARY else {}\n\n\nfunc has_save() -> bool:\n\treturn FileAccess.file_exists(SAVE_PATH)\n\n\nfunc delete_save() -> void:\n\tif has_save():\n\t\tDirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))\n" % save_path

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Could not open %s for writing" % path}
	file.store_string(code)
	file.close()

	var registered_autoload := false
	if bool(params.get("register_autoload", true)):
		var key := "autoload/SaveSystem"
		if not ProjectSettings.has_setting(key):
			ProjectSettings.set_setting(key, "*%s" % path)
			ProjectSettings.save()
			registered_autoload = true

	return {"path": path, "save_path": save_path, "registered_autoload": registered_autoload}


## Spawns `instance_count` additional Godot processes running this same
## project — the standard way to test local multiplayer without a second
## machine. Each is a real separate OS process (OS.create_process is
## non-blocking); the caller is responsible for closing them.
static func play_multiplayer(params: Dictionary, _ei: EditorInterface) -> Variant:
	var instance_count: int = int(params.get("instance_count", 2))
	if instance_count < 1:
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "instance_count must be at least 1"}

	var project_path := ProjectSettings.globalize_path("res://")
	var args := ["--path", project_path]
	if params.has("scene_path"):
		args.append(String(params["scene_path"]))

	var pids: Array = []
	for i in range(instance_count):
		var pid := OS.create_process(OS.get_executable_path(), args)
		if pid <= 0:
			return {
				"__error_code__": "INTERNAL_ERROR",
				"__error_message__": "Failed to launch instance %d (of %d already launched: %s)" % [i, pids.size(), pids],
			}
		pids.append(pid)

	return {"instance_count": instance_count, "pids": pids}
