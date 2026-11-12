import type { UnifiedFieldSelection, InferResult } from "../schemas";
import type { TodoSchema } from "../schemas";
// ref: shouldFail/nonFieldCalculations.ts - a calculation exposed with field?: false is absent from the emitted schema.
import type { InferListTodosResult, GetSingleTodoConfig } from "../schemas";
export const inList: UnifiedFieldSelection<TodoSchema>[] = [
  "id",
  "title",
  // @ts-expect-error internalScore (non-field calculation) is not in the schema
  "internalScore",
];
export const inGetConfig: GetSingleTodoConfig = {
  fields: [
    "id",
    "title",
    // @ts-expect-error internalScore is not selectable in a get action either
    "internalScore",
  ],
};
export const inSelf: UnifiedFieldSelection<TodoSchema>[] = [
  "id",
  // @ts-expect-error internalScore is not selectable in nested calculation fields
  { self: { args: { prefix: "test_" }, fields: ["id", "title", "internalScore"] } },
];
// @ts-expect-error result inference refuses a selection naming a non-field calculation
export type NoInternalScore = InferListTodosResult<["id", "internalScore"]>;
