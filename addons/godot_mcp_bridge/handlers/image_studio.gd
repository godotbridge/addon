## Handlers for the image_studio tool category.
class_name GodotMCPImageStudioHandlers
extends RefCounted

const PROJECT_DIR := "res://image_studio/"


static func register(dispatch: Dictionary) -> void:
	dispatch["create_image_studio_project"] = create_image_studio_project
	dispatch["inspect_image_studio_project"] = inspect_image_studio_project
	dispatch["update_image_studio_project"] = update_image_studio_project
	dispatch["list_image_studio_projects"] = list_image_studio_projects
	dispatch["import_image_studio_asset"] = import_image_studio_asset
	dispatch["import_image_studio_gif"] = import_image_studio_gif
	dispatch["export_image_studio_asset"] = export_image_studio_asset
	dispatch["export_image_studio_animations_zip"] = export_image_studio_animations_zip
	dispatch["export_image_studio_animation_gif"] = export_image_studio_animation_gif
	dispatch["configure_image_studio_animation"] = configure_image_studio_animation
	dispatch["configure_image_studio_rig"] = configure_image_studio_rig
	dispatch["configure_image_studio_tile_map"] = configure_image_studio_tile_map
	dispatch["compose_image_studio_layers"] = compose_image_studio_layers
	dispatch["apply_image_studio_pixel_patch"] = apply_image_studio_pixel_patch
	dispatch["slice_image_studio_sheet"] = slice_image_studio_sheet
	dispatch["transform_image_studio_asset"] = transform_image_studio_asset
	dispatch["request_image_studio_generation"] = request_image_studio_generation
	dispatch["get_image_studio_generation_request"] = get_image_studio_generation_request
	dispatch["list_image_studio_generation_requests"] = list_image_studio_generation_requests
	dispatch["cancel_image_studio_generation_request"] = cancel_image_studio_generation_request
	dispatch["prepare_pixel_asset"] = prepare_pixel_asset


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _ensure_project_dir() -> void:
	if not DirAccess.dir_exists_absolute(PROJECT_DIR):
		DirAccess.make_dir_recursive_absolute(PROJECT_DIR)


static func _project_path(name: String) -> String:
	return PROJECT_DIR + name + ".tres"


static func _load_project(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return {"__error_code__": "PROJECT_NOT_FOUND", "__error_message__": "No project at %s" % path}
	var res: Resource = load(path)
	if res == null:
		return {"__error_code__": "LOAD_FAILED", "__error_message__": "Could not load project at %s" % path}
	return res


static func _save_project(res: Resource, path: String) -> int:
	return ResourceSaver.save(res, path)


static func _new_layer(width: int, height: int, name: String) -> Dictionary:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	return {"name": name, "image": img}


static func _project_to_dict(res: Resource, path: String) -> Dictionary:
	var data := {
		"path": path,
		"name": res.get_meta("project_name", ""),
		"width": int(res.get_meta("width", 0)),
		"height": int(res.get_meta("height", 0)),
		"palette": res.get_meta("palette", []),
		"layer_count": int(res.get_meta("layer_count", 0)),
		"layers": [],
		"animations": res.get_meta("animations", {}),
		"rig": res.get_meta("rig", {}),
		"tile_map": res.get_meta("tile_map", {}),
	}
	var lc: int = data["layer_count"]
	for i in range(lc):
		var lname: String = res.get_meta("layer_%d_name" % i, "layer_%d" % i)
		data["layers"].append(lname)
	return data


# ---------------------------------------------------------------------------
# Tool handlers
# ---------------------------------------------------------------------------

static func create_image_studio_project(params: Dictionary, _ei: EditorInterface) -> Variant:
	_ensure_project_dir()
	var pname: String = params.get("name", "untitled")
	var width: int = params.get("width", 32)
	var height: int = params.get("height", 32)
	var palette: Array = params.get("palette", [])

	var path := _project_path(pname)
	if FileAccess.file_exists(path):
		return {"__error_code__": "ALREADY_EXISTS", "__error_message__": "Project already exists at %s" % path}

	var res := Resource.new()
	res.set_meta("project_name", pname)
	res.set_meta("width", width)
	res.set_meta("height", height)
	res.set_meta("palette", palette)
	res.set_meta("layer_count", 1)
	res.set_meta("animations", {})
	res.set_meta("rig", {})
	res.set_meta("tile_map", {})

	# Create default layer
	var layer := _new_layer(width, height, "background")
	res.set_meta("layer_0_name", layer["name"])
	res.set_meta("layer_0_image", layer["image"])

	var err := _save_project(res, path)
	if err != OK:
		return {"__error_code__": "SAVE_FAILED", "__error_message__": "Failed to save project (err %d)" % err}
	return {"created": true, "path": path, "width": width, "height": height}


static func inspect_image_studio_project(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("project_path", "")
	var res = _load_project(path)
	if res is Dictionary:
		return res
	return _project_to_dict(res, path)


static func update_image_studio_project(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("project_path", "")
	var res = _load_project(path)
	if res is Dictionary:
		return res

	if params.has("name"):
		res.set_meta("project_name", params["name"])
	if params.has("palette"):
		res.set_meta("palette", params["palette"])

	# Handle canvas resize
	var old_w: int = res.get_meta("width", 32)
	var old_h: int = res.get_meta("height", 32)
	var new_w: int = params.get("width", old_w)
	var new_h: int = params.get("height", old_h)
	if new_w != old_w or new_h != old_h:
		res.set_meta("width", new_w)
		res.set_meta("height", new_h)
		var lc: int = res.get_meta("layer_count", 0)
		for i in range(lc):
			var img: Image = res.get_meta("layer_%d_image" % i)
			if img:
				img.resize(new_w, new_h, Image.INTERPOLATE_NEAREST)

	_save_project(res, path)
	return {"updated": true, "path": path}


static func list_image_studio_projects(params: Dictionary, _ei: EditorInterface) -> Variant:
	_ensure_project_dir()
	var projects := []
	var dir := DirAccess.open(PROJECT_DIR)
	if dir == null:
		return {"projects": []}
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			var fpath := PROJECT_DIR + fname
			var res: Resource = load(fpath)
			if res and res.has_meta("project_name"):
				projects.append({
					"path": fpath,
					"name": res.get_meta("project_name", ""),
					"width": int(res.get_meta("width", 0)),
					"height": int(res.get_meta("height", 0)),
				})
		fname = dir.get_next()
	dir.list_dir_end()
	return {"projects": projects}


static func import_image_studio_asset(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("project_path", "")
	var source: String = params.get("source_path", "")
	var layer_name: String = params.get("layer_name", "")

	var res = _load_project(path)
	if res is Dictionary:
		return res

	var src_img := Image.load_from_file(source)
	if src_img == null:
		return {"__error_code__": "IMPORT_FAILED", "__error_message__": "Could not load image %s" % source}

	var w: int = res.get_meta("width", 32)
	var h: int = res.get_meta("height", 32)
	if src_img.get_width() != w or src_img.get_height() != h:
		src_img.resize(w, h, Image.INTERPOLATE_NEAREST)

	var lc: int = res.get_meta("layer_count", 0)
	if layer_name == "":
		layer_name = "imported_%d" % lc
	res.set_meta("layer_%d_name" % lc, layer_name)
	res.set_meta("layer_%d_image" % lc, src_img)
	res.set_meta("layer_count", lc + 1)
	_save_project(res, path)
	return {"imported": true, "layer_name": layer_name, "layer_index": lc}


static func import_image_studio_gif(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("project_path", "")
	var gif_path: String = params.get("gif_path", "")
	var anim_name: String = params.get("animation_name", "")

	var res = _load_project(path)
	if res is Dictionary:
		return res

	if not FileAccess.file_exists(gif_path):
		return {"__error_code__": "FILE_NOT_FOUND", "__error_message__": "GIF not found at %s" % gif_path}

	# GIF parsing is not natively supported in Godot; store reference for
	# external processing.
	if anim_name == "":
		anim_name = gif_path.get_file().get_basename()

	var animations: Dictionary = res.get_meta("animations", {})
	animations[anim_name] = {"source_gif": gif_path, "fps": 12, "loop": true, "frames": []}
	res.set_meta("animations", animations)
	_save_project(res, path)
	return {"imported": true, "animation_name": anim_name, "source": gif_path}


static func export_image_studio_asset(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("project_path", "")
	var output: String = params.get("output_path", "")
	var fmt: String = params.get("format", "png")
	var layer_filter: Array = params.get("layers", [])

	var res = _load_project(path)
	if res is Dictionary:
		return res

	var w: int = res.get_meta("width", 32)
	var h: int = res.get_meta("height", 32)
	var lc: int = res.get_meta("layer_count", 0)

	# Composite selected layers onto a single image
	var composite := Image.create(w, h, false, Image.FORMAT_RGBA8)
	composite.fill(Color.TRANSPARENT)
	for i in range(lc):
		var lname: String = res.get_meta("layer_%d_name" % i, "")
		if layer_filter.size() > 0 and not layer_filter.has(lname):
			continue
		var layer_img: Image = res.get_meta("layer_%d_image" % i)
		if layer_img:
			composite.blend_rect(layer_img, Rect2i(0, 0, w, h), Vector2i.ZERO)

	var err: int
	if fmt == "png":
		err = composite.save_png(output)
	else:
		err = composite.save_png(output)  # fallback to png

	if err != OK:
		return {"__error_code__": "EXPORT_FAILED", "__error_message__": "Failed to save to %s (err %d)" % [output, err]}
	return {"exported": true, "output_path": output, "format": fmt}


static func export_image_studio_animations_zip(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("project_path", "")
	var output: String = params.get("output_path", "")

	var res = _load_project(path)
	if res is Dictionary:
		return res

	var animations: Dictionary = res.get_meta("animations", {})
	if animations.is_empty():
		return {"__error_code__": "NO_ANIMATIONS", "__error_message__": "Project has no animations"}

	# Use ZIPPacker to create a zip
	var writer := ZIPPacker.new()
	var err := writer.open(output)
	if err != OK:
		return {"__error_code__": "ZIP_FAILED", "__error_message__": "Could not create ZIP at %s" % output}

	var w: int = res.get_meta("width", 32)
	var h: int = res.get_meta("height", 32)

	for anim_name: String in animations:
		var anim: Dictionary = animations[anim_name]
		var frames: Array = anim.get("frames", [])
		for fi in range(frames.size()):
			var frame_idx: int = frames[fi]
			var lkey := "layer_%d_image" % frame_idx
			var img: Image = res.get_meta(lkey)
			if img:
				var png_data := img.save_png_to_buffer()
				writer.start_file("%s/frame_%03d.png" % [anim_name, fi])
				writer.write_file(png_data)
				writer.close_file()

	writer.close()
	return {"exported": true, "output_path": output, "animation_count": animations.size()}


static func export_image_studio_animation_gif(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("project_path", "")
	var anim_name: String = params.get("animation_name", "")
	var output: String = params.get("output_path", "")

	var res = _load_project(path)
	if res is Dictionary:
		return res

	var animations: Dictionary = res.get_meta("animations", {})
	if not animations.has(anim_name):
		return {"__error_code__": "ANIMATION_NOT_FOUND", "__error_message__": "No animation named '%s'" % anim_name}

	# Godot does not natively encode GIF. Export frames as PNGs in a directory
	# and return the path for external GIF assembly.
	var anim: Dictionary = animations[anim_name]
	var frames: Array = anim.get("frames", [])
	var frame_dir := output.get_base_dir() + "/" + anim_name + "_frames"
	DirAccess.make_dir_recursive_absolute(frame_dir)

	for fi in range(frames.size()):
		var frame_idx: int = frames[fi]
		var img: Image = res.get_meta("layer_%d_image" % frame_idx)
		if img:
			img.save_png(frame_dir + "/frame_%03d.png" % fi)

	return {
		"exported": true,
		"frames_dir": frame_dir,
		"frame_count": frames.size(),
		"fps": anim.get("fps", 12),
		"note": "GIF encoding not natively supported; frames exported as PNGs.",
	}


static func configure_image_studio_animation(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("project_path", "")
	var anim_name: String = params.get("animation_name", "")

	var res = _load_project(path)
	if res is Dictionary:
		return res

	var animations: Dictionary = res.get_meta("animations", {})
	var anim: Dictionary = animations.get(anim_name, {})
	anim["fps"] = params.get("fps", anim.get("fps", 12))
	anim["loop"] = params.get("loop", anim.get("loop", true))
	if params.has("frames") and params["frames"] is Array and params["frames"].size() > 0:
		anim["frames"] = params["frames"]
	animations[anim_name] = anim
	res.set_meta("animations", animations)
	_save_project(res, path)
	return {"configured": true, "animation_name": anim_name, "settings": anim}


static func configure_image_studio_rig(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("project_path", "")

	var res = _load_project(path)
	if res is Dictionary:
		return res

	var rig := {
		"bones": params.get("bones", []),
		"bind_layer": params.get("bind_layer", ""),
	}
	res.set_meta("rig", rig)
	_save_project(res, path)
	return {"configured": true, "rig": rig}


static func configure_image_studio_tile_map(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("project_path", "")

	var res = _load_project(path)
	if res is Dictionary:
		return res

	var tile_map := {
		"tile_width": params.get("tile_width", 16),
		"tile_height": params.get("tile_height", 16),
		"columns": params.get("columns", 0),
		"rows": params.get("rows", 0),
	}
	res.set_meta("tile_map", tile_map)
	_save_project(res, path)
	return {"configured": true, "tile_map": tile_map}


static func compose_image_studio_layers(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("project_path", "")
	var layer_names: Array = params.get("layer_names", [])
	var merge_mode: String = params.get("merge_mode", "normal")
	var output_layer: String = params.get("output_layer", "")

	var res = _load_project(path)
	if res is Dictionary:
		return res

	var w: int = res.get_meta("width", 32)
	var h: int = res.get_meta("height", 32)
	var lc: int = res.get_meta("layer_count", 0)

	var composite := Image.create(w, h, false, Image.FORMAT_RGBA8)
	composite.fill(Color.TRANSPARENT)

	for i in range(lc):
		var lname: String = res.get_meta("layer_%d_name" % i, "")
		if layer_names.has(lname):
			var img: Image = res.get_meta("layer_%d_image" % i)
			if img:
				composite.blend_rect(img, Rect2i(0, 0, w, h), Vector2i.ZERO)

	if output_layer == "":
		output_layer = "composed"
	res.set_meta("layer_%d_name" % lc, output_layer)
	res.set_meta("layer_%d_image" % lc, composite)
	res.set_meta("layer_count", lc + 1)
	_save_project(res, path)
	return {"composed": true, "output_layer": output_layer, "layer_index": lc}


static func apply_image_studio_pixel_patch(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("project_path", "")
	var layer_name: String = params.get("layer_name", "")
	var patches: Array = params.get("patches", [])

	var res = _load_project(path)
	if res is Dictionary:
		return res

	var lc: int = res.get_meta("layer_count", 0)
	var layer_idx := -1
	for i in range(lc):
		if res.get_meta("layer_%d_name" % i, "") == layer_name:
			layer_idx = i
			break
	if layer_idx < 0:
		return {"__error_code__": "LAYER_NOT_FOUND", "__error_message__": "No layer named '%s'" % layer_name}

	var img: Image = res.get_meta("layer_%d_image" % layer_idx)
	if img == null:
		return {"__error_code__": "LAYER_CORRUPT", "__error_message__": "Layer image is null"}

	var applied := 0
	for patch in patches:
		var x: int = patch.get("x", 0)
		var y: int = patch.get("y", 0)
		var color_str: String = patch.get("color", "#ffffff")
		var color := Color.html(color_str)
		if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
			img.set_pixel(x, y, color)
			applied += 1

	_save_project(res, path)
	return {"applied": true, "pixels_modified": applied}


static func slice_image_studio_sheet(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("project_path", "")
	var frame_w: int = params.get("frame_width", 16)
	var frame_h: int = params.get("frame_height", 16)
	var source_layer: String = params.get("source_layer", "")
	var margin: int = params.get("margin", 0)
	var spacing: int = params.get("spacing", 0)

	var res = _load_project(path)
	if res is Dictionary:
		return res

	var lc: int = res.get_meta("layer_count", 0)
	var src_img: Image = null

	if source_layer != "":
		for i in range(lc):
			if res.get_meta("layer_%d_name" % i, "") == source_layer:
				src_img = res.get_meta("layer_%d_image" % i)
				break
	else:
		if lc > 0:
			src_img = res.get_meta("layer_0_image")

	if src_img == null:
		return {"__error_code__": "NO_SOURCE", "__error_message__": "No source layer to slice"}

	var img_w := src_img.get_width()
	var img_h := src_img.get_height()
	var cols := (img_w - 2 * margin + spacing) / (frame_w + spacing)
	var rows := (img_h - 2 * margin + spacing) / (frame_h + spacing)
	var frame_count := 0

	for row in range(rows):
		for col in range(cols):
			var sx := margin + col * (frame_w + spacing)
			var sy := margin + row * (frame_h + spacing)
			var frame := Image.create(frame_w, frame_h, false, Image.FORMAT_RGBA8)
			frame.blit_rect(src_img, Rect2i(sx, sy, frame_w, frame_h), Vector2i.ZERO)
			var idx := lc + frame_count
			res.set_meta("layer_%d_name" % idx, "frame_%d" % frame_count)
			res.set_meta("layer_%d_image" % idx, frame)
			frame_count += 1

	res.set_meta("layer_count", lc + frame_count)
	_save_project(res, path)
	return {"sliced": true, "frames_created": frame_count, "columns": cols, "rows": rows}


static func transform_image_studio_asset(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("project_path", "")
	var operation: String = params.get("operation", "")
	var layer_name: String = params.get("layer_name", "")

	var res = _load_project(path)
	if res is Dictionary:
		return res

	var lc: int = res.get_meta("layer_count", 0)

	# Collect target layers
	var targets := []
	for i in range(lc):
		var lname: String = res.get_meta("layer_%d_name" % i, "")
		if layer_name == "" or lname == layer_name:
			targets.append(i)

	if targets.is_empty():
		return {"__error_code__": "LAYER_NOT_FOUND", "__error_message__": "No matching layer for '%s'" % layer_name}

	for idx in targets:
		var img: Image = res.get_meta("layer_%d_image" % idx)
		if img == null:
			continue
		match operation:
			"flip_h":
				img.flip_x()
			"flip_v":
				img.flip_y()
			"rotate_90":
				img.rotate_90(CLOCKWISE)
			"rotate_180":
				img.rotate_180()
			"rotate_270":
				img.rotate_90(COUNTERCLOCKWISE)
			"resize":
				var sx: float = params.get("scale_x", 1.0)
				var sy: float = params.get("scale_y", 1.0)
				var new_w := int(img.get_width() * sx)
				var new_h := int(img.get_height() * sy)
				img.resize(new_w, new_h, Image.INTERPOLATE_NEAREST)
			_:
				return {"__error_code__": "UNKNOWN_OP", "__error_message__": "Unknown operation '%s'" % operation}

	_save_project(res, path)
	return {"transformed": true, "operation": operation, "layers_affected": targets.size()}


static func request_image_studio_generation(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("project_path", "")
	var prompt: String = params.get("prompt", "")
	var layer_name: String = params.get("layer_name", "")
	var style: String = params.get("style", "pixel_art")
	var image_b64: String = params.get("image_base64", "")

	var res = _load_project(path)
	if res is Dictionary:
		return res

	var request_id := str(randi() % 1000000).pad_zeros(8)
	var status := "completed" if image_b64 != "" else "pending"

	var lc: int = res.get_meta("layer_count", 0)
	if layer_name == "":
		layer_name = "generated_%s" % request_id

	if image_b64 != "":
		var raw := Marshalls.base64_to_raw(image_b64)
		var img := Image.new()
		var err := img.load_png_from_buffer(raw)
		if err != OK:
			return {"__error_code__": "DECODE_FAILED", "__error_message__": "Could not decode generated PNG (err %d)" % err}

		var w: int = res.get_meta("width", 32)
		var h: int = res.get_meta("height", 32)
		if img.get_width() != w or img.get_height() != h:
			img.resize(w, h, Image.INTERPOLATE_NEAREST)

		res.set_meta("layer_%d_name" % lc, layer_name)
		res.set_meta("layer_%d_image" % lc, img)
		res.set_meta("layer_count", lc + 1)

	var requests: Dictionary = res.get_meta("generation_requests", {})
	requests[request_id] = {
		"prompt": prompt,
		"layer_name": layer_name,
		"style": style,
		"status": status,
		"created_at": Time.get_datetime_string_from_system(),
	}
	res.set_meta("generation_requests", requests)
	_save_project(res, path)

	var result := {"request_id": request_id, "status": status}
	if image_b64 != "":
		result["layer_name"] = layer_name
		result["layer_index"] = lc
	return result


static func get_image_studio_generation_request(params: Dictionary, _ei: EditorInterface) -> Variant:
	var request_id: String = params.get("request_id", "")

	# Search all projects for the request
	_ensure_project_dir()
	var dir := DirAccess.open(PROJECT_DIR)
	if dir == null:
		return {"__error_code__": "NOT_FOUND", "__error_message__": "Request not found"}

	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			var fpath := PROJECT_DIR + fname
			var res: Resource = load(fpath)
			if res:
				var requests: Dictionary = res.get_meta("generation_requests", {})
				if requests.has(request_id):
					var req: Dictionary = requests[request_id]
					req["request_id"] = request_id
					req["project_path"] = fpath
					return req
		fname = dir.get_next()
	dir.list_dir_end()
	return {"__error_code__": "NOT_FOUND", "__error_message__": "Request '%s' not found" % request_id}


static func list_image_studio_generation_requests(params: Dictionary, _ei: EditorInterface) -> Variant:
	var filter_path: String = params.get("project_path", "")
	_ensure_project_dir()
	var all_requests := []

	var dir := DirAccess.open(PROJECT_DIR)
	if dir == null:
		return {"requests": []}
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			var fpath := PROJECT_DIR + fname
			if filter_path != "" and fpath != filter_path:
				fname = dir.get_next()
				continue
			var res: Resource = load(fpath)
			if res:
				var requests: Dictionary = res.get_meta("generation_requests", {})
				for rid: String in requests:
					var req: Dictionary = requests[rid].duplicate()
					req["request_id"] = rid
					req["project_path"] = fpath
					all_requests.append(req)
		fname = dir.get_next()
	dir.list_dir_end()
	return {"requests": all_requests}


static func cancel_image_studio_generation_request(params: Dictionary, _ei: EditorInterface) -> Variant:
	var request_id: String = params.get("request_id", "")
	_ensure_project_dir()

	var dir := DirAccess.open(PROJECT_DIR)
	if dir == null:
		return {"__error_code__": "NOT_FOUND", "__error_message__": "Request not found"}

	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			var fpath := PROJECT_DIR + fname
			var res: Resource = load(fpath)
			if res:
				var requests: Dictionary = res.get_meta("generation_requests", {})
				if requests.has(request_id):
					var req: Dictionary = requests[request_id]
					if req.get("status", "") == "pending":
						req["status"] = "cancelled"
						requests[request_id] = req
						res.set_meta("generation_requests", requests)
						_save_project(res, fpath)
						return {"cancelled": true, "request_id": request_id}
					else:
						return {"__error_code__": "NOT_CANCELLABLE", "__error_message__": "Request status is '%s'" % req.get("status", "")}
		fname = dir.get_next()
	dir.list_dir_end()
	return {"__error_code__": "NOT_FOUND", "__error_message__": "Request '%s' not found" % request_id}


static func prepare_pixel_asset(params: Dictionary, _ei: EditorInterface) -> Variant:
	var path: String = params.get("project_path", "")
	var output: String = params.get("output_path", "")
	var max_size: int = params.get("max_size", 0)
	var import_flags: Dictionary = params.get("import_flags", {})

	var res = _load_project(path)
	if res is Dictionary:
		return res

	var w: int = res.get_meta("width", 32)
	var h: int = res.get_meta("height", 32)
	var lc: int = res.get_meta("layer_count", 0)

	# Flatten all layers
	var composite := Image.create(w, h, false, Image.FORMAT_RGBA8)
	composite.fill(Color.TRANSPARENT)
	for i in range(lc):
		var img: Image = res.get_meta("layer_%d_image" % i)
		if img:
			composite.blend_rect(img, Rect2i(0, 0, w, h), Vector2i.ZERO)

	# Optional downscale if max_size is set
	if max_size > 0:
		if composite.get_width() > max_size or composite.get_height() > max_size:
			var scale_factor: float = float(max_size) / max(composite.get_width(), composite.get_height())
			var nw := int(composite.get_width() * scale_factor)
			var nh := int(composite.get_height() * scale_factor)
			composite.resize(nw, nh, Image.INTERPOLATE_NEAREST)

	var err := composite.save_png(output)
	if err != OK:
		return {"__error_code__": "SAVE_FAILED", "__error_message__": "Failed to save to %s (err %d)" % [output, err]}

	# Write a .import companion if flags provided
	if not import_flags.is_empty():
		var import_path := output + ".import"
		var f := FileAccess.open(import_path, FileAccess.WRITE)
		if f:
			f.store_line("[remap]")
			f.store_line("")
			f.store_line("importer=\"texture\"")
			f.store_line("type=\"CompressedTexture2D\"")
			f.store_line("")
			f.store_line("[params]")
			for key: String in import_flags:
				f.store_line("%s=%s" % [key, str(import_flags[key])])
			f.close()

	return {"prepared": true, "output_path": output, "width": composite.get_width(), "height": composite.get_height()}
