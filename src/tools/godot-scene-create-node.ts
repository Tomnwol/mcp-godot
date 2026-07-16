import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { runGodotTool } from "../godot/run-godot-tool.js";
import type { CreateNodeResult } from "../godot/protocol.js";
import { nodePathSchema, portSchema, writeAnnotations } from "./schemas.js";

export function registerGodotSceneCreateNodeTool(server: McpServer): void {
  server.registerTool(
    "godot_scene_create_node",
    {
      title: "Create node",
      description:
        "Add a child node under a parent (ClassDB type + optional name). Returns {path,type,name,parent} only. " +
        "Do NOT use for packing an existing .tscn — use godot_scene_instantiate. " +
        "Remember godot_scene_save after edits. Response ~40 tokens.",
      inputSchema: {
        parent: nodePathSchema.describe("Parent node path (scene root name for root)."),
        type: z
          .string()
          .min(1)
          .describe('Godot Node class (e.g. "Label", "Node2D", "Timer")'),
        name: z
          .string()
          .optional()
          .describe("Optional node name (defaults to type)."),
        port: portSchema,
      },
      annotations: writeAnnotations,
    },
    async ({ parent, type, name, port }) =>
      runGodotTool<CreateNodeResult>(port, "create_node", {
        parent,
        type,
        name,
      })
  );
}
