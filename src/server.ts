#!/usr/bin/env node
/**
 * Godot MCP server — bridges AI assistants to the Godot editor.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { serverInfo } from "./config.js";
import { registerPingGodotTool } from "./tools/ping-godot.js";
import { registerGetSceneTreeTool } from "./tools/get-scene-tree.js";
import { registerGetNodePropertyTool } from "./tools/get-node-property.js";
import { registerSetNodePropertyTool } from "./tools/set-node-property.js";
import { registerListNodePropertiesTool } from "./tools/list-node-properties.js";

const server = new McpServer(serverInfo);

registerPingGodotTool(server);
registerGetSceneTreeTool(server);
registerGetNodePropertyTool(server);
registerSetNodePropertyTool(server);
registerListNodePropertiesTool(server);

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error(`${serverInfo.name} v${serverInfo.version} started on stdio`);
}

main().catch((error) => {
  console.error("Fatal MCP server error:", error);
  process.exit(1);
});
