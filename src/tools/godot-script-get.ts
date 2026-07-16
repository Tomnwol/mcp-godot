import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { runGodotTool } from "../godot/run-godot-tool.js";
import type { GetScriptResult } from "../godot/protocol.js";
import {
  limitSchema,
  nodePathSchema,
  portSchema,
  readOnlyAnnotations,
} from "./schemas.js";

export function registerGodotScriptGetTool(server: McpServer): void {
  server.registerTool(
    "godot_script_get",
    {
      title: "Get script source",
      description:
        "Read GDScript source by node path or script_path, paginated (default offset=1, limit=80 lines). " +
        "Do NOT request huge limits — page with offset. Prefer script_path when known. Response ~200–1500 tokens.",
      inputSchema: {
        path: nodePathSchema
          .optional()
          .describe("Node path whose attached script to read."),
        script_path: z
          .string()
          .optional()
          .describe('res:// path to a .gd file (e.g. "res://player.gd")'),
        offset: z
          .number()
          .int()
          .min(1)
          .default(1)
          .describe("1-based start line (default 1)."),
        limit: limitSchema(80, 400),
        port: portSchema,
      },
      annotations: readOnlyAnnotations,
    },
    async ({ path, script_path, offset, limit, port }) => {
      if (!path?.trim() && !script_path?.trim()) {
        return {
          content: [
            {
              type: "text" as const,
              text: "Provide path (node) or script_path (at least one required).",
            },
          ],
          isError: true,
        };
      }
      return runGodotTool<GetScriptResult>(port, "get_script", {
        path,
        script_path,
        offset,
        limit,
      });
    }
  );
}
