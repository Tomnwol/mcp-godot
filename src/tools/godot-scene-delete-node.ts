import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { runGodotTool } from "../godot/run-godot-tool.js";
import type { DeleteNodeResult } from "../godot/protocol.js";
import {
  destructiveAnnotations,
  nodePathSchema,
  portSchema,
} from "./schemas.js";

export function registerGodotSceneDeleteNodeTool(server: McpServer): void {
  server.registerTool(
    "godot_scene_delete_node",
    {
      title: "Delete node",
      description:
        "Delete a node (and its children) from the open scene. Cannot delete the scene root. Destructive. " +
        "Confirm the path via search first. Call godot_scene_save to persist. Response ~20 tokens.",
      inputSchema: {
        path: nodePathSchema,
        port: portSchema,
      },
      annotations: destructiveAnnotations,
    },
    async ({ path, port }) =>
      runGodotTool<DeleteNodeResult>(port, "delete_node", { path })
  );
}
