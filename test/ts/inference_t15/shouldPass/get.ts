import type { InferResult, UnifiedFieldSelection } from "../schemas";
type Eq<A, B> = (<T>() => T extends A ? 1 : 2) extends (<T>() => T extends B ? 1 : 2) ? true : false;
const assertType = <_T extends true>() => {};
void assertType;
import type { InferGetSingleTodoResult, InferGetSingleTodoNullableResult, GetSingleTodoConfig } from "../schemas";
// ref: get.ts - get actions: selected fields, input args, relationships, aggregates; nullable get adds `| null`.
declare const basic: InferGetSingleTodoResult<["id", "title", "description", "completed", "status"]>;
export const id: string = basic.id;
export const description: string | null = basic.description;
export const completed: boolean | null = basic.completed;
declare const withUser: InferGetSingleTodoResult<["id", "title", { user: ["id", "name", "email"] }]>;
export const userName: string = withUser.user.name;
declare const agg: InferGetSingleTodoResult<["id", "commentCount", "hasComments", "averageRating"]>;
export const commentCount: number = agg.commentCount;
export const rating: number | null = agg.averageRating;
export const config: GetSingleTodoConfig = { fields: ["id", "title", "priority", "completed"], args: { filterCompleted: false, priorityFilter: "high" } };
declare const nullable: InferGetSingleTodoNullableResult<["id", "title"]>;
export const nullableId: string | undefined = nullable?.id;
// @ts-expect-error nullable get result must be narrowed before access
export const unnarrowed: string = nullable.id;
// @ts-expect-error a non-nullable get result carries no null branch
export const noNull: null = basic;
