function resolveHost(): string {
  return process.env.GODOT_MCP_HOST ?? "127.0.0.1";
}

/** Connection settings for the Godot editor WebSocket bridge. */
export const godotBridgeConfig = {
  host: resolveHost(),
  port: Number(process.env.GODOT_MCP_PORT ?? "6505"),
  timeoutMs: Number(process.env.GODOT_MCP_TIMEOUT_MS ?? "3000"),
} as const;
