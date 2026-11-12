import type { InferResult, UnifiedFieldSelection } from "../schemas";
type Eq<A, B> = (<T>() => T extends A ? 1 : 2) extends (<T>() => T extends B ? 1 : 2) ? true : false;
const assertType = <_T extends true>() => {};
void assertType;
import type { TodoSchema } from "../schemas";
// ref: complexScenarios.ts "Test 7" - mixed relationships, aggregates, custom types, nested self calc.
const sel = [
  "id", "title", "status", "isOverdue", "commentCount", "helpfulCommentCount", "colorPalette",
  { user: ["id", "email"], comments: ["id", "content", { user: ["id", "name"] }] },
  {
    self: {
      args: { prefix: "complex_" },
      fields: [
        "id", "description", "priority", "helpfulCommentCount", "colorPalette",
        { user: ["id", "name", "email"], comments: ["id", "authorName", "rating"] },
        {
          self: {
            args: { prefix: "complex_nested_" },
            fields: ["tags", "createdAt", "colorPalette", { meta: ["category", "isUrgent"], comments: ["id", "isHelpful", { user: ["id"] }] }],
          },
        },
      ],
    },
  },
] satisfies UnifiedFieldSelection<TodoSchema>[];
declare const r: InferResult<TodoSchema, typeof sel>;
export const topOverdue: boolean | null | undefined = r.isOverdue;
export const topCount: number = r.commentCount;
export const palette: { primary: string; secondary: string; accent: string } | null = r.colorPalette;
export const selfDays: number = r.self.helpfulCommentCount;
export const selfPalette: { primary: string; secondary: string; accent: string } | null = r.self.colorPalette;
export const nestedTags: string[] | null = r.self.self.tags;
export const nestedHelpful: boolean | null = r.self.self.comments[0].isHelpful;
export const nestedUserId: string = r.self.self.comments[0].user.id;
// @ts-expect-error unselected field is absent from the inferred result
export const notSelected = r.hasComments;
