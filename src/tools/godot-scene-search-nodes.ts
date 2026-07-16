import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { runGodotTool } from "../godot/run-godot-tool.js";
import type { SearchNodesResult } from "../godot/protocol.js";
import { limitSchema, portSchema, readOnlyAnnotations } from "./schemas.js";

export function registerGodotSceneSearchNodesTool(server: McpServer): void {
  server.registerTool(
    "godot_scene_search_nodes",
    {
      title: "Search scene nodes",
      description:
        "Find nodes by name substring and/or class type. Returns compact {path,type,name} matches (default limit 20). " +
        "Prefer this over godot_scene_get_tree for locating a node. " +
        "Provide query and/or type. Do NOT use to dump the whole scene — use a specific query. Response ~100–400 tokens.",
      inputSchema: {
        query: z
          .string()
          .optional()
          .describe("Case-insensitive name substring (e.g. \"player\", \"Label\")"),
        type: z
          .string()
          .optional()
          .describe('Godot class filter (e.g. "Label", "CharacterBody2D")'),
        limit: limitSchema(20, 200),
        port: portSchema,
      },
      annotations: readOnlyAnnotations,
    },
    async ({ query, type, limit, port }) => {
      if (!query?.trim() && !type?.trim()) {
        return {
          content: [
            {
              type: "text" as const,
              text: "Provide query and/or type (at least one required).",
            },
          ],
          isError: true,
        };
      }
      return runGodotTool<SearchNodesResult>(port, "search_nodes", {
        query,
        type,
        limit,
      });
    }
  );
}
