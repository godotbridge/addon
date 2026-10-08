## Handlers for the input_setup tool category. Input actions are persisted to
## ProjectSettings (under "input/<name>", the same keys the editor's own Input
## Map UI writes) so they survive a restart, not just InputMap's in-memory copy.
class_name GodotMCPInputSetupHandlers
extends RefCounted


static func register(dispatch: Dictionary) -> void:
	dispatch["get_input_actions"] = get_input_actions
	dispatch["add_input_action"] = add_input_action
	dispatch["remove_input_action"] = remove_input_action
	dispatch["add_key_to_action"] = add_key_to_action
	dispatch["add_input_event_to_action"] = add_input_event_to_action


static func get_input_actions(_params: Dictionary, _ei: EditorInterface) -> Dictionary:
	var actions: Array = []
	for action in InputMap.get_actions():
		var action_str: String = str(action)
		var events: Array = []
		for event in InputMap.action_get_events(action_str):
			events.append(_describe_input_event(event))
		actions.append({
			"name": action_str,
			"deadzone": InputMap.action_get_deadzone(action_str),
			"events": events,
		})
	return {"actions": actions}


static func add_input_action(params: Dictionary, _ei: EditorInterface) -> Variant:
	var action_name: String = params.get("action_name", "")
	if action_name == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "action_name is required"}
	var key := "input/%s" % action_name
	if ProjectSettings.has_setting(key):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "Action %s already exists" % action_name}

	var deadzone: float = float(params.get("deadzone", 0.5))
	var value := {"deadzone": deadzone, "events": []}
	# No set_initial_value() here — see project_configuration.gd's _set_and_save
	# for why that would make save() silently skip persisting this at all.
	ProjectSettings.set_setting(key, value)
	ProjectSettings.save()

	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, deadzone)
	return {"action_name": action_name, "deadzone": deadzone}


static func remove_input_action(params: Dictionary, _ei: EditorInterface) -> Variant:
	var action_name: String = params.get("action_name", "")
	var key := "input/%s" % action_name
	if not ProjectSettings.has_setting(key):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "No such action %s" % action_name}
	ProjectSettings.clear(key)
	ProjectSettings.save()
	if InputMap.has_action(action_name):
		InputMap.erase_action(action_name)
	return {"action_name": action_name}


static func add_key_to_action(params: Dictionary, _ei: EditorInterface) -> Variant:
	var action_name: String = params.get("action_name", "")
	if action_name == "" or not InputMap.has_action(action_name):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "No such action %s" % action_name}
	var event := InputEventKey.new()
	event.keycode = int(params.get("keycode", 0))
	InputMap.action_add_event(action_name, event)
	_persist_action(action_name)
	return {"action_name": action_name, "keycode": event.keycode}


static func add_input_event_to_action(params: Dictionary, _ei: EditorInterface) -> Variant:
	var action_name: String = params.get("action_name", "")
	if action_name == "" or not InputMap.has_action(action_name):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "No such action %s" % action_name}

	var event_type: String = params.get("type", "key")
	var event: InputEvent
	match event_type:
		"key":
			var e := InputEventKey.new()
			e.keycode = int(params.get("keycode", 0))
			event = e
		"mouse_button":
			var e2 := InputEventMouseButton.new()
			e2.button_index = int(params.get("button_index", MOUSE_BUTTON_LEFT))
			event = e2
		"joypad_button":
			var e3 := InputEventJoypadButton.new()
			e3.button_index = int(params.get("button_index", 0))
			event = e3
		_:
			return {"__error_code__": "INVALID_PARAMS", "__error_message__": "Unknown event type '%s'" % event_type}

	InputMap.action_add_event(action_name, event)
	_persist_action(action_name)
	return {"action_name": action_name, "type": event_type}


static func _persist_action(action_name: String) -> void:
	var key := "input/%s" % action_name
	var events: Array = []
	for event in InputMap.action_get_events(action_name):
		events.append(event)
	var value := {"deadzone": InputMap.action_get_deadzone(action_name), "events": events}
	ProjectSettings.set_setting(key, value)
	ProjectSettings.save()


static func _describe_input_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {"type": "key", "keycode": event.keycode}
	if event is InputEventMouseButton:
		return {"type": "mouse_button", "button_index": event.button_index}
	if event is InputEventJoypadButton:
		return {"type": "joypad_button", "button_index": event.button_index}
	return {"type": event.get_class()}
