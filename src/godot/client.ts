import { randomUUID } from "node:crypto";
import WebSocket from "ws";
import { godotBridgeConfig } from "./config.js";
import type { BridgeRequest, BridgeResponse } from "./protocol.js";

export interface GodotClientOptions {
  host?: string;
  port?: number;
  timeoutMs?: number;
}

/** Short-lived WebSocket client for talking to the Godot editor plugin. */
export class GodotClient {
  private readonly host: string;
  private readonly port: number;
  private readonly timeoutMs: number;

  constructor(options: GodotClientOptions = {}) {
    this.host = options.host ?? godotBridgeConfig.host;
    this.port = options.port ?? godotBridgeConfig.port;
    this.timeoutMs = options.timeoutMs ?? godotBridgeConfig.timeoutMs;
  }

  async call<T>(method: string, params?: Record<string, unknown>): Promise<T> {
    const id = randomUUID();
    const request: BridgeRequest = { id, method, params };
    const url = `ws://${this.host}:${this.port}`;

    return new Promise((resolve, reject) => {
      const ws = new WebSocket(url);
      let settled = false;

      const fail = (error: Error) => {
        if (settled) return;
        settled = true;
        clearTimeout(timer);
        ws.terminate();
        reject(error);
      };

      const timer = setTimeout(() => {
        fail(
          new Error(
            `Timed out after ${this.timeoutMs}ms waiting for Godot at ${url}. ` +
              "Is the editor open with the Godot MCP plugin enabled?"
          )
        );
      }, this.timeoutMs);

      ws.on("open", () => {
        ws.send(JSON.stringify(request));
      });

      ws.on("message", (data) => {
        if (settled) return;
        settled = true;
        clearTimeout(timer);

        try {
          const response = JSON.parse(data.toString()) as BridgeResponse;
          if (response.error) {
            reject(new Error(response.error.message));
            return;
          }
          resolve(response.result as T);
        } catch (error) {
          reject(error instanceof Error ? error : new Error(String(error)));
        } finally {
          ws.close();
        }
      });

      ws.on("error", (error) => {
        fail(
          new Error(
            `Cannot reach Godot plugin at ${url}: ${error.message}. ` +
              "Enable the plugin in Project → Project Settings → Plugins."
          )
        );
      });
    });
  }
}
