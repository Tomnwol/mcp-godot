# Godot MCP Server

MCP server that connects AI assistants to the Godot editor. Built with the
official [`@modelcontextprotocol/sdk`](https://github.com/modelcontextprotocol/typescript-sdk).

**Status: v0.2** — 16 namespaced tools, compact JSON responses, search-first
scene navigation, read/write annotations.

## Architecture

```
┌─────────────┐   stdio (JSON-RPC)   ┌──────────────────┐  WebSocket  ┌─────────────┐
│   Cursor    │ ◄──────────────────► │   godot-mcp      │ ◄─────────► │ Godot plugin│
│  (client)   │                      │  (this project)  │  :6505      │ godot-plugin│
└─────────────┘                      └──────────────────┘             └─────────────┘
```

## Design principles (low token usage)

- **Namespaced tools** (`godot_editor_*`, `godot_scene_*`, `godot_node_*`, …)
- **Search before dump** — `godot_scene_search_nodes` over full trees
- **Shallow defaults** — tree depth 2, outline format, property limits
- **Compact JSON** — no pretty-print; paginated scripts/logs
- **When-NOT-to-use** hints in every tool description
- **Annotations** — `readOnlyHint` / `destructiveHint` for client gating

Recommended discovery order:

`godot_editor_get_state` → `godot_scene_search_nodes` → `godot_node_list_properties` → get/set → `godot_scene_save`

## Tools (16)

| Namespace | Tools |
|-----------|-------|
| `godot_editor_*` | `ping`, `get_state`, `run_project`, `stop_project` |
| `godot_scene_*` | `get_tree`, `search_nodes`, `create_node`, `delete_node`, `instantiate`, `save` |
| `godot_node_*` | `list_properties`, `get_property`, `set_property` |
| `godot_script_*` | `get`, `set` |
| `godot_log_*` | `get` |

Full roadmap / anti-patterns: **[docs/tools-roadmap.md](docs/tools-roadmap.md)**.

## Godot plugin setup

Copy `godot-plugin/addons/godot-mcp/` into your project's `addons/` folder, then
enable **Godot MCP** in **Project → Project Settings → Plugins**.

See [`godot-plugin/README.md`](godot-plugin/README.md) for the WebSocket protocol
(v2).

When active:

```
godot-mcp: listening on ws://127.0.0.1:6505
```

## Installation

```bash
cd mcp-godot
npm install
npm run build
```

Produces `build/server.js`.

## Local testing

```bash
npm run inspector
```

## Cursor integration

`.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "godot-mcp": {
      "command": "node",
      "args": ["c:/Users/Tom/tmp/mcp-godot/build/server.js"]
    }
  }
}
```

After changing server code: `npm run build`, then **toggle the MCP server off/on**
in Settings → Tools & MCP (reload alone does not restart the process).

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GODOT_MCP_HOST` | `127.0.0.1` | Godot plugin host |
| `GODOT_MCP_PORT` | `6505` | Godot plugin WebSocket port |
| `GODOT_MCP_TIMEOUT_MS` | `3000` | Connection timeout (ms) |

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Old tool names / output after build | Toggle MCP off → on |
| Server red / error | `Output → MCP Logs` |
| `godot_editor_ping` ECONNREFUSED | Godot open + plugin enabled |
| Protocol mismatch | Plugin protocol v2 required (re-copy addons) |
