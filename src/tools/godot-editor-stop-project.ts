import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { runGodotTool } from "../godot/run-godot-tool.js";
import type { StopProjectResult } from "../godot/protocol.js";
import { destructiveAnnotations, portSchema } from "./schemas.js";

export function registerGodotEditorStopProjectTool(server: McpServer): void {
  server.registerTool(
    "godot_editor_stop_project",
    {
      title: "Stop project",
      description:
        "Stop the currently playing scene/project in the editor. Safe if nothing is playing. Response ~20 tokens.",
      inputSchema: { port: portSchema },
      annotations: destructiveAnnotations,
    },
    async ({ port }) => runGodotTool<StopProjectResult>(port, "stop_project")
  );
}
