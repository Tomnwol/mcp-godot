import { z } from "zod";
import { runGodotTool } from "../godot/run-godot-tool.js";
import type { NodePropertyResult } from "../godot/protocol.js";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { nodePathSchema, portSchema } from "./schemas.js";

const jsonValue = z.union([
  z.string(),
  z.number(),
  z.boolean(),
  z.null(),
  z.array(z.any()),
  z.record(z.string(), z.any()),
]);

const inputSchema = {
  path: nodePathSchema,
  property: z
    .string()
    .min(1)
    .describe('Property name to set (e.g. "position", "text", "visible")'),
  value: jsonValue.describe(
    'New property value as JSON. Vectors/colors use objects: {"x": 1, "y": 2} or {"r": 1, "g": 0, "b": 0, "a": 1}.'
  ),
  port: portSchema,
};

export function registerSetNodePropertyTool(server: McpServer): void {
  server.registerTool(
    "set_node_property",
    {
      title: "Set Node Property",
      description:
        "Set a property value on a node in the scene currently open in the Godot editor.",
      inputSchema,
    },
    async ({ path, property, value, port }) =>
      runGodotTool<NodePropertyResult>(port, "set_node_property", {
        path,
        property,
        value,
      })
  );
}
