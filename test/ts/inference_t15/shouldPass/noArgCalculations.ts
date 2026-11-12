import type { InferResult, UnifiedFieldSelection } from "../schemas";
type Eq<A, B> = (<T>() => T extends A ? 1 : 2) extends (<T>() => T extends B ? 1 : 2) ? true : false;
const assertType = <_T extends true>() => {};
void assertType;
import type { TodoSchema } from "../schemas";
// ref: noArgCalculations.ts - calculations without arguments select like plain typed maps, incl. nested and mixed with arg calculations.
const basic = ["id", "title", { summary: ["viewCount", "editCount"] }] satisfies UnifiedFieldSelection<TodoSchema>[];
declare const rb: Array<InferResult<TodoSchema, typeof basic>>;
export const viewCount: number | null | undefined = rb[0].summary?.viewCount;
const nested = ["id", { summary: ["viewCount", "completionTimeSeconds", { performanceMetrics: ["focusTimeSeconds", "efficiencyScore"] }] }] satisfies UnifiedFieldSelection<TodoSchema>[];
declare const rn: InferResult<TodoSchema, typeof nested>;
export const focus: number | undefined = rn.summary?.performanceMetrics?.focusTimeSeconds;
const all = ["id", { summary: ["viewCount", "editCount", "difficultyRating", "allCompleted", { performanceMetrics: ["interruptionCount", "taskComplexity"] }] }] satisfies UnifiedFieldSelection<TodoSchema>[];
declare const ra: InferResult<TodoSchema, typeof all>;
export const allCompleted: boolean | null | undefined = ra.summary?.allCompleted;
export const complexity: string | null | undefined = ra.summary?.performanceMetrics?.taskComplexity;
const mixed = ["id", { summary: ["viewCount"], self: { args: { prefix: "test" }, fields: ["title", "completed"] } }] satisfies UnifiedFieldSelection<TodoSchema>[];
declare const rm: InferResult<TodoSchema, typeof mixed>;
export const selfTitle: string = rm.self.title;
export const selfCompleted: boolean | null | undefined = rm.self.completed;
// @ts-expect-error unselected summary member is absent
export const hidden = ra.summary?.completionTimeSeconds;
