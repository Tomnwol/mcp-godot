import { z } from "zod";
import { runGodotTool } from "../godot/run-godot-tool.js";
import type { SceneTreeResult } from "../godot/protocol.js";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { portSchema } from "./schemas.js";

const inputSchema = {
  max_depth: z
    .number()
    .int()
    .min(-1)
    .optional()
    .describe(
      "Maximum depth to traverse (-1 for unlimited, 0 for root only). Default: -1"
    ),
  port: portSchema,
};

export function registerGetSceneTreeTool(server: McpServer): void {
  server.registerTool(
    "get_scene_tree",
    {
      title: "Get Scene Tree",
      description:
        "Read the hierarchy of the scene currently open in the Godot editor.",
      inputSchema,
    },
    async ({ max_depth, port }) => {
      const params =
        max_depth !== undefined ? { max_depth } : undefined;
      return runGodotTool<SceneTreeResult>(port, "get_scene_tree", params);
    }
  );
}
