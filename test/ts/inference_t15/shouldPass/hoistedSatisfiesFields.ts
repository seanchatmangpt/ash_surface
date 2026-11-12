import type { InferResult, UnifiedFieldSelection } from "../schemas";
type Eq<A, B> = (<T>() => T extends A ? 1 : 2) extends (<T>() => T extends B ? 1 : 2) ? true : false;
const assertType = <_T extends true>() => {};
void assertType;
import type { TodoSchema } from "../schemas";
// ref: hoistedSatisfiesFields.ts - selections hoisted into consts with `satisfies` keep typed-map / union / relationship inference.
const tm = ["id", { options: ["priority"] }, { user: ["name"] }] satisfies UnifiedFieldSelection<TodoSchema>[];
declare const r1: InferResult<TodoSchema, typeof tm>;
export const userName: string = r1.user.name;
export const priority: number | undefined = r1.options?.priority;
const two = ["id", { options: ["priority"] }, { statistics: ["viewCount"] }, { user: ["name"] }] satisfies UnifiedFieldSelection<TodoSchema>[];
declare const r2: InferResult<TodoSchema, typeof two>;
export const viewCount: number | null | undefined = r2.statistics?.viewCount;
const un = ["id", { content: ["note"] }, { user: ["name"] }] satisfies UnifiedFieldSelection<TodoSchema>[];
declare const r3: InferResult<TodoSchema, typeof un>;
export const note = r3.content;
const members = ["id", { content: [{ text: ["text", "wordCount"] }, { checklist: ["title"] }] }, { user: ["name"] }] satisfies UnifiedFieldSelection<TodoSchema>[];
declare const r4: InferResult<TodoSchema, typeof members>;
export const content = r4.content;
// hoisted through a const-generic identity helper
const tupleFields = <const F extends UnifiedFieldSelection<TodoSchema>[]>(f: F): F => f;
const HOISTED = tupleFields(["id", { options: ["priority"] }, { user: ["name"] }]);
declare const r5: InferResult<TodoSchema, typeof HOISTED>;
export const hoistedId: string = r5.id;
export const hoistedUser: string = r5.user.name;
