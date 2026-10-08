@tool
extends EditorPlugin

const BridgeServer = preload("res://addons/godot_mcp_bridge/bridge_server.gd")

const RUNTIME_PROBE_AUTOLOAD_NAME := "GodotMCPRuntimeProbe"
const RUNTIME_PROBE_PATH := "res://addons/godot_mcp_bridge/runtime/mcp_runtime_probe.gd"

var _bridge: Node


func _enter_tree() -> void:
	_bridge = BridgeServer.new()
	_bridge.name = "GodotMCPBridgeServer"
	_bridge.editor_interface = get_editor_interface()
	add_child(_bridge)

	# Lets the running game connect back to the bridge's runtime channel for
	# game_* tool calls. Uses the same API the editor's own Project Settings >
	# Autoload UI uses, so it shows up there too (and is safely removed below
	# if the plugin is disabled).
	add_autoload_singleton(RUNTIME_PROBE_AUTOLOAD_NAME, RUNTIME_PROBE_PATH)


func _exit_tree() -> void:
	remove_autoload_singleton(RUNTIME_PROBE_AUTOLOAD_NAME)
	if is_instance_valid(_bridge):
		_bridge.queue_free()
		_bridge = null
