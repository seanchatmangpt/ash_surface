import type { ListTodosConfig, CreateTodoConfig, GetSingleTodoConfig, SearchTodosConfig, InferDestroyTodoResult } from "../schemas";
// ref: shouldFail/operations.ts - per-operation config misuse (ash_surface config = { fields, args, ... }).
export const listBadField: ListTodosConfig = {
  // @ts-expect-error nonExistentField is not a selectable field
  fields: ["id", "title", "nonExistentField"],
};
export const createMissingTitle: CreateTodoConfig = {
  fields: ["id", "title"],
  // @ts-expect-error title is required for createTodo
  args: { userId: "user-123" },
};
export const getBadNested: GetSingleTodoConfig = {
  fields: [
    "id",
    // @ts-expect-error invalidUserField is not a field of user; nonExistentRelation is not a relationship
    { user: ["id", "name", "invalidUserField"], nonExistentRelation: ["id", "title"] },
  ],
};
export const listBadCalcArg: ListTodosConfig = {
  fields: [
    "id",
    // @ts-expect-error invalidArg is not an argument of the self calculation
    { user: ["id"], self: { args: { prefix: "test_", invalidArg: "not allowed" }, fields: ["id", "title"] } },
  ],
};
export const createWrongBoolean: CreateTodoConfig = {
  fields: ["id"],
  // @ts-expect-error completed must be boolean, not string
  args: { title: "T", completed: "invalid", userId: "u" },
};
export const createBadPriority: CreateTodoConfig = {
  fields: ["id"],
  // @ts-expect-error "invalid" is not a priority value
  args: { title: "T", priority: "invalid", userId: "u" },
};
export const createBadStatus: CreateTodoConfig = {
  fields: ["id"],
  // @ts-expect-error "invalid" is not a status value
  args: { title: "T", status: "invalid", userId: "u" },
};
export const getArgsAsString: GetSingleTodoConfig = {
  fields: [
    "id",
    // @ts-expect-error calculation args must be an object, not a string
    { self: { args: "invalid", fields: ["id"] } },
  ],
};
export const searchQueryNumber: SearchTodosConfig = {
  fields: ["id", "title"],
  // @ts-expect-error query must be a string, not a number
  args: { query: 123 },
};
declare const destroyed: InferDestroyTodoResult;
// @ts-expect-error a destroy result is the empty object; it carries no fields
export const destroyHasNoFields: string = destroyed.id;
export const validCreate: CreateTodoConfig = { fields: ["id"], args: { title: "T", userId: "u", priority: "high" } };
