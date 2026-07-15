import { z } from "zod";
import { GodotClient } from "../godot/client.js";
import type { PingResult } from "../godot/protocol.js";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";

const inputSchema = {
  port: z
    .number()
    .int()
    .min(1)
    .max(65535)
    .optional()
    .describe("Override the Godot plugin WebSocket port (default 6505)"),
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
    async ({ port }) => {
      try {
        const client = new GodotClient(port !== undefined ? { port } : {});
        const result = await client.call<PingResult>("ping");

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
