## Hosts two WebSocket servers (see protocol/MESSAGES.md):
##   - the editor channel (port 8765): the Python MCP server connects here,
##     handles every tool category except runtime monitoring.
##   - the runtime channel (port 8766): the mcp_runtime_probe.gd autoload,
##     running inside the *playing game*, connects here. game_* tool calls
##     arriving on the editor channel are relayed verbatim to this connection
##     and its response relayed straight back — this node never parses their
##     payloads, since the request/response `id` already matches on the
##     Python side without any extra correlation bookkeeping here.
## Runs as a child node of the EditorPlugin, so it lives for as long as the
## plugin is enabled and the project is open.
extends Node

const JsonRpc = preload("res://addons/godot_mcp_bridge/utils/json_rpc.gd")
const ProjectManagementHandlers = preload("res://addons/godot_mcp_bridge/handlers/project_management.gd")
const FileOperationsHandlers = preload("res://addons/godot_mcp_bridge/handlers/file_operations.gd")
const EditorInteractionHandlers = preload("res://addons/godot_mcp_bridge/handlers/editor_interaction.gd")
const SceneAnalysisHandlers = preload("res://addons/godot_mcp_bridge/handlers/scene_analysis.gd")
const ProjectStatisticsHandlers = preload("res://addons/godot_mcp_bridge/handlers/project_statistics.gd")
const ScriptManagementHandlers = preload("res://addons/godot_mcp_bridge/handlers/script_management.gd")
const SignalsGroupsHandlers = preload("res://addons/godot_mcp_bridge/handlers/signals_groups.gd")
const SceneConstructionHandlers = preload("res://addons/godot_mcp_bridge/handlers/scene_construction.gd")
const AssetManagementHandlers = preload("res://addons/godot_mcp_bridge/handlers/asset_management.gd")
const ResourceAuthoringHandlers = preload("res://addons/godot_mcp_bridge/handlers/resource_authoring.gd")
const ExecutionTestingHandlers = preload("res://addons/godot_mcp_bridge/handlers/execution_testing.gd")
const InputSetupHandlers = preload("res://addons/godot_mcp_bridge/handlers/input_setup.gd")
const NodeCompositionHandlers = preload("res://addons/godot_mcp_bridge/handlers/node_composition.gd")
const AudioConfigurationHandlers = preload("res://addons/godot_mcp_bridge/handlers/audio_configuration.gd")
const ThemingHandlers = preload("res://addons/godot_mcp_bridge/handlers/theming.gd")
const ShaderAuthoringHandlers = preload("res://addons/godot_mcp_bridge/handlers/shader_authoring.gd")
const Scene2DHandlers = preload("res://addons/godot_mcp_bridge/handlers/scene_2d.gd")
const UiLayoutHandlers = preload("res://addons/godot_mcp_bridge/handlers/ui_layout.gd")
const PhysicsConfigurationHandlers = preload("res://addons/godot_mcp_bridge/handlers/physics_configuration.gd")
const NavigationSystemsHandlers = preload("res://addons/godot_mcp_bridge/handlers/navigation_systems.gd")
const ParticleEffectsHandlers = preload("res://addons/godot_mcp_bridge/handlers/particle_effects.gd")
const AnimationSystemsHandlers = preload("res://addons/godot_mcp_bridge/handlers/animation_systems.gd")
const TilemapEditingHandlers = preload("res://addons/godot_mcp_bridge/handlers/tilemap_editing.gd")
const Scene3DHandlers = preload("res://addons/godot_mcp_bridge/handlers/scene_3d.gd")
const ProjectConfigurationHandlers = preload("res://addons/godot_mcp_bridge/handlers/project_configuration.gd")
const PluginManagementHandlers = preload("res://addons/godot_mcp_bridge/handlers/plugin_management.gd")
const ApiReferenceHandlers = preload("res://addons/godot_mcp_bridge/handlers/api_reference.gd")
const AdvancedScriptingHandlers = preload("res://addons/godot_mcp_bridge/handlers/advanced_scripting.gd")
const BuildExportHandlers = preload("res://addons/godot_mcp_bridge/handlers/build_export.gd")
const MultiplayerSetupHandlers = preload("res://addons/godot_mcp_bridge/handlers/multiplayer_setup.gd")
const ProjectHealthHandlers = preload("res://addons/godot_mcp_bridge/handlers/project_health.gd")
const WorldDesignHandlers = preload("res://addons/godot_mcp_bridge/handlers/world_design.gd")
const GameTemplatesHandlers = preload("res://addons/godot_mcp_bridge/handlers/game_templates.gd")
const RiggingHandlers = preload("res://addons/godot_mcp_bridge/handlers/rigging.gd")
const ImageStudioHandlers = preload("res://addons/godot_mcp_bridge/handlers/image_studio.gd")

const EDITOR_CHANNEL_PORT := 8765
const RUNTIME_CHANNEL_PORT := 8766
const GAME_TOOL_PREFIX := "game_"
## Godot's WebSocketPeer default (64KB) is too small for a base64-encoded
## screenshot or GIF frame sequence; large enough for those without being
## wasteful per-connection.
const LARGE_BUFFER_SIZE := 16 * 1024 * 1024

var editor_interface: EditorInterface

var _tcp_server := TCPServer.new()
var _peer: WebSocketPeer = null
var _dispatch: Dictionary = {}

var _runtime_tcp_server := TCPServer.new()
var _runtime_peer: WebSocketPeer = null


func _ready() -> void:
	_register_handlers()

	var err := _tcp_server.listen(EDITOR_CHANNEL_PORT, "127.0.0.1")
	if err != OK:
		push_error("GodotMCP: failed to listen on 127.0.0.1:%d (err %d)" % [EDITOR_CHANNEL_PORT, err])
		return
	print("GodotMCP: editor bridge listening on ws://127.0.0.1:%d" % EDITOR_CHANNEL_PORT)

	var runtime_err := _runtime_tcp_server.listen(RUNTIME_CHANNEL_PORT, "127.0.0.1")
	if runtime_err != OK:
		push_error("GodotMCP: failed to listen on 127.0.0.1:%d (err %d)" % [RUNTIME_CHANNEL_PORT, runtime_err])
		return
	print("GodotMCP: runtime bridge listening on ws://127.0.0.1:%d" % RUNTIME_CHANNEL_PORT)


func _register_handlers() -> void:
	ProjectManagementHandlers.register(_dispatch)
	FileOperationsHandlers.register(_dispatch)
	EditorInteractionHandlers.register(_dispatch)
	SceneAnalysisHandlers.register(_dispatch)
	ProjectStatisticsHandlers.register(_dispatch)
	ScriptManagementHandlers.register(_dispatch)
	SignalsGroupsHandlers.register(_dispatch)
	SceneConstructionHandlers.register(_dispatch)
	AssetManagementHandlers.register(_dispatch)
	ResourceAuthoringHandlers.register(_dispatch)
	ExecutionTestingHandlers.register(_dispatch)
	InputSetupHandlers.register(_dispatch)
	NodeCompositionHandlers.register(_dispatch)
	AudioConfigurationHandlers.register(_dispatch)
	ThemingHandlers.register(_dispatch)
	ShaderAuthoringHandlers.register(_dispatch)
	Scene2DHandlers.register(_dispatch)
	UiLayoutHandlers.register(_dispatch)
	PhysicsConfigurationHandlers.register(_dispatch)
	NavigationSystemsHandlers.register(_dispatch)
	ParticleEffectsHandlers.register(_dispatch)
	AnimationSystemsHandlers.register(_dispatch)
	TilemapEditingHandlers.register(_dispatch)
	Scene3DHandlers.register(_dispatch)
	ProjectConfigurationHandlers.register(_dispatch)
	PluginManagementHandlers.register(_dispatch)
	ApiReferenceHandlers.register(_dispatch)
	AdvancedScriptingHandlers.register(_dispatch)
	BuildExportHandlers.register(_dispatch)
	MultiplayerSetupHandlers.register(_dispatch)
	ProjectHealthHandlers.register(_dispatch)
	WorldDesignHandlers.register(_dispatch)
	GameTemplatesHandlers.register(_dispatch)
	RiggingHandlers.register(_dispatch)
	ImageStudioHandlers.register(_dispatch)


func _process(_delta: float) -> void:
	_accept_pending_connection()
	_accept_pending_runtime_connection()

	if _peer != null:
		_peer.poll()
		var state := _peer.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			while _peer.get_available_packet_count() > 0:
				_handle_frame(_peer.get_packet().get_string_from_utf8())
		elif state == WebSocketPeer.STATE_CLOSED:
			_peer = null

	if _runtime_peer != null:
		_runtime_peer.poll()
		var rstate := _runtime_peer.get_ready_state()
		if rstate == WebSocketPeer.STATE_OPEN:
			# Runtime responses are relayed straight back to the editor
			# channel client verbatim — see the class-level doc comment.
			while _runtime_peer.get_available_packet_count() > 0:
				_send(_runtime_peer.get_packet().get_string_from_utf8())
		elif rstate == WebSocketPeer.STATE_CLOSED:
			_runtime_peer = null


func _accept_pending_connection() -> void:
	if not _tcp_server.is_connection_available():
		return
	var connection := _tcp_server.take_connection()
	if _peer != null:
		# Only one editor-channel client at a time; replace the old one.
		_peer.close()
	_peer = WebSocketPeer.new()
	# Default buffer sizes (64KB) are too small for a base64-encoded
	# screenshot or a GIF frame sequence — sending one raises
	# ERR_OUT_OF_MEMORY inside wslay and the caller sees a silent TIMEOUT
	# instead of an error. Must be set before accept_stream()/connect_to_url().
	_peer.inbound_buffer_size = LARGE_BUFFER_SIZE
	_peer.outbound_buffer_size = LARGE_BUFFER_SIZE
	_peer.accept_stream(connection)


func _accept_pending_runtime_connection() -> void:
	if not _runtime_tcp_server.is_connection_available():
		return
	var connection := _runtime_tcp_server.take_connection()
	if _runtime_peer != null:
		# Only one running game at a time; replace the old one (e.g. after a
		# scene reload restarted the probe's connection).
		_runtime_peer.close()
	_runtime_peer = WebSocketPeer.new()
	_runtime_peer.inbound_buffer_size = LARGE_BUFFER_SIZE
	_runtime_peer.outbound_buffer_size = LARGE_BUFFER_SIZE
	_runtime_peer.accept_stream(connection)


func _handle_frame(raw: String) -> void:
	var request := JsonRpc.decode_request(raw)
	if request.is_empty():
		push_warning("GodotMCP: dropped malformed frame: %s" % raw)
		return

	var tool: String = request["tool"]
	if tool.begins_with(GAME_TOOL_PREFIX):
		_relay_to_runtime(request["id"], raw)
		return

	var id: String = request["id"]
	var params: Dictionary = request["params"]

	if not _dispatch.has(tool):
		_send(JsonRpc.encode_error(id, "TOOL_NOT_IMPLEMENTED", "No handler bound for tool '%s'" % tool))
		return

	var handler: Callable = _dispatch[tool]
	# await on a non-Signal, non-coroutine value is a documented no-op pass-
	# through in GDScript, so this is safe for the vast majority of handlers
	# that return synchronously — it only actually suspends for the rare
	# handler (e.g. open_scene) that awaits internally to let the editor
	# settle before replying.
	var result: Variant = await handler.call(params, editor_interface)

	if typeof(result) == TYPE_DICTIONARY and result.has("__error_code__"):
		_send(JsonRpc.encode_error(id, result["__error_code__"], result["__error_message__"]))
	else:
		_send(JsonRpc.encode_success(id, result))


func _relay_to_runtime(request_id: String, raw: String) -> void:
	if _runtime_peer == null or _runtime_peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
		_send(JsonRpc.encode_error(request_id, "NO_GAME_RUNNING", "No running game is connected to the runtime channel"))
		return
	_runtime_peer.send_text(raw)


func _send(payload: String) -> void:
	if _peer != null and _peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_peer.send_text(payload)


func _exit_tree() -> void:
	if _peer != null:
		_peer.close()
	if _runtime_peer != null:
		_runtime_peer.close()
	_tcp_server.stop()
	_runtime_tcp_server.stop()
