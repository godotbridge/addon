## Handlers for the api_reference tool category. list_tools and godot_guide
## are implemented purely in Python (server/src/godot_mcp/tools/api_reference.py)
## since they don't need live engine state — only list_classes/describe_class,
## which need ClassDB, go through the bridge.
class_name GodotMCPApiReferenceHandlers
extends RefCounted


static func register(dispatch: Dictionary) -> void:
	dispatch["list_classes"] = list_classes
	dispatch["describe_class"] = describe_class


static func list_classes(params: Dictionary, _ei: EditorInterface) -> Dictionary:
	var inherits: String = params.get("inherits", "")
	var instantiable_only: bool = bool(params.get("instantiable_only", true))

	var classes: Array = []
	for class_name_str in ClassDB.get_class_list():
		if inherits != "" and not ClassDB.is_parent_class(class_name_str, inherits):
			continue
		if instantiable_only and not ClassDB.can_instantiate(class_name_str):
			continue
		classes.append(class_name_str)
	classes.sort()
	return {"classes": classes}


static func describe_class(params: Dictionary, _ei: EditorInterface) -> Variant:
	var class_name_str: String = params.get("class_name", "")
	if not ClassDB.class_exists(class_name_str):
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No class named '%s'" % class_name_str}

	var properties: Array = []
	for prop in ClassDB.class_get_property_list(class_name_str, true):
		properties.append(prop.get("name", ""))

	var methods: Array = []
	for method in ClassDB.class_get_method_list(class_name_str, true):
		methods.append(method.get("name", ""))

	var signals: Array = []
	for sig in ClassDB.class_get_signal_list(class_name_str, true):
		signals.append(sig.get("name", ""))

	return {
		"class_name": class_name_str,
		"parent_class": ClassDB.get_parent_class(class_name_str),
		"can_instantiate": ClassDB.can_instantiate(class_name_str),
		"properties": properties,
		"methods": methods,
		"signals": signals,
	}
