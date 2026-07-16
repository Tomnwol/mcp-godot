import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { runGodotTool } from "../godot/run-godot-tool.js";
import type { InstantiateSceneResult } from "../godot/protocol.js";
import { nodePathSchema, portSchema, writeAnnotations } from "./schemas.js";

export function registerGodotSceneInstantiateTool(server: McpServer): void {
  server.registerTool(
    "godot_scene_instantiate",
    {
      title: "Instantiate packed scene",
      description:
        "Instance a PackedScene (.tscn) under a parent. Prefer this over manually recreating prefab hierarchies. " +
        "Do NOT use for empty typed nodes — use godot_scene_create_node. Response ~50 tokens.",
      inputSchema: {
        parent: nodePathSchema.describe("Parent node path."),
        scene_path: z
          .string()
          .min(1)
          .describe('res:// path to PackedScene (e.g. "res://enemies/slime.tscn")'),
        name: z.string().optional().describe("Optional instance name override."),
        port: portSchema,
      },
      annotations: writeAnnotations,
    },
    async ({ parent, scene_path, name, port }) =>
      runGodotTool<InstantiateSceneResult>(port, "instantiate_scene", {
        parent,
        scene_path,
        name,
      })
  );
}
