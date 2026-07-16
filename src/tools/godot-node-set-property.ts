import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { runGodotTool } from "../godot/run-godot-tool.js";
import type { NodePropertyResult } from "../godot/protocol.js";
import {
  jsonValueSchema,
  nodePathSchema,
  portSchema,
  writeAnnotations,
} from "./schemas.js";

export function registerGodotNodeSetPropertyTool(server: McpServer): void {
  server.registerTool(
    "godot_node_set_property",
    {
      title: "Set node property",
      description:
        "Write one property on a node in the open scene (editor memory; call godot_scene_save to persist). " +
        'Vectors/colors: {"x":1,"y":2} or {"r":1,"g":0,"b":0,"a":1}. ' +
        "Do NOT invent property names — list first if unsure. Not for creating/deleting nodes. Response ~50–150 tokens.",
      inputSchema: {
        path: nodePathSchema,
        property: z
          .string()
          .min(1)
          .describe('Property name (e.g. "position", "text", "visible")'),
        value: jsonValueSchema.describe("New JSON value matching the property type."),
        port: portSchema,
      },
      annotations: writeAnnotations,
    },
    async ({ path, property, value, port }) =>
      runGodotTool<NodePropertyResult>(port, "set_node_property", {
        path,
        property,
        value,
      })
  );
}
