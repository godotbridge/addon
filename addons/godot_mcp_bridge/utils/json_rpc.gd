## Wire-format helpers matching protocol/MESSAGES.md.
class_name GodotMCPJsonRpc
extends RefCounted


## Parses one incoming frame. Returns null (and logs) if it isn't a well-formed request.
static func decode_request(raw: String) -> Dictionary:
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	if not parsed.has("id") or not parsed.has("tool"):
		return {}
	if not parsed.has("params"):
		parsed["params"] = {}
	return parsed


## JSON.stringify() has no native representation for Vector2/Vector3/Color/
## Rect2/NodePath — its fallback for anything outside (null, bool, int,
## float, String, Array, Dictionary) is to stringify via `str()` and wrap it
## as a JSON string literal (confirmed empirically: a Node2D's `position`
## came back as the literal string "(0, 0)" instead of {"x":0,"y":0}),
## silently destroying structure for any caller that needs the components.
## Recursively convert these to the same {"x":..,"y":..}-style dictionaries
## the rest of this addon's handlers already use for such values by
## convention, before handing off to JSON.stringify.
static func _sanitize(value: Variant) -> Variant:
	match typeof(value):
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return {"x": value.x, "y": value.y}
		TYPE_VECTOR3, TYPE_VECTOR3I:
			return {"x": value.x, "y": value.y, "z": value.z}
		TYPE_COLOR:
			return {"r": value.r, "g": value.g, "b": value.b, "a": value.a}
		TYPE_RECT2, TYPE_RECT2I:
			return {"x": value.position.x, "y": value.position.y, "width": value.size.x, "height": value.size.y}
		TYPE_NODE_PATH:
			return str(value)
		TYPE_ARRAY:
			var out_array: Array = []
			for item in value:
				out_array.append(_sanitize(item))
			return out_array
		TYPE_DICTIONARY:
			var out_dict := {}
			for key in value.keys():
				out_dict[str(key)] = _sanitize(value[key])
			return out_dict
		_:
			return value


static func encode_success(id: String, result: Variant) -> String:
	return JSON.stringify({"id": id, "ok": true, "result": _sanitize(result)})


static func encode_error(id: String, code: String, message: String) -> String:
	return JSON.stringify({
		"id": id,
		"ok": false,
		"error": {"code": code, "message": message},
	})
