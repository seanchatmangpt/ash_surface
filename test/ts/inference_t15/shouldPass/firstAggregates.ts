import type { InferResult, UnifiedFieldSelection } from "../schemas";
type Eq<A, B> = (<T>() => T extends A ? 1 : 2) extends (<T>() => T extends B ? 1 : 2) ? true : false;
const assertType = <_T extends true>() => {};
void assertType;
import type { TodoSchema } from "../schemas";
// ref: firstAggregates.ts - a `first` aggregate over a TypedMap-shaped record selects attributes, nested typed maps, datetime and collection members.
const a = ["id", "title", { firstCommentMetadata: ["category", "priorityScore", "isUrgent"] }] satisfies UnifiedFieldSelection<TodoSchema>[];
declare const ra: InferResult<TodoSchema, typeof a>;
export const category: string | undefined = ra.firstCommentMetadata?.category;
export const score: number | null | undefined = ra.firstCommentMetadata?.priorityScore;
const n = ["id", { firstCommentMetadata: ["category", { settings: ["notifications", "autoArchive", "reminderFrequency"] }] }] satisfies UnifiedFieldSelection<TodoSchema>[];
declare const rn: InferResult<TodoSchema, typeof n>;
export const notifications: boolean | null | undefined = rn.firstCommentMetadata?.settings?.notifications;
const all = ["id", { firstCommentMetadata: ["id", "category", "priorityScore", "deadline", "tags", "creatorId", "createdAt", "estimatedHours"] }] satisfies UnifiedFieldSelection<TodoSchema>[];
declare const rall: InferResult<TodoSchema, typeof all>;
export const hours: number | null | undefined = rall.firstCommentMetadata?.estimatedHours;
export const tag0: string | undefined = rall.firstCommentMetadata?.tags?.[0];
// @ts-expect-error an unselected member of the first-aggregate record is absent
export const hidden = ra.firstCommentMetadata?.deadline;
