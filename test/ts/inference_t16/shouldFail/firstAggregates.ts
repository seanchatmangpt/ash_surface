import type { UnifiedFieldSelection, InferResult } from "../schemas";
import type { TodoSchema } from "../schemas";
// ref: shouldFail/firstAggregates.ts - first-aggregate TypedMaps expose attributes only; calculations are not selectable.
export const cannotSelectSimpleCalculation: UnifiedFieldSelection<TodoSchema>[] = [
  "id",
  // @ts-expect-error displayCategory is a calculation, not an attribute of CommentMetadata
  { firstCommentMetadata: ["category", "displayCategory"] },
];
export const cannotSelectBooleanCalculation: UnifiedFieldSelection<TodoSchema>[] = [
  "id",
  // @ts-expect-error isOverdue is a calculation, not an attribute of CommentMetadata
  { firstCommentMetadata: ["category", "isOverdue"] },
];
export const cannotSelectCalculationWithArgs: UnifiedFieldSelection<TodoSchema>[] = [
  "id",
  // @ts-expect-error adjustedPriority (calculation with args) is not in the attributes-only map
  { firstCommentMetadata: ["priorityScore", { adjustedPriority: { args: { urgencyMultiplier: 1.5 }, fields: true } }] },
];
export const cannotSelectFormattedSummary: UnifiedFieldSelection<TodoSchema>[] = [
  "id",
  // @ts-expect-error formattedSummary (calculation with args) is not in the attributes-only map
  { firstCommentMetadata: ["category", { formattedSummary: { args: { format: "detailed" }, fields: true } }] },
];
export const attributesAreSelectable: UnifiedFieldSelection<TodoSchema>[] = [
  "id",
  { firstCommentMetadata: ["category", "priorityScore"] },
];
