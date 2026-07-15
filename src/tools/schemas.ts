import { z } from "zod";

export const portSchema = z
  .number()
  .int()
  .min(1)
  .max(65535)
  .optional()
  .describe("Override the Godot plugin WebSocket port (default 6505)");

export const nodePathSchema = z
  .string()
  .describe(
    'Node path relative to the edited scene root (e.g. "Player" or "Player/Sprite2D"). Use the root node name for the scene root.'
  );
