import { z } from "zod";
import { runGodotTool } from "../godot/run-godot-tool.js";
import type { NodePropertyResult } from "../godot/protocol.js";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { nodePathSchema, portSchema } from "./schemas.js";

const inputSchema = {
  path: nodePathSchema,
  property: z
    .string()
    .min(1)
    .describe('Property name to read (e.g. "position", "text", "visible")'),
  port: portSchema,
};

export function registerGetNodePropertyTool(server: McpServer): void {
  server.registerTool(
    "get_node_property",
    {
      title: "Get Node Property",
      description:
        "Read a property value from a node in the scene currently open in the Godot editor.",
      inputSchema,
    },
    async ({ path, property, port }) =>
      runGodotTool<NodePropertyResult>(port, "get_node_property", {
        path,
        property,
      })
  );
}
