import type { InferResult, UnifiedFieldSelection, SortString, ConditionalPaginatedResult } from "../schemas";
import type { TodoSchema, UserSchema, CommentSchema, TagSchema, AddressSchema, NoFieldsSchema } from "../schemas";
type Eq<A, B> = (<T>() => T extends A ? 1 : 2) extends (<T>() => T extends B ? 1 : 2) ? true : false;
export const assertType = <_T extends true>() => {};

const sel = [{ meta: ["k", "n"] }] satisfies UnifiedFieldSelection<TodoSchema>[];
type R = InferResult<TodoSchema, typeof sel>;
export const r: R = { meta: { k: "a", n: 1 } };
