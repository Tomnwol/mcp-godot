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

## WebSocket protocol

**Version:** `1` (returned as `protocol_version` in `ping` responses)

**Transport:** JSON over WebSocket at `ws://127.0.0.1:6505` (one request per
connection for now).

### Request envelope

```json
{
  "id": "unique-request-id",
  "method": "method_name",
  "params": {}
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | yes | Correlates the response |
| `method` | string | yes | Method to invoke |
| `params` | object | no | Method-specific parameters |

### Success response

```json
{
  "id": "unique-request-id",
  "result": {}
}
```

### Error response

```json
{
  "id": "unique-request-id",
  "error": {
    "code": -32001,
    "message": "Human-readable error"
  }
}
```

### Error codes

| Code | Meaning |
|------|---------|
| `-32700` | Parse error (invalid JSON) |
| `-32600` | Invalid request (not an object) |
| `-32601` | Method not found |
| `-32602` | Missing required parameter |
| `-32001` | Node not found |
| `-32002` | Property not found on node |

## Methods

### `ping`

Health check and protocol handshake.

**Params:** none

**Result:**

```json
{
  "pong": true,
  "protocol_version": "1",
  "godot_version": { "major": 4, "minor": 4, "patch": 0 },
  "editor": true
}
```

### `get_scene_tree`

Returns the hierarchy of the scene currently open in the editor.

**Params:**

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `max_depth` | int | `-1` | Max depth (`-1` = unlimited, `0` = root only) |

**Result:**

```json
{
  "scene_path": "res://main.tscn",
  "root": {
    "name": "Main",
    "type": "Control",
    "path": "Main",
    "children": []
  }
}
```

When no scene is open, `root` is `null` and `message` explains why.

Node `path` values are relative to the edited scene root.

### `get_node_property`

Read a single property from a node in the edited scene.

**Params:**

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `path` | string | yes | Node path relative to scene root |
| `property` | string | yes | Property name (e.g. `position`, `text`) |

**Result:**

```json
{
  "path": "Player",
  "property": "position",
  "value": { "x": 100, "y": 200 }
}
```

**Value serialization:**

| Godot type | JSON |
|------------|------|
| bool, int, float, string | as-is |
| Vector2 / Vector3 | `{ "x", "y" }` / `{ "x", "y", "z" }` |
| Color | `{ "r", "g", "b", "a" }` |
| Array, Dictionary | recursive |
| NodePath | string |
| Node in scene | `{ "type": "Node", "path": "..." }` |
| Other Object | `{ "type": "ClassName", "hint": "non-serializable object reference" }` |

### `set_node_property`

Write a property on a node in the edited scene.

**Params:**

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `path` | string | yes | Node path relative to scene root |
| `property` | string | yes | Property name |
| `value` | any | yes | JSON value (same shapes as `get_node_property`) |

**Result:** same shape as `get_node_property` with the updated value.

### `list_node_properties`

List properties available on a node. Intended for discovery before
`get_node_property` / `set_node_property`.

**Params:**

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `path` | string | — | Node path relative to scene root |
| `exported_only` | bool | `false` | Only `@export` script variables |
| `relevant_only` | bool | `true` | Compact AI-friendly subset |
| `editable_only` | bool | `true` | Hide internal, read-only, inspector groups |
| `include_values` | bool | `false` | Include current value of each property |

**Result:**

```json
{
  "path": "Control",
  "type": "Control",
  "filters": {
    "exported_only": false,
    "editable_only": true,
    "relevant_only": true,
    "include_values": false
  },
  "properties": [
    {
      "name": "position",
      "type": "Vector2",
      "class_name": "",
      "hint": 0,
      "hint_string": "suffix:px",
      "usage": ["editor"]
    }
  ]
}
```

**Property entry fields:**

| Field | Description |
|-------|-------------|
| `name` | Property name for get/set calls |
| `type` | Variant type name (or resource class for objects) |
| `class_name` | Godot class for object references |
| `hint` | Godot `PropertyHint` enum (e.g. `2` = enum) |
| `hint_string` | Hint details (enum labels, ranges, etc.) |
| `usage` | Flags: `storage`, `editor`, `script`, … |
| `value` | Present when `include_values: true` |

**`relevant_only` filter:** keeps script variables and common editor/layout
properties; hides accessibility, focus chains, process settings, computed
runtime fields, and similar noise.

## Examples

```json
{"id": "1", "method": "ping"}

{"id": "2", "method": "get_scene_tree", "params": {"max_depth": 2}}

{"id": "3", "method": "list_node_properties", "params": {"path": "Control"}}

{"id": "4", "method": "get_node_property", "params": {"path": "Player", "property": "position"}}

{"id": "5", "method": "set_node_property", "params": {"path": "Player/Label", "property": "text", "value": "Hello"}}
```

## Protocol versioning

`protocol_version` is returned by `ping`. When breaking changes are introduced
to request/response shapes or method names, this string will be incremented.
Clients should verify compatibility on connect.
