import type { InferResult, UnifiedFieldSelection, SortString, ConditionalPaginatedResult } from "../schemas";
import type { TodoSchema, UserSchema, CommentSchema, TagSchema, AddressSchema, NoFieldsSchema } from "../schemas";
type Eq<A, B> = (<T>() => T extends A ? 1 : 2) extends (<T>() => T extends B ? 1 : 2) ? true : false;
export const assertType = <_T extends true>() => {};

const sel = ["id", "points"] satisfies UnifiedFieldSelection<TodoSchema>[];
type R = InferResult<TodoSchema, typeof sel>;
const p: R["points"] = null;
const q: R["points"] = 3;
export { p, q };
