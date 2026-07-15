import { execSync } from "node:child_process";
import { readFileSync } from "node:fs";

function isWsl(): boolean {
  try {
    return readFileSync("/proc/version", "utf8").toLowerCase().includes("microsoft");
  } catch {
    return false;
  }
}

/** Default gateway in WSL2 points at the Windows host. */
function wslWindowsHost(): string | undefined {
  try {
    const route = execSync("ip route show default", { encoding: "utf8" });
    const match = route.match(/default via (\S+)/);
    return match?.[1];
  } catch {
    return undefined;
  }
}

function resolveHost(): string {
  if (process.env.GODOT_MCP_HOST) {
    return process.env.GODOT_MCP_HOST;
  }

  // WSL: Godot runs on Windows; 127.0.0.1 is the Linux VM, not the host.
  if (isWsl()) {
    const windowsHost = wslWindowsHost();
    if (windowsHost) {
      return windowsHost;
    }
  }

  return "127.0.0.1";
}

/** Connection settings for the Godot editor WebSocket bridge. */
export const godotBridgeConfig = {
  host: resolveHost(),
  port: Number(process.env.GODOT_MCP_PORT ?? "6505"),
  timeoutMs: Number(process.env.GODOT_MCP_TIMEOUT_MS ?? "3000"),
} as const;
