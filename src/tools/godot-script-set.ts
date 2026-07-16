import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { runGodotTool } from "../godot/run-godot-tool.js";
import type { SetScriptResult } from "../godot/protocol.js";
import {
  destructiveAnnotations,
  nodePathSchema,
  portSchema,
} from "./schemas.js";

export function registerGodotScriptSetTool(server: McpServer): void {
  server.registerTool(
    "godot_script_set",
    {
      title: "Write script source",
      description:
        "Overwrite a .gd file on disk (full content). Optionally attach_to a node. Destructive overwrite. " +
        "Do NOT send partial patches — full file content required. Returns {bytes,lines} only (no echo of content). " +
        "After edits, use godot_editor_run_project + godot_log_get to verify. Response ~40 tokens.",
      inputSchema: {
        script_path: z
          .string()
          .min(1)
          .describe('res:// path to write (e.g. "res://player.gd")'),
        content: z.string().describe("Full new file contents."),
        attach_to: nodePathSchema
          .optional()
          .describe("Optional node path to attach the script after write."),
        port: portSchema,
      },
      annotations: destructiveAnnotations,
    },
    async ({ script_path, content, attach_to, port }) =>
      runGodotTool<SetScriptResult>(
        port,
        "set_script",
        { script_path, content, attach_to },
        { timeoutMs: 15000 }
      )
  );
}
