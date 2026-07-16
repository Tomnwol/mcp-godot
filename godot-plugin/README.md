# Godot MCP — Editor Plugin

WebSocket bridge inside the Godot editor (Godot 4.5+ recommended; Logger
capture needs 4.5+). Uses `TCPServer` + `WebSocketPeer`.

## Installation

1. Copy `addons/godot-mcp/` into your Godot project's `addons/` folder.
2. Open the project in Godot 4.x.
3. **Project → Project Settings → Plugins** → enable **Godot MCP**.
4. Output panel should show:

   ```
   godot-mcp: listening on ws://127.0.0.1:6505
   ```

## Verify

```bash
npm run build && npm run inspector
# Call godot_editor_ping
```

## WebSocket protocol

**Version:** `2` (breaking vs v1: compact ping, tree defaults, new methods)

**Transport:** JSON over `ws://127.0.0.1:6505` (one request per connection).

### Envelope

Request: `{ "id", "method", "params?" }`  
Success: `{ "id", "result" }`  
Error: `{ "id", "error": { "code", "message" } }`

### Error codes

| Code | Meaning |
|------|---------|
| `-32700` | Parse error |
| `-32600` | Invalid request |
| `-32601` | Method not found |
| `-32602` | Invalid / missing params |
| `-32001` | Node not found |
| `-32002` | Property not found |
| `-32003` | Save failed |
| `-32004` | Script I/O failed |

## Methods

### `ping`

```json
{ "pong": true, "protocol_version": "2", "godot_version": "4.7.0", "editor": true }
```

### `get_editor_state`

No params. Returns `scene_path`, `root`, `selected[]`, `playing`, `main_screen`.

### `get_scene_tree`

| Param | Default | Notes |
|-------|---------|-------|
| `max_depth` | `2` | `-1` = unlimited (avoid) |
| `limit` | `80` | Max nodes |
| `format` | `outline` | `outline` \| `json` |

Outline example line: `  Player (CharacterBody2D) [Player]`

### `search_nodes`

| Param | Notes |
|-------|-------|
| `query` | Name substring (optional if `type` set) |
| `type` | Class filter (optional if `query` set) |
| `limit` | Default `20` |

Returns `{ matches: [{name,type,path}], total, truncated }`.

### `list_node_properties`

| Param | Default |
|-------|---------|
| `path` | required |
| `relevant_only` / `editable_only` | `true` |
| `exported_only` / `include_values` | `false` |
| `name_contains` | optional |
| `detail` | `summary` (`name` \| `summary` \| `full`) |
| `limit` | `60` |

### `get_node_property` / `set_node_property`

Same as v1: `{ path, property }` / `{ path, property, value }` → `{ path, property, value }`.

### `create_node`

`{ parent, type, name? }` → `{ path, type, name, parent }`

### `delete_node`

`{ path }` → `{ deleted }` (not scene root)

### `instantiate_scene`

`{ parent, scene_path, name? }` → instance summary

### `save_scene`

→ `{ saved, scene_path }`

### `get_script`

`{ path? \| script_path?, offset?=1, limit?=80 }` → paginated `{ content, total_lines, truncated }`

### `set_script`

`{ script_path, content, attach_to? }` → `{ saved, bytes, lines }` (no content echo)

### `run_project` / `stop_project`

`{ mode?: "main"\|"current" }` / no params

### `get_output_log`

`{ tail?=40, level?: "all"\|"error"\|"warning"\|"info" }` — ring buffer via `Logger`

## Value serialization

| Godot | JSON |
|-------|------|
| bool/int/float/string | as-is |
| Vector2/3 | `{x,y}` / `{x,y,z}` |
| Color | `{r,g,b,a}` |
| Node in scene | `{type:"Node", path:"..."}` |

## MCP tool names

Bridge method names are unprefixed; the Node MCP server exposes namespaced
tools (`godot_scene_get_tree` → method `get_scene_tree`, etc.).
