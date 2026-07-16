import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { runGodotTool } from "../godot/run-godot-tool.js";
import type { RunProjectResult } from "../godot/protocol.js";
import { portSchema, writeAnnotations } from "./schemas.js";

export function registerGodotEditorRunProjectTool(server: McpServer): void {
  server.registerTool(
    "godot_editor_run_project",
    {
      title: "Run project",
      description:
        "Play the project in the editor (F5 main scene, or current scene). Stops any running play first. " +
        "Then use godot_log_get for errors. Do NOT spam run — one play, inspect, stop. Response ~30 tokens.",
      inputSchema: {
        mode: z
          .enum(["main", "current"])
          .default("main")
          .describe('main = project main scene (default); current = edited scene.'),
        port: portSchema,
      },
      annotations: writeAnnotations,
    },
    async ({ mode, port }) =>
      runGodotTool<RunProjectResult>(port, "run_project", { mode })
  );
}
