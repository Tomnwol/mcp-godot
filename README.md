# Godot MCP Server

MCP (Model Context Protocol) server that connects AI assistants to the Godot
editor and runtime. Built with the official
[`@modelcontextprotocol/sdk`](https://github.com/modelcontextprotocol/typescript-sdk).

**Status: early development.** The server boots and exposes a `hello` tool to
verify the MCP pipeline end-to-end. Godot-facing tools (scene tree, node
properties, editor control, etc.) are planned next.

## Architecture

```
┌─────────────┐   stdio (JSON-RPC)   ┌──────────────────┐   TBD    ┌─────────────┐
│   Cursor    │ ◄──────────────────► │   godot-mcp      │ ◄──────► │ Godot plugin│
│  (client)   │                      │  (this project)  │          │  (planned)  │
└─────────────┘                      └──────────────────┘          └─────────────┘
```

The MCP server will eventually talk to Godot via a local channel (WebSocket,
TCP, or HTTP API) exposed by a GDScript plugin in the editor.

## Why TypeScript?

- Official MCP SDK, fully typed (tool schemas validated with `zod`).
- npm ecosystem: easy to add WebSocket/TCP/HTTP clients for Godot later.
- Compiles to standard JS (`build/`), runnable anywhere Node is available.

## Project metadata

Server identity is defined once in `package.json`:

```json
{
  "version": "0.1.1",
  "description": "MCP bridge to the Godot editor",
  "mcp": {
    "name": "godot-mcp",
    "title": "Godot MCP"
  }
}
```

`src/config.ts` reads these fields at startup and passes them to the MCP
client via `initialize → serverInfo`. The key in `.cursor/mcp.json` must match
`mcp.name`.

## Installation

```bash
cd mcp-godot
npm install
npm run build
```

This produces `build/server.js`, the entry point used by MCP clients.

## Local testing (without Cursor)

Use the MCP Inspector to call tools from the browser:

```bash
npm run inspector
```

Or send raw JSON-RPC over stdio:

```bash
node build/server.js
# paste JSON-RPC lines on stdin, e.g.:
# {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"0.0.1"}}}
```

## Cursor integration

Project config is already at `.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "godot-mcp": {
      "command": "node",
      "args": ["/absolute/path/to/mcp-godot/build/server.js"]
    }
  }
}
```

Replace `/absolute/path/to/` with the real path on your machine.

After changing server code:

```bash
npm run build
```

Then **toggle the MCP server off and on** in `Settings → Tools & MCP`.
Reload Window alone does not restart the Node process — the old code stays in
memory until the process is killed.

During development:

```bash
npm run watch   # recompile on save, then toggle MCP off → on
```

## Claude Code integration

Add a `.mcp.json` at the project root (or use global config):

```json
{
  "mcpServers": {
    "godot-mcp": {
      "command": "node",
      "args": ["build/server.js"]
    }
  }
}
```

From the project directory:

```bash
claude
> /mcp
```

Or register globally:

```bash
claude mcp add godot-mcp -- node /absolute/path/to/mcp-godot/build/server.js
```

## Roadmap

- [ ] Godot editor plugin (WebSocket or HTTP bridge)
- [ ] `get_scene_tree` — read the current scene hierarchy
- [ ] `get_node_property` / `set_node_property` — inspect and modify nodes
- [ ] `run_scene` — launch a scene from the editor
- [ ] Proper error handling when Godot is not running (`isError: true`)
- [ ] Typed `inputSchema` with `zod` for every tool

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Old tool output after `npm run build` | Toggle MCP off → on in Cursor settings |
| Server shows red / error | `Output → MCP Logs`, check for startup errors |
| `hello` tool not visible | Ensure `godot-mcp` is enabled in Tools & MCP |
