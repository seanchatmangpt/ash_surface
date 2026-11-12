import type { InferResult, UnifiedFieldSelection, SortString, ConditionalPaginatedResult } from "../schemas";
import type { TodoSchema, UserSchema, CommentSchema, TagSchema, AddressSchema, NoFieldsSchema } from "../schemas";
type Eq<A, B> = (<T>() => T extends A ? 1 : 2) extends (<T>() => T extends B ? 1 : 2) ? true : false;
export const assertType = <_T extends true>() => {};

const sel = ["id", "title", "done", "points"] satisfies UnifiedFieldSelection<TodoSchema>[];
type R = InferResult<TodoSchema, typeof sel>;
export const r: R = { id: "1", title: "t", done: false, points: null };
export const e: InferResult<TodoSchema, undefined> = {};
