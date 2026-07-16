import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { runGodotTool } from "../godot/run-godot-tool.js";
import type { SceneTreeResult } from "../godot/protocol.js";
import { limitSchema, portSchema, readOnlyAnnotations } from "./schemas.js";

export function registerGodotSceneGetTreeTool(server: McpServer): void {
  server.registerTool(
    "godot_scene_get_tree",
    {
      title: "Get scene tree",
      description:
        "Read a shallow hierarchy of the open scene. Default: outline text, max_depth=2, limit=80 nodes. " +
        "Prefer godot_scene_search_nodes when looking for a named/type node (cheaper). " +
        "Do NOT use max_depth=-1 or format=json on large scenes unless necessary. " +
        "If truncated=true, search or increase depth carefully. Typical response ~200–800 tokens.",
      inputSchema: {
        max_depth: z
          .number()
          .int()
          .min(-1)
          .default(2)
          .describe(
            "Max depth (-1 unlimited, 0 root only). Default 2. Prefer search over deep dumps."
          ),
        limit: limitSchema(80, 500),
        format: z
          .enum(["outline", "json"])
          .default("outline")
          .describe(
            "outline = compact indented text (default); json = nested objects (heavier)."
          ),
        port: portSchema,
      },
      annotations: readOnlyAnnotations,
    },
    async ({ max_depth, limit, format, port }) =>
      runGodotTool<SceneTreeResult>(port, "get_scene_tree", {
        max_depth,
        limit,
        format,
      })
  );
}
