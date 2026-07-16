import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { runGodotTool } from "../godot/run-godot-tool.js";
import type { NodePropertyResult } from "../godot/protocol.js";
import {
  nodePathSchema,
  portSchema,
  readOnlyAnnotations,
} from "./schemas.js";

export function registerGodotNodeGetPropertyTool(server: McpServer): void {
  server.registerTool(
    "godot_node_get_property",
    {
      title: "Get node property",
      description:
        "Read one property value from a node. Prefer after godot_node_list_properties or when the property name is known. " +
        "Do NOT use to dump many properties — call list then get selectively. Response ~50–150 tokens.",
      inputSchema: {
        path: nodePathSchema,
        property: z
          .string()
          .min(1)
          .describe('Property name (e.g. "position", "text", "visible")'),
        port: portSchema,
      },
      annotations: readOnlyAnnotations,
    },
    async ({ path, property, port }) =>
      runGodotTool<NodePropertyResult>(port, "get_node_property", {
        path,
        property,
      })
  );
}
