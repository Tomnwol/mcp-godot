import { z } from "zod";
import { runGodotTool } from "../godot/run-godot-tool.js";
import type { PingResult } from "../godot/protocol.js";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { portSchema } from "./schemas.js";

const inputSchema = {
  port: portSchema,
};

export function registerPingGodotTool(server: McpServer): void {
  server.registerTool(
    "ping_godot",
    {
      title: "Ping Godot",
      description:
        "Verify the Godot editor is running and the Godot MCP plugin is reachable.",
      inputSchema,
    },
    async ({ port }) => runGodotTool<PingResult>(port, "ping")
  );
}
