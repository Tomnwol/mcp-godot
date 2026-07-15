#!/usr/bin/env node
/**
 * Godot MCP server — bridges AI assistants to the Godot editor.
 *
 * Currently exposes a connectivity-check tool while the Godot plugin and
 * editor-facing tools are being built. Future tools will communicate with
 * Godot over a local WebSocket, TCP, or HTTP channel.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { serverInfo } from "./config.js";
import { registerPingGodotTool } from "./tools/ping-godot.js";
import { registerGetSceneTreeTool } from "./tools/get-scene-tree.js";

const server = new McpServer(serverInfo);

// Connectivity check — will be replaced by Godot editor tools
server.registerTool(
  "hello",
  {
    title: "Hello",
    description: "Verify the MCP server is running and reachable.",
    inputSchema: {},
  },
  async () => {
    return {
      content: [{ type: "text", text: "Hello World ! :0" }],
    };
  }
);

registerPingGodotTool(server);
registerGetSceneTreeTool(server);

async function main() {
  // stdio transport: Cursor and Claude Code spawn this as a local subprocess
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error(`${serverInfo.name} v${serverInfo.version} started on stdio`);
}

main().catch((error) => {
  console.error("Fatal MCP server error:", error);
  process.exit(1);
});
