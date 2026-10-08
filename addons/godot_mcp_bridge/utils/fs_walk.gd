## Shared recursive file-listing helper used by any handler that needs to
## enumerate project files (optionally filtered by extension).
class_name GodotMCPFsWalk
extends RefCounted

const IGNORED_DIRS := [".godot", ".import", ".git"]


## Recursively lists files under dir_path. If extensions is non-empty, only
## files whose extension matches one of them are included (case-sensitive,
## no leading dot — e.g. "tscn", "gd").
static func list_files(dir_path: String, extensions: PackedStringArray = PackedStringArray()) -> Array:
	var out: Array = []
	_walk(dir_path, extensions, out)
	return out


static func _walk(dir_path: String, extensions: PackedStringArray, out: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry in IGNORED_DIRS:
			entry = dir.get_next()
			continue
		var full_path: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			_walk(full_path, extensions, out)
		elif extensions.is_empty() or extensions.has(entry.get_extension()):
			out.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()
