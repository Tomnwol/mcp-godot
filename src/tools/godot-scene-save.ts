import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { runGodotTool } from "../godot/run-godot-tool.js";
import type { SaveSceneResult } from "../godot/protocol.js";
import { portSchema, writeAnnotations } from "./schemas.js";

export function registerGodotSceneSaveTool(server: McpServer): void {
  server.registerTool(
    "godot_scene_save",
    {
      title: "Save scene",
      description:
        "Save the currently edited scene to disk. Call after structural or property edits you want persisted. " +
        "Do NOT call before every single set — batch edits then save once. Response ~30 tokens.",
      inputSchema: { port: portSchema },
      annotations: writeAnnotations,
    },
    async ({ port }) =>
      runGodotTool<SaveSceneResult>(port, "save_scene", undefined, {
        timeoutMs: 10000,
      })
  );
}
