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
