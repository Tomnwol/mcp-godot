import { z } from "zod";
import { runGodotTool } from "../godot/run-godot-tool.js";
import type { NodePropertiesResult } from "../godot/protocol.js";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { nodePathSchema, portSchema } from "./schemas.js";

const inputSchema = {
  path: nodePathSchema,
  exported_only: z
    .boolean()
    .default(false)
    .describe("If true, only @export script variables."),
  relevant_only: z
    .boolean()
    .default(true)
    .describe(
      "If true, keep script variables plus common editor/layout properties and hide accessibility, focus chains, process settings, and computed runtime fields."
    ),
  editable_only: z
    .boolean()
    .default(true)
    .describe(
      "If true, hide internal, read-only, and inspector group/category entries."
    ),
  include_values: z
    .boolean()
    .default(false)
    .describe("If true, include the current value of each property."),
  port: portSchema,
};

export function registerListNodePropertiesTool(server: McpServer): void {
  server.registerTool(
    "list_node_properties",
    {
      title: "List Node Properties",
      description:
        "List properties available on a node in the scene currently open in the Godot editor. By default returns a compact, AI-friendly subset. Use relevant_only: false for the full editable property list.",
      inputSchema,
    },
    async ({
      path,
      exported_only,
      relevant_only,
      editable_only,
      include_values,
      port,
    }) =>
      runGodotTool<NodePropertiesResult>(port, "list_node_properties", {
        path,
        exported_only,
        relevant_only,
        editable_only,
        include_values,
      })
  );
}
