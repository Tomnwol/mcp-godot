import { z } from "zod";
import { GodotClient } from "../godot/client.js";
import type { SceneTreeResult } from "../godot/protocol.js";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";

const inputSchema = {
  max_depth: z
    .number()
    .int()
    .min(-1)
    .optional()
    .describe(
      "Maximum depth to traverse (-1 for unlimited, 0 for root only). Default: -1"
    ),
  port: z
    .number()
    .int()
    .min(1)
    .max(65535)
    .optional()
    .describe("Override the Godot plugin WebSocket port (default 6505)"),
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
      try {
        const client = new GodotClient(port !== undefined ? { port } : {});
        const params =
          max_depth !== undefined ? { max_depth } : undefined;
        const result = await client.call<SceneTreeResult>(
          "get_scene_tree",
          params
        );

        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(result, null, 2),
            },
          ],
        };
      } catch (error) {
        const message =
          error instanceof Error ? error.message : "Unknown error reaching Godot";

        return {
          content: [{ type: "text", text: message }],
          isError: true,
        };
      }
    }
  );
}
