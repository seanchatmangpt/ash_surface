import type { InferResult, UnifiedFieldSelection } from "../schemas";
type Eq<A, B> = (<T>() => T extends A ? 1 : 2) extends (<T>() => T extends B ? 1 : 2) ? true : false;
const assertType = <_T extends true>() => {};
void assertType;
import type { CreateContentConfig, InferCreateContentResult } from "../schemas";
// ref: argsWithFieldConstraints.ts - create action whose typed-map argument (`item`) and constrained `category` are typed.
export const basic: CreateContentConfig = {
  fields: ["id", "title", "category"],
  args: { title: "Getting Started", thumbnailUrl: "t.jpg", thumbnailAlt: "t", userId: "u", item: { heroImageUrl: "h", heroImageAlt: "a", summary: "s", body: "b" } },
};
export const allOptionals: CreateContentConfig = {
  fields: ["id", "title", "type", "publishedAt", "authorId"],
  args: { type: "article", title: "t", thumbnailUrl: "t", thumbnailAlt: "t", publishedAt: "2025-01-15T10:00:00Z", category: "mindset", authorId: "a", userId: "u", item: { heroImageUrl: "h", heroImageAlt: "a", summary: "s", body: "b" } },
};
declare const withAuthor: InferCreateContentResult<["id", "title", "category", { author: ["id", "name", "email"] }]>;
export const category: "fitness" | "mindset" | "nutrition" | "progress" = withAuthor.category;
export const authorName: string | undefined = withAuthor.author?.name;
// @ts-expect-error category is a closed enum
export const badCategory: CreateContentConfig = { fields: ["id"], args: { title: "t", thumbnailUrl: "t", thumbnailAlt: "t", userId: "u", category: "cooking", item: { heroImageUrl: "h", heroImageAlt: "a", summary: "s", body: "b" } } };
// @ts-expect-error typed-map member `body` is required
export const missingMember: CreateContentConfig = { fields: ["id"], args: { title: "t", thumbnailUrl: "t", thumbnailAlt: "t", userId: "u", item: { heroImageUrl: "h", heroImageAlt: "a", summary: "s" } } };
