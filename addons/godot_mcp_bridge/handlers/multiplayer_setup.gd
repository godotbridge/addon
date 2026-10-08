## Handlers for the multiplayer_setup tool category.
class_name GodotMCPMultiplayerSetupHandlers
extends RefCounted

const NodeResolver = preload("res://addons/godot_mcp_bridge/utils/node_resolver.gd")


static func register(dispatch: Dictionary) -> void:
	dispatch["add_multiplayer_spawner"] = add_multiplayer_spawner
	dispatch["add_multiplayer_synchronizer"] = add_multiplayer_synchronizer
	dispatch["create_multiplayer_setup"] = create_multiplayer_setup


static func add_multiplayer_spawner(params: Dictionary, ei: EditorInterface) -> Variant:
	var parent := NodeResolver.resolve(params, ei, "parent_path")
	if parent is Dictionary:
		return parent
	var root: Node = ei.get_edited_scene_root()
	var node := NodeResolver.add_child_node(parent, root, "MultiplayerSpawner", params.get("node_name", ""))
	if node is Dictionary:
		return node

	if params.has("spawn_path"):
		node.spawn_path = NodePath(String(params["spawn_path"]))
	var spawnable_scenes: Array = params.get("spawnable_scenes", [])
	for scene_path in spawnable_scenes:
		node.add_spawnable_scene(String(scene_path))

	return {"node_path": NodeResolver.relative_path(root, node), "type": "MultiplayerSpawner"}


static func add_multiplayer_synchronizer(params: Dictionary, ei: EditorInterface) -> Variant:
	var parent := NodeResolver.resolve(params, ei, "parent_path")
	if parent is Dictionary:
		return parent
	var root: Node = ei.get_edited_scene_root()
	var node := NodeResolver.add_child_node(parent, root, "MultiplayerSynchronizer", params.get("node_name", ""))
	if node is Dictionary:
		return node

	if params.has("root_path"):
		node.root_path = NodePath(String(params["root_path"]))

	var replicated_properties: Array = params.get("replicated_properties", [])
	if not replicated_properties.is_empty():
		var config := SceneReplicationConfig.new()
		for prop_path in replicated_properties:
			config.add_property(NodePath(String(prop_path)))
		node.replication_config = config

	return {"node_path": NodeResolver.relative_path(root, node), "type": "MultiplayerSynchronizer"}


## Scaffolds a MultiplayerSpawner wired to spawn a player scene under
## parent_path — the common "spawn players as they connect" starting point,
## not a full networking stack (that also needs a NetworkedMultiplayerPeer
## the caller connects/hosts explicitly at runtime).
static func create_multiplayer_setup(params: Dictionary, ei: EditorInterface) -> Variant:
	var parent := NodeResolver.resolve(params, ei, "parent_path")
	if parent is Dictionary:
		return parent
	var root: Node = ei.get_edited_scene_root()

	var spawner := NodeResolver.add_child_node(parent, root, "MultiplayerSpawner", params.get("node_name", "PlayerSpawner"))
	if spawner is Dictionary:
		return spawner

	# spawn_path is a NodePath Godot resolves relative to the spawner itself
	# at runtime (not relative to the scene root) — get_path_to() computes
	# that correctly regardless of where in the tree the spawner ends up.
	spawner.spawn_path = spawner.get_path_to(parent)
	var player_scene_path: String = params.get("player_scene_path", "")
	if player_scene_path != "":
		if not FileAccess.file_exists(player_scene_path):
			return {"__error_code__": "SCENE_NOT_FOUND", "__error_message__": "No scene at %s" % player_scene_path}
		spawner.add_spawnable_scene(player_scene_path)

	return {
		"spawner_path": NodeResolver.relative_path(root, spawner),
		"spawn_path": str(spawner.spawn_path),
		"player_scene_path": player_scene_path,
	}
