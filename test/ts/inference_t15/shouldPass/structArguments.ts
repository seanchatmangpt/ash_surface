import type { InferResult, UnifiedFieldSelection } from "../schemas";
type Eq<A, B> = (<T>() => T extends A ? 1 : 2) extends (<T>() => T extends B ? 1 : 2) ? true : false;
const assertType = <_T extends true>() => {};
void assertType;
import type { AssignToUserTodoConfig, AssignToUsersTodoConfig, InferAssignToUserTodoResult } from "../schemas";
// ref: structArguments.ts - struct and array-of-struct arguments, optional sibling argument, selected result.
export const single: AssignToUserTodoConfig = { args: { assignee: { id: "1", name: "Test User", email: "t@example.com" }, reason: "r" }, fields: ["assigneeId", "assigneeName", "reason"] };
export const noReason: AssignToUserTodoConfig = { args: { assignee: { id: "1", name: "n", email: "e" } }, fields: ["assigneeId"] };
export const many: AssignToUsersTodoConfig = { args: { assignees: [{ id: "1", name: "a", email: "a@e" }, { id: "2", name: "b", email: "b@e" }] }, fields: ["assigneeId", "assigneeName"] };
declare const r: InferAssignToUserTodoResult<["assigneeId", "assigneeName", "reason"]>;
export const reason: string | null = r.reason;
// @ts-expect-error struct member email is required
export const missingEmail: AssignToUserTodoConfig = { args: { assignee: { id: "1", name: "n" } }, fields: ["assigneeId"] };
// @ts-expect-error the array argument takes structs, not strings
export const wrongItems: AssignToUsersTodoConfig = { args: { assignees: ["x"] }, fields: ["assigneeId"] };
