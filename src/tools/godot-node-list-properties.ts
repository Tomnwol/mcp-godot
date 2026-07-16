import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { runGodotTool } from "../godot/run-godot-tool.js";
import type { NodePropertiesResult } from "../godot/protocol.js";
import {
  limitSchema,
  nodePathSchema,
  portSchema,
  readOnlyAnnotations,
} from "./schemas.js";

export function registerGodotNodeListPropertiesTool(server: McpServer): void {
  server.registerTool(
    "godot_node_list_properties",
    {
      title: "List node properties",
      description:
        "Discover properties on one node. Default: relevant+editable subset, detail=summary (name+type), no values, limit=60. " +
        "Use name_contains to filter (e.g. \"anchor\"). " +
        "Do NOT set include_values=true unless needed (token heavy). " +
        "Do NOT use detail=full unless debugging hints. Prefer this then godot_node_get_property for one value. Response ~150–600 tokens.",
      inputSchema: {
        path: nodePathSchema,
        exported_only: z
          .boolean()
          .default(false)
          .describe("If true, only @export script variables."),
        relevant_only: z
          .boolean()
          .default(true)
          .describe("AI-friendly subset (default true). Set false only if a property is missing."),
        editable_only: z
          .boolean()
          .default(true)
          .describe("Hide internal/read-only/group entries (default true)."),
        include_values: z
          .boolean()
          .default(false)
          .describe("Include current values (expensive). Prefer get_property for one value."),
        name_contains: z
          .string()
          .optional()
          .describe("Case-insensitive property name filter."),
        detail: z
          .enum(["name", "summary", "full"])
          .default("summary")
          .describe("name = strings only; summary = name+type (default); full = hints/usage."),
        limit: limitSchema(60, 300),
        port: portSchema,
      },
      annotations: readOnlyAnnotations,
    },
    async (args) =>
      runGodotTool<NodePropertiesResult>(args.port, "list_node_properties", {
        path: args.path,
        exported_only: args.exported_only,
        relevant_only: args.relevant_only,
        editable_only: args.editable_only,
        include_values: args.include_values,
        name_contains: args.name_contains,
        detail: args.detail,
        limit: args.limit,
      })
  );
}
