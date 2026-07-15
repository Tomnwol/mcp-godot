# Godot MCP — Editor Plugin

WebSocket bridge that runs inside the Godot editor (Godot 4.x). Uses
`TCPServer` + `WebSocketPeer` — no `WebSocketServer` required.

## Installation

1. Copy the `addons/godot-mcp/` folder into your Godot project's `addons/`
   directory:

   ```
   your-godot-project/
   └── addons/
       └── godot-mcp/    ← copy from this repo
   ```

2. Open the project in Godot 4.x.

3. Go to **Project → Project Settings → Plugins** and enable **Godot MCP**.

4. Check the Godot output panel — you should see:

   ```
   godot-mcp: listening on ws://127.0.0.1:6505
   ```

## Verify from the MCP server

With Godot running and the plugin enabled:

```bash
# In the mcp-godot repo
npm run build
npm run inspector
# Call the "ping_godot" tool
```

Or from Cursor: enable the `godot-mcp` MCP server and ask the assistant to
call `ping_godot`.

## Protocol

JSON over WebSocket, one request per connection (for now):

```json
// Request
{"id": "1", "method": "ping"}

// Response
{"id": "1", "result": {"pong": true, "godot_version": {...}, "editor": true}}

// Scene tree
{"id": "2", "method": "get_scene_tree", "params": {"max_depth": 2}}
```

Future methods (`get_scene_tree`, etc.) will use the same envelope.
