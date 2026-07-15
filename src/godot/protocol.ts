/** Current WebSocket bridge protocol version (semver string). */
export const BRIDGE_PROTOCOL_VERSION = "1";

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
  godot_version: Record<string, unknown>;
  editor: boolean;
}

export interface SceneTreeNode {
  name: string;
  type: string;
  /** Path relative to the edited scene root (e.g. "MainScene/Player"). */
  path: string;
  children: SceneTreeNode[];
}

export interface SceneTreeResult {
  scene_path: string;
  root: SceneTreeNode | null;
  message?: string;
}

export interface NodePropertyResult {
  path: string;
  property: string;
  value: unknown;
}

export interface NodePropertyInfo {
  name: string;
  type: string;
  class_name: string;
  hint: number;
  hint_string: string;
  usage: string[];
  value?: unknown;
}

export interface NodePropertiesResult {
  path: string;
  type: string;
  filters?: {
    exported_only: boolean;
    editable_only: boolean;
    relevant_only: boolean;
    include_values: boolean;
  };
  properties: NodePropertyInfo[];
}
