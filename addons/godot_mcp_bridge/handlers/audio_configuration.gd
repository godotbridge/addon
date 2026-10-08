## Handlers for the audio_configuration tool category.
class_name GodotMCPAudioConfigurationHandlers
extends RefCounted

const NodeResolver = preload("res://addons/godot_mcp_bridge/utils/node_resolver.gd")


static func register(dispatch: Dictionary) -> void:
	dispatch["add_bus_effect"] = add_bus_effect
	dispatch["create_audio_randomizer"] = create_audio_randomizer
	dispatch["add_audio_player"] = add_audio_player
	dispatch["get_audio_info"] = get_audio_info
	dispatch["get_audio_buses"] = get_audio_buses
	dispatch["add_audio_bus"] = add_audio_bus
	dispatch["set_audio_bus"] = set_audio_bus
	dispatch["save_bus_layout"] = save_bus_layout


static func _find_bus(bus_name: String) -> int:
	return AudioServer.get_bus_index(bus_name)


static func add_bus_effect(params: Dictionary, _ei: EditorInterface) -> Variant:
	var bus_name: String = params.get("bus_name", "")
	var bus_idx := _find_bus(bus_name)
	if bus_idx < 0:
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "No audio bus named %s" % bus_name}

	var effect_type: String = params.get("effect_type", "")
	var effect: AudioEffect = ClassDB.instantiate(effect_type)
	if effect == null:
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "Unknown effect class %s" % effect_type}

	var properties: Dictionary = params.get("properties", {})
	for property in properties.keys():
		effect.set(property, properties[property])

	AudioServer.add_bus_effect(bus_idx, effect)
	return {"bus_name": bus_name, "effect_type": effect_type, "effect_index": AudioServer.get_bus_effect_count(bus_idx) - 1}


static func create_audio_randomizer(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "path is required"}
	if FileAccess.file_exists(path):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "A resource already exists at %s" % path}

	var randomizer := AudioStreamRandomizer.new()
	var stream_paths: Array = params.get("stream_paths", [])
	for i in range(stream_paths.size()):
		var stream: Variant = load(String(stream_paths[i]))
		if stream is AudioStream:
			randomizer.add_stream(i, stream)

	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err: Error = ResourceSaver.save(randomizer, path)
	if err != OK:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Could not save resource: %s" % error_string(err)}
	return {"path": path, "stream_count": randomizer.streams_count}


static func add_audio_player(params: Dictionary, ei: EditorInterface) -> Variant:
	var dimension: String = params.get("dimension", "")
	var node_type := "AudioStreamPlayer"
	if dimension == "2d":
		node_type = "AudioStreamPlayer2D"
	elif dimension == "3d":
		node_type = "AudioStreamPlayer3D"

	var parent := NodeResolver.resolve(params, ei, "parent_path")
	if parent is Dictionary:
		return parent
	var root: Node = ei.get_edited_scene_root()
	var node := NodeResolver.add_child_node(parent, root, node_type, params.get("node_name", ""))
	if node is Dictionary:
		return node

	var stream_path: String = params.get("stream_path", "")
	if stream_path != "":
		var stream: Variant = load(stream_path)
		if not (stream is AudioStream):
			return {
				"__error_code__": "RESOURCE_NOT_FOUND",
				"__error_message__": "%s is not an AudioStream resource (loaded as %s)" % [stream_path, stream.get_class() if stream != null else "null"],
			}
		node.stream = stream
	if params.has("bus"):
		node.bus = String(params["bus"])

	return {"node_path": NodeResolver.relative_path(root, node), "type": node_type}


static func get_audio_info(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if not (node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s is not an audio player node" % node.get_class()}
	return {
		"type": node.get_class(),
		"bus": node.bus,
		"volume_db": node.volume_db,
		"playing": node.playing,
		"stream_path": node.stream.resource_path if node.stream != null else "",
	}


static func get_audio_buses(_params: Dictionary, _ei: EditorInterface) -> Dictionary:
	var buses: Array = []
	for i in range(AudioServer.bus_count):
		buses.append({
			"index": i,
			"name": AudioServer.get_bus_name(i),
			"volume_db": AudioServer.get_bus_volume_db(i),
			"mute": AudioServer.is_bus_mute(i),
			"solo": AudioServer.is_bus_solo(i),
			"effect_count": AudioServer.get_bus_effect_count(i),
		})
	return {"buses": buses}


static func add_audio_bus(params: Dictionary, _ei: EditorInterface) -> Variant:
	var bus_name: String = params.get("bus_name", "")
	if bus_name == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "bus_name is required"}
	if _find_bus(bus_name) >= 0:
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "Bus %s already exists" % bus_name}

	var at_position: int = int(params.get("at_position", AudioServer.bus_count))
	AudioServer.add_bus(at_position)
	AudioServer.set_bus_name(at_position, bus_name)
	return {"bus_name": bus_name, "index": at_position}


static func set_audio_bus(params: Dictionary, _ei: EditorInterface) -> Variant:
	var bus_name: String = params.get("bus_name", "")
	var bus_idx := _find_bus(bus_name)
	if bus_idx < 0:
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "No audio bus named %s" % bus_name}

	if params.has("volume_db"):
		AudioServer.set_bus_volume_db(bus_idx, float(params["volume_db"]))
	if params.has("mute"):
		AudioServer.set_bus_mute(bus_idx, bool(params["mute"]))
	if params.has("solo"):
		AudioServer.set_bus_solo(bus_idx, bool(params["solo"]))
	if params.has("send"):
		AudioServer.set_bus_send(bus_idx, String(params["send"]))

	return {
		"bus_name": bus_name,
		"volume_db": AudioServer.get_bus_volume_db(bus_idx),
		"mute": AudioServer.is_bus_mute(bus_idx),
		"solo": AudioServer.is_bus_solo(bus_idx),
	}


static func save_bus_layout(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "res://default_bus_layout.tres")
	# ResourceSaver.save() never auto-creates a missing parent directory —
	# same gotcha as write_file/create_script.
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var layout := AudioServer.generate_bus_layout()
	var err: Error = ResourceSaver.save(layout, path)
	if err != OK:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Could not save bus layout: %s" % error_string(err)}
	return {"path": path}
