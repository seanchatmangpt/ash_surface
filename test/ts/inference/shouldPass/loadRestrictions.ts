import type { InferResult, UnifiedFieldSelection, SortString, ConditionalPaginatedResult } from "../schemas";
import type { TodoSchema, UserSchema, CommentSchema, TagSchema, AddressSchema, NoFieldsSchema } from "../schemas";
type Eq<A, B> = (<T>() => T extends A ? 1 : 2) extends (<T>() => T extends B ? 1 : 2) ? true : false;
export const assertType = <_T extends true>() => {};

const sel = [{ comments: { fields: ["body"], filter: { body: "x" }, sort: "-body", limit: 3 } }] satisfies UnifiedFieldSelection<TodoSchema>[];
export const s = sel;
