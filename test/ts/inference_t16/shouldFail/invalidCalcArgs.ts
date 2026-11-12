import type { UnifiedFieldSelection, InferResult } from "../schemas";
import type { TodoSchema } from "../schemas";
// ref: shouldFail/invalidCalcArgs.ts - calculation args are typed; wrong types, shapes and a missing fields property fail.
export const wrongArgType: UnifiedFieldSelection<TodoSchema>[] = [
  "id",
  // @ts-expect-error prefix is string | undefined, not number
  { self: { args: { prefix: 42 }, fields: ["title"] } },
];
export const wrongNestedArgType: UnifiedFieldSelection<TodoSchema>[] = [
  "id",
  // @ts-expect-error the nested self calculation prefix must not accept boolean
  { self: { args: { prefix: "ok" }, fields: ["title", { self: { args: { prefix: true }, fields: ["status"] } }] } },
];
export const unknownArg: UnifiedFieldSelection<TodoSchema>[] = [
  "id",
  // @ts-expect-error unknownArg is not an argument of the self calculation
  { self: { args: { prefix: "test_", unknownArg: "invalid" }, fields: ["title"] } },
];
export const argsAsString: UnifiedFieldSelection<TodoSchema>[] = [
  "id",
  // @ts-expect-error args must be an object, not a string
  { self: { args: "invalid", fields: ["title"] } },
];
export const argsAsArray: UnifiedFieldSelection<TodoSchema>[] = [
  "id",
  // @ts-expect-error args must be an object, not an array
  { self: { args: ["prefix", "test_"], fields: ["title"] } },
];
export const argsAsNull: UnifiedFieldSelection<TodoSchema>[] = [
  "id",
  // @ts-expect-error args must be omitted or an object, not null
  { self: { args: null, fields: ["title"] } },
];
export const missingFields: UnifiedFieldSelection<TodoSchema>[] = [
  "id",
  // @ts-expect-error the fields property is required
  { self: { args: { prefix: "test_" } } },
];
export const validArgs: UnifiedFieldSelection<TodoSchema>[] = [
  "id",
  { self: { args: { prefix: "test_" }, fields: ["title"] } },
];
