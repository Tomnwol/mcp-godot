import { GodotClient } from "./client.js";

type ToolTextContent = { type: "text"; text: string };

export type GodotToolResult = {
  content: ToolTextContent[];
  isError?: boolean;
};

export type RunGodotToolOptions = {
  /** Override WebSocket timeout for slow operations (save, script write, run). */
  timeoutMs?: number;
};

/** Drop undefined values so Godot receives only explicit params. */
export function compactParams(
  params: Record<string, unknown>
): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined) out[key] = value;
  }
  return out;
}

/** Call the Godot plugin and format the result as compact MCP tool content. */
export async function runGodotTool<T>(
  port: number | undefined,
  method: string,
  params?: Record<string, unknown>,
  options?: RunGodotToolOptions
): Promise<GodotToolResult> {
  try {
    const client = new GodotClient({
      ...(port !== undefined ? { port } : {}),
      ...(options?.timeoutMs !== undefined
        ? { timeoutMs: options.timeoutMs }
        : {}),
    });
    const result = await client.call<T>(
      method,
      params !== undefined ? compactParams(params) : undefined
    );
    // Compact JSON — pretty-print wastes 30–50% tokens with no benefit to models.
    return {
      content: [{ type: "text", text: JSON.stringify(result) }],
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
