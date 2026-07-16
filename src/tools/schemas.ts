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

export const limitSchema = (defaultLimit: number, max = 200) =>
  z
    .number()
    .int()
    .min(1)
    .max(max)
    .default(defaultLimit)
    .describe(`Max items to return (default ${defaultLimit}, max ${max})`);

export const jsonValueSchema = z.union([
  z.string(),
  z.number(),
  z.boolean(),
  z.null(),
  z.array(z.any()),
  z.record(z.string(), z.any()),
]);

/** Shared read-only annotation for inspect tools. */
export const readOnlyAnnotations = {
  readOnlyHint: true,
  destructiveHint: false,
  idempotentHint: true,
  openWorldHint: false,
} as const;

/** Shared annotation for non-destructive writes (set property, create, save). */
export const writeAnnotations = {
  readOnlyHint: false,
  destructiveHint: false,
  idempotentHint: false,
  openWorldHint: false,
} as const;

/** Shared annotation for destructive ops (delete, stop, overwrite script). */
export const destructiveAnnotations = {
  readOnlyHint: false,
  destructiveHint: true,
  idempotentHint: false,
  openWorldHint: false,
} as const;
