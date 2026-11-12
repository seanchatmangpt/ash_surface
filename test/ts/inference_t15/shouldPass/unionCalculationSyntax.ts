import type { InferResult, UnifiedFieldSelection } from "../schemas";
type Eq<A, B> = (<T>() => T extends A ? 1 : 2) extends (<T>() => T extends B ? 1 : 2) ? true : false;
const assertType = <_T extends true>() => {};
void assertType;
import type { ContentRecordSchema } from "../schemas";
// ref: unionCalculationSyntax.ts - a union attribute selects through `{ member: [fields] }`.
const sel = ["id", "category", "title", "type", "thumbnailUrl", "thumbnailAlt", "publishedAt", { item: [{ article: ["id", "heroImageAlt"] }] }] satisfies UnifiedFieldSelection<ContentRecordSchema>[];
declare const r: InferResult<ContentRecordSchema, typeof sel>;
export const category: "fitness" | "mindset" | "nutrition" | "progress" = r.category;
export const item = r.item;
