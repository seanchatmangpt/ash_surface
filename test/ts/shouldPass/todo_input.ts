import { z } from "zod";
import { SCHEMAS } from "../generated/ash_surface_client.mjs";

const createSchema = SCHEMAS["Todo.create"];

// Parsed value must be usable as a typed object under --strict.
export function titleOf(raw: unknown): string {
  const parsed = createSchema.parse(raw);
  return String((parsed as Record<string, unknown>)["title"]);
}

export const isSchema: z.ZodType = createSchema;
export const result = createSchema.safeParse({ title: "ok" });
export const succeeded: boolean = result.success;
