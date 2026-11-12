import type { InferResult, UnifiedFieldSelection } from "../schemas";
type Eq<A, B> = (<T>() => T extends A ? 1 : 2) extends (<T>() => T extends B ? 1 : 2) ? true : false;
const assertType = <_T extends true>() => {};
void assertType;
import type { InferGetUserByEmailResult, InferGetUserByEmailNullableResult, GetUserByEmailConfig, InferGetTodoByUserAndStatusResult, GetTodoByUserAndStatusConfig } from "../schemas";
// ref: getBy.ts - get_by actions: keyed lookups (single and composite key), relationships, nullable variant.
declare const basic: InferGetUserByEmailResult<["id", "name", "email"]>;
export const userEmail: string = basic.email;
export const cfg: GetUserByEmailConfig = { args: { email: "alice@example.com" }, fields: ["id", "name", "email"] };
declare const todos: InferGetUserByEmailResult<["id", { todos: ["id", "title", "completed", "status"] }]>;
export const todoTitle: string = todos.todos[0].title;
declare const nullable: InferGetUserByEmailNullableResult<["id", "name"]>;
export const nullableName: string | undefined = nullable?.name;
// @ts-expect-error nullable get_by result must be narrowed
export const unnarrowed: string = nullable.name;
declare const composite: InferGetTodoByUserAndStatusResult<["id", "title", "status"]>;
export const status: string = composite.status;
export const ccfg: GetTodoByUserAndStatusConfig = { args: { userId: "u", status: "pending" }, fields: ["id"] };
// @ts-expect-error composite key requires both members
export const missingKey: GetTodoByUserAndStatusConfig = { args: { userId: "u" }, fields: ["id"] };
// @ts-expect-error key member has the wrong type
export const wrongKey: GetUserByEmailConfig = { args: { email: 1 }, fields: ["id"] };
