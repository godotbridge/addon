# GodotBridge — Godot Editor Plugin

The Godot 4.x editor addon for [GodotBridge](https://godotbridge.dev). This plugin creates a local WebSocket bridge that lets an MCP-speaking AI agent (Claude, Cursor, Windsurf, or any MCP client) inspect and control your Godot editor session and running game.

## Features

- **345 tools** across 36 categories — scene building, animation, shaders, physics, runtime game control, AI Image Studio, and more
- **Real-time bridge** — WebSocket connection between the editor and the MCP server
- **Runtime probe** — a second channel to the running game for live inspection, input simulation, screenshots, and debugging
- **Zero compilation** — pure GDScript, drop-in plugin

## Installation

### From Godot Asset Library (recommended)

1. Open your Godot project
2. Go to **AssetLib** tab
3. Search for **GodotBridge**
4. Click **Download** → **Install**
5. Enable the plugin: **Project → Project Settings → Plugins → GodotBridge → Enable**

### Manual installation

1. Download or clone this repository
2. Copy the `addons/godot_mcp_bridge` folder into your Godot project's `addons/` directory
3. Enable the plugin: **Project → Project Settings → Plugins → GodotBridge → Enable**

## Setup

This plugin is the editor-side half of GodotBridge. You also need the **MCP server** to connect your AI agent:

```bash
pip install godotbridge
```

Then register it with your AI client:

**Claude Code:**
```bash
claude mcp add godot-bridge -- godotbridge
```

**Claude Desktop / Cursor / Windsurf:**

Add to your MCP config:
```json
{
  "mcpServers": {
    "godot-bridge": {
      "command": "godotbridge"
    }
  }
}
```

For detailed setup instructions, visit [godotbridge.dev](https://godotbridge.dev).

## How it works

```
Your AI agent (Claude, Cursor, etc.)
        │
        │  MCP / stdio
        ▼
GodotBridge MCP Server (Python)
        │
        │  WebSocket · ws://127.0.0.1:8765
        ▼
This plugin (Godot editor)
        │
        │  WebSocket · ws://127.0.0.1:8766
        ▼
Your running game (runtime probe)
```

The editor plugin hosts the WebSocket server. The MCP server connects to it as a client — so the bridge survives your AI session ending and reconnects automatically.

## Requirements

- Godot 4.2 or later
- GodotBridge MCP server (Python 3.10+)

## License

MIT — see [LICENSE](LICENSE) for details.

## Links

- [Website](https://godotbridge.dev)
- [Documentation](https://godotbridge.dev/docs)
- [MCP Server (PyPI)](https://pypi.org/project/godotbridge/)
- [Report Issues](https://github.com/godotbridge/addon/issues)
