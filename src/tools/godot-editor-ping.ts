import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { runGodotTool } from "../godot/run-godot-tool.js";
import type { PingResult } from "../godot/protocol.js";
import { portSchema, readOnlyAnnotations } from "./schemas.js";

export function registerGodotEditorPingTool(server: McpServer): void {
  server.registerTool(
    "godot_editor_ping",
    {
      title: "Ping Godot editor",
      description:
        "Verify the Godot editor is reachable and return protocol/version. " +
        "Use first when unsure the plugin is running. Do NOT use for scene inspection — prefer godot_editor_get_state. " +
        "Response ~50 tokens.",
      inputSchema: { port: portSchema },
      annotations: readOnlyAnnotations,
    },
    async ({ port }) => runGodotTool<PingResult>(port, "ping")
  );
}
