import type { InferResult, UnifiedFieldSelection } from "../schemas";
type Eq<A, B> = (<T>() => T extends A ? 1 : 2) extends (<T>() => T extends B ? 1 : 2) ? true : false;
const assertType = <_T extends true>() => {};
void assertType;
import type { TaskStatsSchema } from "../schemas";
// ref: genericActionTypedStruct.ts - generic actions returning typed structs support field selection (single + array).
const some = ["totalCount", "completed"] satisfies UnifiedFieldSelection<TaskStatsSchema>[];
declare const one: InferResult<TaskStatsSchema, typeof some>;
export const totalCount: number | null = one.totalCount;
export const completed: boolean | null = one.completed;
// @ts-expect-error isUrgent was not selected
export const isUrgent = one.isUrgent;
// @ts-expect-error averageDuration was not selected
export const averageDuration = one.averageDuration;
const all = ["totalCount", "completed", "isUrgent", "averageDuration"] satisfies UnifiedFieldSelection<TaskStatsSchema>[];
declare const many: Array<InferResult<TaskStatsSchema, typeof all>>;
export const dur: number | null = many[0].averageDuration;
export const urgent: boolean | null = many[0].isUrgent;
