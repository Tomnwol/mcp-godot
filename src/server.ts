/**
 * Godot MCP server — bridges AI assistants to the Godot editor.
 *
 * Tool namespaces:
 *   godot_editor_*  — connectivity, state, run/stop
 *   godot_scene_*   — tree, search, CRUD, save
 *   godot_node_*    — property inspect/modify
 *   godot_script_*  — script read/write
 *   godot_log_*     — output log tail
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { serverInfo } from "./config.js";
import { registerGodotEditorPingTool } from "./tools/godot-editor-ping.js";
import { registerGodotEditorGetStateTool } from "./tools/godot-editor-get-state.js";
import { registerGodotEditorRunProjectTool } from "./tools/godot-editor-run-project.js";
import { registerGodotEditorStopProjectTool } from "./tools/godot-editor-stop-project.js";
import { registerGodotSceneGetTreeTool } from "./tools/godot-scene-get-tree.js";
import { registerGodotSceneSearchNodesTool } from "./tools/godot-scene-search-nodes.js";
import { registerGodotSceneSaveTool } from "./tools/godot-scene-save.js";
import { registerGodotSceneCreateNodeTool } from "./tools/godot-scene-create-node.js";
import { registerGodotSceneDeleteNodeTool } from "./tools/godot-scene-delete-node.js";
import { registerGodotSceneInstantiateTool } from "./tools/godot-scene-instantiate.js";
import { registerGodotNodeListPropertiesTool } from "./tools/godot-node-list-properties.js";
import { registerGodotNodeGetPropertyTool } from "./tools/godot-node-get-property.js";
import { registerGodotNodeSetPropertyTool } from "./tools/godot-node-set-property.js";
import { registerGodotScriptGetTool } from "./tools/godot-script-get.js";
import { registerGodotScriptSetTool } from "./tools/godot-script-set.js";
import { registerGodotLogGetTool } from "./tools/godot-log-get.js";

const server = new McpServer(serverInfo);

registerGodotEditorPingTool(server);
registerGodotEditorGetStateTool(server);
registerGodotEditorRunProjectTool(server);
registerGodotEditorStopProjectTool(server);
registerGodotSceneGetTreeTool(server);
registerGodotSceneSearchNodesTool(server);
registerGodotSceneSaveTool(server);
registerGodotSceneCreateNodeTool(server);
registerGodotSceneDeleteNodeTool(server);
registerGodotSceneInstantiateTool(server);
registerGodotNodeListPropertiesTool(server);
registerGodotNodeGetPropertyTool(server);
registerGodotNodeSetPropertyTool(server);
registerGodotScriptGetTool(server);
registerGodotScriptSetTool(server);
registerGodotLogGetTool(server);

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error(`${serverInfo.name} v${serverInfo.version} started on stdio`);
}

main().catch((error) => {
  console.error("Fatal MCP server error:", error);
  process.exit(1);
});
