import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { runGodotTool } from "../godot/run-godot-tool.js";
import type { OutputLogResult } from "../godot/protocol.js";
import { limitSchema, portSchema, readOnlyAnnotations } from "./schemas.js";

export function registerGodotLogGetTool(server: McpServer): void {
  server.registerTool(
    "godot_log_get",
    {
      title: "Get output log",
      description:
        "Tail recent editor/engine log lines (default 40). Filter with level=error|warning|all. " +
        "Do NOT request huge tails — prefer level=error after a run. Captured via Godot Logger (4.5+). Response ~100–800 tokens.",
      inputSchema: {
        tail: limitSchema(40, 200).describe("Number of recent lines (default 40)."),
        level: z
          .enum(["all", "error", "warning", "info"])
          .default("all")
          .describe("Filter by severity (default all). Prefer error when debugging."),
        port: portSchema,
      },
      annotations: readOnlyAnnotations,
    },
    async ({ tail, level, port }) =>
      runGodotTool<OutputLogResult>(port, "get_output_log", { tail, level })
  );
}
