## Handlers for the asset_management tool category (basic subset for Phase 1).
class_name GodotMCPAssetManagementHandlers
extends RefCounted

const FsWalk = preload("res://addons/godot_mcp_bridge/utils/fs_walk.gd")

const DEFAULT_ASSET_EXTENSIONS := ["png", "jpg", "jpeg", "svg", "webp", "ogg", "wav", "mp3", "ttf", "otf", "tres", "res"]


static func register(dispatch: Dictionary) -> void:
	dispatch["list_assets"] = list_assets
	dispatch["get_resource_info"] = get_resource_info
	dispatch["resolve_uid"] = resolve_uid
	dispatch["diff_images"] = diff_images
	dispatch["get_image_info"] = get_image_info
	dispatch["reimport_assets"] = reimport_assets
	dispatch["rescan_filesystem"] = rescan_filesystem
	dispatch["set_import_options"] = set_import_options


static func list_assets(params: Dictionary, _ei: EditorInterface) -> Dictionary:
	var extensions: Array = params.get("extensions", DEFAULT_ASSET_EXTENSIONS)
	return {"assets": FsWalk.list_files("res://", PackedStringArray(extensions))}


static func get_resource_info(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "" or not FileAccess.file_exists(path):
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No resource at %s" % path}
	var res: Resource = load(path)
	if res == null:
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "Could not load resource at %s" % path}
	return {"path": path, "type": res.get_class()}


## Translates between uid:// and res:// identifiers. Provide exactly one of
## `uid` or `path`.
static func resolve_uid(params: Dictionary, _ei: EditorInterface) -> Variant:
	var uid_text: String = params.get("uid", "")
	var path: String = params.get("path", "")

	if uid_text != "":
		var id: int = ResourceUID.text_to_id(uid_text)
		if id == ResourceUID.INVALID_ID or not ResourceUID.has_id(id):
			return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "Unknown uid %s" % uid_text}
		return {"uid": uid_text, "path": ResourceUID.get_id_path(id)}

	if path != "":
		if not FileAccess.file_exists(path):
			return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No resource at %s" % path}
		var id2: int = ResourceLoader.get_resource_uid(path)
		if id2 == ResourceUID.INVALID_ID:
			return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "%s has no assigned uid" % path}
		return {"path": path, "uid": ResourceUID.id_to_text(id2)}

	return {"__error_code__": "INVALID_PARAMS", "__error_message__": "Provide either uid or path"}


static func diff_images(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path_a: String = params.get("path_a", "")
	var path_b: String = params.get("path_b", "")
	if path_a == "" or path_b == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "path_a and path_b are required"}
	var img_a := Image.new()
	var img_b := Image.new()
	if img_a.load(path_a) != OK:
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "Could not load image at %s" % path_a}
	if img_b.load(path_b) != OK:
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "Could not load image at %s" % path_b}
	var w := mini(img_a.get_width(), img_b.get_width())
	var h := mini(img_a.get_height(), img_b.get_height())
	var diff_count := 0
	var total := w * h
	for y in range(h):
		for x in range(w):
			if img_a.get_pixel(x, y) != img_b.get_pixel(x, y):
				diff_count += 1
	return {
		"width_a": img_a.get_width(), "height_a": img_a.get_height(),
		"width_b": img_b.get_width(), "height_b": img_b.get_height(),
		"differing_pixels": diff_count,
		"total_pixels": total,
		"diff_percentage": (float(diff_count) / float(total) * 100.0) if total > 0 else 0.0,
	}


static func get_image_info(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "" or not FileAccess.file_exists(path):
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No image at %s" % path}
	var img := Image.new()
	if img.load(path) != OK:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Could not load image at %s" % path}
	var file := FileAccess.open(path, FileAccess.READ)
	var file_size: int = file.get_length() if file else 0
	return {
		"width": img.get_width(),
		"height": img.get_height(),
		"format": str(img.get_format()),
		"has_alpha": img.detect_alpha() != Image.ALPHA_NONE,
		"file_size": file_size,
	}


static func reimport_assets(params: Dictionary, ei: EditorInterface) -> Variant:
	var paths: Array = params.get("paths", [])
	if paths.is_empty():
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "paths array is required"}
	var packed := PackedStringArray()
	for p in paths:
		packed.append(String(p))
	ei.get_resource_filesystem().reimport_files(packed)
	return {"reimported": paths}


static func rescan_filesystem(_params: Dictionary, ei: EditorInterface) -> Dictionary:
	ei.get_resource_filesystem().scan()
	return {"scanned": true}


static func set_import_options(params: Dictionary, ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "path is required"}
	var import_path: String = path + ".import"
	if not FileAccess.file_exists(import_path):
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No .import file at %s" % import_path}
	var cfg := ConfigFile.new()
	var err := cfg.load(import_path)
	if err != OK:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Could not load .import file"}
	var options: Dictionary = params.get("options", {})
	var set_keys: Array = []
	for key in options.keys():
		cfg.set_value("params", String(key), options[key])
		set_keys.append(key)
	cfg.save(import_path)
	ei.get_resource_filesystem().reimport_files(PackedStringArray([path]))
	return {"path": path, "options_set": set_keys}
