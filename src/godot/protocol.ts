/** Current WebSocket bridge protocol version. */
export const BRIDGE_PROTOCOL_VERSION = "2";

/** JSON envelope sent to / received from the Godot plugin. */
export interface BridgeRequest {
  id: string;
  method: string;
  params?: Record<string, unknown>;
}

export interface BridgeError {
  code: number;
  message: string;
}

export interface BridgeResponse {
  id: string;
  result?: unknown;
  error?: BridgeError;
}

export interface PingResult {
  pong: boolean;
  protocol_version: string;
  godot_version: string;
  editor: boolean;
}

export interface EditorStateResult {
  scene_path: string;
  root: { name: string; type: string; path: string } | null;
  selected: Array<{ path: string; type: string; name: string }>;
  playing: boolean;
  main_screen: string;
}

export interface SceneTreeNode {
  name: string;
  type: string;
  path: string;
  children: SceneTreeNode[];
}

export interface SceneTreeResult {
  scene_path: string;
  format: "outline" | "json";
  tree?: string;
  root?: SceneTreeNode | null;
  node_count: number;
  truncated: boolean;
  max_depth?: number;
  limit?: number;
  message?: string;
}

export interface SearchNodesResult {
  matches: Array<{ name: string; type: string; path: string }>;
  total: number;
  truncated: boolean;
  limit?: number;
  message?: string;
}

export interface NodePropertyResult {
  path: string;
  property: string;
  value: unknown;
}

export interface NodePropertyInfo {
  name: string;
  type?: string;
  class_name?: string;
  hint?: number;
  hint_string?: string;
  usage?: string[];
  value?: unknown;
}

export interface NodePropertiesResult {
  path: string;
  type: string;
  detail: string;
  total: number;
  truncated: boolean;
  properties: Array<NodePropertyInfo | string>;
}

export interface CreateNodeResult {
  path: string;
  type: string;
  name: string;
  parent: string;
}

export interface DeleteNodeResult {
  deleted: string;
}

export interface InstantiateSceneResult {
  path: string;
  type: string;
  name: string;
  scene_path: string;
  parent: string;
}

export interface SaveSceneResult {
  saved: boolean;
  scene_path: string;
}

export interface GetScriptResult {
  script_path: string;
  offset: number;
  limit: number;
  total_lines: number;
  truncated: boolean;
  content: string;
}

export interface SetScriptResult {
  saved: boolean;
  script_path: string;
  bytes: number;
  lines: number;
  attached_to: string | null;
}

export interface RunProjectResult {
  playing: boolean;
  mode: string;
}

export interface StopProjectResult {
  stopped: boolean;
  playing: boolean;
}

export interface OutputLogResult {
  tail: number;
  level: string;
  count: number;
  lines: Array<{ text: string; level: string }>;
}
