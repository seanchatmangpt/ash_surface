import type { InferResult, UnifiedFieldSelection, SortString, ConditionalPaginatedResult } from "../schemas";
import type { TodoSchema, UserSchema, CommentSchema, TagSchema, AddressSchema, NoFieldsSchema } from "../schemas";
type Eq<A, B> = (<T>() => T extends A ? 1 : 2) extends (<T>() => T extends B ? 1 : 2) ? true : false;
export const assertType = <_T extends true>() => {};

type Pk = Pick<TagSchema, "id" | "label">;
const sel = ["id", "label"] satisfies UnifiedFieldSelection<TagSchema>[];
export const r: InferResult<TagSchema, typeof sel> = { id: "1", label: "l" };
export const p: Pk["id"] = "x";
