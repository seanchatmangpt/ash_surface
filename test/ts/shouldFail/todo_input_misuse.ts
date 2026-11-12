import { SCHEMAS } from "../generated/ash_surface_client.mjs";

const createSchema = SCHEMAS["Todo.create"];

// Each line below MUST be a tsc error; the test asserts the error count.
export const a: number = createSchema.safeParse({ title: "ok" }).success;
export const b: string = createSchema.safeParse({ title: "ok" });
export const c = SCHEMAS["No.Such"].parse({});
