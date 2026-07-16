import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { runGodotTool } from "../godot/run-godot-tool.js";
import type { EditorStateResult } from "../godot/protocol.js";
import { portSchema, readOnlyAnnotations } from "./schemas.js";

export function registerGodotEditorGetStateTool(server: McpServer): void {
  server.registerTool(
    "godot_editor_get_state",
    {
      title: "Get editor state",
      description:
        "Compact editor context: open scene path, root node, selection, playing flag, main screen (2D/3D/Script). " +
        "Prefer this over godot_scene_get_tree when you only need where you are. " +
        "Do NOT use to list all nodes — use godot_scene_search_nodes or a shallow tree. Response ~100 tokens.",
      inputSchema: { port: portSchema },
      annotations: readOnlyAnnotations,
    },
    async ({ port }) =>
      runGodotTool<EditorStateResult>(port, "get_editor_state")
  );
}
