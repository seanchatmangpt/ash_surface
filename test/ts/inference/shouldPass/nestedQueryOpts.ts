import type { InferResult, UnifiedFieldSelection, SortString, ConditionalPaginatedResult } from "../schemas";
import type { TodoSchema, UserSchema, CommentSchema, TagSchema, AddressSchema, NoFieldsSchema } from "../schemas";
type Eq<A, B> = (<T>() => T extends A ? 1 : 2) extends (<T>() => T extends B ? 1 : 2) ? true : false;
export const assertType = <_T extends true>() => {};

const sel = [{ comments: { fields: ["id"], page: { limit: 5, offset: 0 } } }] satisfies UnifiedFieldSelection<TodoSchema>[];
export const s = sel;
const sel2 = [{ comments: { fields: ["id"], page: { limit: 5, after: "c" } } }] satisfies UnifiedFieldSelection<TodoSchema>[];
export const s2 = sel2;
