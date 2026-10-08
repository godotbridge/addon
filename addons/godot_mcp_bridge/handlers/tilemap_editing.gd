## Handlers for the tilemap_editing tool category. Targets the classic
## TileMap node (multiple layers on one node) — still functional in 4.5,
## though Godot's newer recommended pattern is one TileMapLayer node per
## layer. Revisit if a future engine version removes TileMap outright.
class_name GodotMCPTilemapEditingHandlers
extends RefCounted

const NodeResolver = preload("res://addons/godot_mcp_bridge/utils/node_resolver.gd")


static func register(dispatch: Dictionary) -> void:
	dispatch["create_tileset"] = create_tileset
	dispatch["tilemap_set_cell"] = tilemap_set_cell
	dispatch["tilemap_set_cells"] = tilemap_set_cells
	dispatch["tilemap_fill_rect"] = tilemap_fill_rect
	dispatch["tilemap_get_cell"] = tilemap_get_cell
	dispatch["tilemap_clear"] = tilemap_clear
	dispatch["tilemap_get_used_cells"] = tilemap_get_used_cells
	dispatch["tilemap_get_info"] = tilemap_get_info
	dispatch["configure_tileset_atlas"] = configure_tileset_atlas
	dispatch["configure_tileset_layers"] = configure_tileset_layers
	dispatch["configure_tileset_terrains"] = configure_tileset_terrains
	dispatch["set_tileset_tile_data"] = set_tileset_tile_data


static func _vec2i(d: Dictionary) -> Vector2i:
	return Vector2i(int(d.get("x", 0)), int(d.get("y", 0)))


static func _vec2i_to_dict(v: Vector2i) -> Dictionary:
	return {"x": v.x, "y": v.y}


static func _get_tilemap(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if not (node is TileMap):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s is not a TileMap" % node.get_class()}
	return node


static func create_tileset(params: Dictionary, ei: EditorInterface) -> Variant:
	var path: String = params.get("path", "")
	if path == "":
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "path is required"}
	if FileAccess.file_exists(path):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "A tileset already exists at %s" % path}

	var tile_set := TileSet.new()
	var tile_size: Dictionary = params.get("tile_size", {"x": 16, "y": 16})
	tile_set.tile_size = _vec2i(tile_size)

	var texture_path: String = params.get("texture_path", "")
	if texture_path != "":
		if not FileAccess.file_exists(texture_path):
			return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No texture at %s" % texture_path}
		var loaded_tex: Variant = load(texture_path)
		if not (loaded_tex is Texture2D):
			return {
				"__error_code__": "RESOURCE_NOT_FOUND",
				"__error_message__": "%s is not a Texture2D resource (loaded as %s)" % [texture_path, loaded_tex.get_class() if loaded_tex != null else "null"],
			}
		var source := TileSetAtlasSource.new()
		source.texture = loaded_tex
		source.texture_region_size = tile_set.tile_size
		tile_set.add_source(source)

	var err: Error = ResourceSaver.save(tile_set, path)
	if err != OK:
		return {"__error_code__": "INTERNAL_ERROR", "__error_message__": "Could not save tileset: %s" % error_string(err)}

	var fs := ei.get_resource_filesystem()
	fs.update_file(path)
	fs.reimport_files([path])

	return {"path": path, "tile_size": _vec2i_to_dict(tile_set.tile_size)}


static func tilemap_set_cell(params: Dictionary, ei: EditorInterface) -> Variant:
	var tilemap := _get_tilemap(params, ei)
	if tilemap is Dictionary:
		return tilemap

	var layer: int = int(params.get("layer", 0))
	var coords := _vec2i(params.get("coords", {}))
	var source_id: int = int(params.get("source_id", -1))
	var atlas_coords := _vec2i(params.get("atlas_coords", {"x": 0, "y": 0}))
	var alternative_tile: int = int(params.get("alternative_tile", 0))

	tilemap.set_cell(layer, coords, source_id, atlas_coords, alternative_tile)
	return {"node_path": params.get("node_path", ""), "layer": layer, "coords": _vec2i_to_dict(coords), "source_id": source_id}


static func tilemap_set_cells(params: Dictionary, ei: EditorInterface) -> Variant:
	var tilemap := _get_tilemap(params, ei)
	if tilemap is Dictionary:
		return tilemap

	var layer: int = int(params.get("layer", 0))
	var cells: Array = params.get("cells", [])
	var updated := 0
	for cell in cells:
		var coords := _vec2i(cell.get("coords", {}))
		var source_id: int = int(cell.get("source_id", -1))
		var atlas_coords := _vec2i(cell.get("atlas_coords", {"x": 0, "y": 0}))
		var alternative_tile: int = int(cell.get("alternative_tile", 0))
		tilemap.set_cell(layer, coords, source_id, atlas_coords, alternative_tile)
		updated += 1
	return {"node_path": params.get("node_path", ""), "layer": layer, "updated": updated}


static func tilemap_fill_rect(params: Dictionary, ei: EditorInterface) -> Variant:
	var tilemap := _get_tilemap(params, ei)
	if tilemap is Dictionary:
		return tilemap

	var layer: int = int(params.get("layer", 0))
	var rect: Dictionary = params.get("rect", {})
	var x: int = int(rect.get("x", 0))
	var y: int = int(rect.get("y", 0))
	var width: int = int(rect.get("width", 1))
	var height: int = int(rect.get("height", 1))
	var source_id: int = int(params.get("source_id", -1))
	var atlas_coords := _vec2i(params.get("atlas_coords", {"x": 0, "y": 0}))

	var filled := 0
	for cx in range(x, x + width):
		for cy in range(y, y + height):
			tilemap.set_cell(layer, Vector2i(cx, cy), source_id, atlas_coords)
			filled += 1
	return {"node_path": params.get("node_path", ""), "layer": layer, "filled": filled}


static func tilemap_get_cell(params: Dictionary, ei: EditorInterface) -> Variant:
	var tilemap := _get_tilemap(params, ei)
	if tilemap is Dictionary:
		return tilemap

	var layer: int = int(params.get("layer", 0))
	var coords := _vec2i(params.get("coords", {}))
	var source_id: int = tilemap.get_cell_source_id(layer, coords)
	return {
		"source_id": source_id,
		"atlas_coords": _vec2i_to_dict(tilemap.get_cell_atlas_coords(layer, coords)),
		"alternative_tile": tilemap.get_cell_alternative_tile(layer, coords),
		"empty": source_id == -1,
	}


static func tilemap_clear(params: Dictionary, ei: EditorInterface) -> Variant:
	var tilemap := _get_tilemap(params, ei)
	if tilemap is Dictionary:
		return tilemap

	if params.has("layer"):
		tilemap.clear_layer(int(params["layer"]))
	else:
		tilemap.clear()
	return {"node_path": params.get("node_path", "")}


static func tilemap_get_used_cells(params: Dictionary, ei: EditorInterface) -> Variant:
	var tilemap := _get_tilemap(params, ei)
	if tilemap is Dictionary:
		return tilemap

	var layer: int = int(params.get("layer", 0))
	var cells: Array = []
	for coords in tilemap.get_used_cells(layer):
		cells.append(_vec2i_to_dict(coords))
	return {"cells": cells}


static func tilemap_get_info(params: Dictionary, ei: EditorInterface) -> Variant:
	var tilemap := _get_tilemap(params, ei)
	if tilemap is Dictionary:
		return tilemap

	var layers: Array = []
	for i in range(tilemap.get_layers_count()):
		layers.append({
			"index": i,
			"name": tilemap.get_layer_name(i),
			"enabled": tilemap.is_layer_enabled(i),
			"used_cell_count": tilemap.get_used_cells(i).size(),
		})

	return {
		"layer_count": tilemap.get_layers_count(),
		"tile_set_assigned": tilemap.tile_set != null,
		"layers": layers,
	}


static func _load_tileset(params: Dictionary) -> Variant:
	var path: String = params.get("tileset_path", "")
	if path == "" or not FileAccess.file_exists(path):
		return {"__error_code__": "RESOURCE_NOT_FOUND", "__error_message__": "No tileset at %s" % path}
	var res: Resource = load(path)
	if not (res is TileSet):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "Resource at %s is not a TileSet" % path}
	return res


static func configure_tileset_atlas(params: Dictionary, ei: EditorInterface) -> Variant:
	var tileset := _load_tileset(params)
	if tileset is Dictionary:
		return tileset
	var source_index: int = int(params.get("source_index", 0))
	if source_index >= tileset.get_source_count():
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "No source at index %d" % source_index}
	var source_id: int = tileset.get_source_id(source_index)
	var source: TileSetAtlasSource = tileset.get_source(source_id) as TileSetAtlasSource
	if source == null:
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "Source %d is not an atlas source" % source_index}
	if params.has("texture_path"):
		var texture: Variant = load(String(params["texture_path"]))
		if texture is Texture2D:
			source.texture = texture
	if params.has("tile_size"):
		source.texture_region_size = _vec2i(params["tile_size"])
	if params.has("margins"):
		source.margins = _vec2i(params["margins"])
	if params.has("separation"):
		source.separation = _vec2i(params["separation"])
	ResourceSaver.save(tileset, params.get("tileset_path", ""))
	ei.get_resource_filesystem().scan()
	return {"tileset_path": params.get("tileset_path", ""), "configured": true}


static func configure_tileset_layers(params: Dictionary, ei: EditorInterface) -> Variant:
	var tileset := _load_tileset(params)
	if tileset is Dictionary:
		return tileset
	if params.has("physics_layers"):
		var count: int = int(params["physics_layers"])
		while tileset.get_physics_layers_count() < count:
			tileset.add_physics_layer()
	if params.has("navigation_layers"):
		var count: int = int(params["navigation_layers"])
		while tileset.get_navigation_layers_count() < count:
			tileset.add_navigation_layer()
	if params.has("custom_data_layers"):
		for layer_def in params["custom_data_layers"]:
			tileset.add_custom_data_layer()
			var idx: int = tileset.get_custom_data_layers_count() - 1
			tileset.set_custom_data_layer_name(idx, String(layer_def.get("name", "")))
	ResourceSaver.save(tileset, params.get("tileset_path", ""))
	ei.get_resource_filesystem().scan()
	return {"tileset_path": params.get("tileset_path", ""), "configured": true}


static func configure_tileset_terrains(params: Dictionary, ei: EditorInterface) -> Variant:
	var tileset := _load_tileset(params)
	if tileset is Dictionary:
		return tileset
	var set_idx: int = int(params.get("terrain_set_index", 0))
	while tileset.get_terrain_sets_count() <= set_idx:
		tileset.add_terrain_set()
	if params.has("terrain_set_mode"):
		tileset.set_terrain_set_mode(set_idx, int(params["terrain_set_mode"]))
	if params.has("terrains"):
		for terrain_def in params["terrains"]:
			tileset.add_terrain(set_idx)
			var t_idx: int = tileset.get_terrains_count(set_idx) - 1
			tileset.set_terrain_name(set_idx, t_idx, String(terrain_def.get("name", "")))
			if terrain_def.has("color"):
				tileset.set_terrain_color(set_idx, t_idx, Color(String(terrain_def["color"])))
	ResourceSaver.save(tileset, params.get("tileset_path", ""))
	ei.get_resource_filesystem().scan()
	return {"tileset_path": params.get("tileset_path", ""), "configured": true}


static func set_tileset_tile_data(params: Dictionary, ei: EditorInterface) -> Variant:
	var tileset := _load_tileset(params)
	if tileset is Dictionary:
		return tileset
	var source_index: int = int(params.get("source_index", 0))
	if source_index >= tileset.get_source_count():
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "No source at index %d" % source_index}
	var source_id: int = tileset.get_source_id(source_index)
	var source: TileSetAtlasSource = tileset.get_source(source_id) as TileSetAtlasSource
	if source == null:
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "Source %d is not an atlas source" % source_index}
	var coords := _vec2i(params.get("atlas_coords", {}))
	if not source.has_tile(coords):
		source.create_tile(coords)
	var tile_data: TileData = source.get_tile_data(coords, 0)
	if params.has("terrain_set"):
		tile_data.terrain_set = int(params["terrain_set"])
	if params.has("terrain"):
		tile_data.terrain = int(params["terrain"])
	if params.has("custom_data"):
		for key in params["custom_data"].keys():
			tile_data.set_custom_data(String(key), params["custom_data"][key])
	ResourceSaver.save(tileset, params.get("tileset_path", ""))
	ei.get_resource_filesystem().scan()
	return {"tileset_path": params.get("tileset_path", ""), "atlas_coords": _vec2i_to_dict(coords)}
