import type { InferResult, UnifiedFieldSelection, SortString, ConditionalPaginatedResult } from "../schemas";
import type { TodoSchema, UserSchema, CommentSchema, TagSchema, AddressSchema, NoFieldsSchema } from "../schemas";
type Eq<A, B> = (<T>() => T extends A ? 1 : 2) extends (<T>() => T extends B ? 1 : 2) ? true : false;
export const assertType = <_T extends true>() => {};

// Guards against filter/sort types being loosened to `any` on a many-cardinality relationship.
export const f: UnifiedFieldSelection<TodoSchema>[] = [{ comments: { fields: ["id"], filter: { body: 5 } } }]; // @error TS2322
export const s: UnifiedFieldSelection<TodoSchema>[] = [{ comments: { fields: ["id"], sort: ["body", 7] } }]; // @error TS2322
export const s2: UnifiedFieldSelection<TodoSchema>[] = [{ comments: { fields: ["id"], sort: "~body" } }]; // @error TS2322
