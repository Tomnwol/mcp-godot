import { GodotClient } from "./client.js";

type ToolTextContent = { type: "text"; text: string };

export type GodotToolResult = {
  content: ToolTextContent[];
  isError?: boolean;
};

/** Call the Godot plugin and format the result as MCP tool content. */
export async function runGodotTool<T>(
  port: number | undefined,
  method: string,
  params?: Record<string, unknown>
): Promise<GodotToolResult> {
  try {
    const client = new GodotClient(port !== undefined ? { port } : {});
    const result = await client.call<T>(method, params);
    return {
      content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
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
