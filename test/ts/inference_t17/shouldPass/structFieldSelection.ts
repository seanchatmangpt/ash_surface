import type { InferResult, UnifiedFieldSelection, TodoSchema, UserSchema } from "../schemas";
type Eq<A, B> = (<T>() => T extends A ? 1 : 2) extends (<T>() => T extends B ? 1 : 2) ? true : false;
const assertType = <_T extends true>() => {};
void assertType;
// ref: structFieldSelection.ts tests 1-4 (bare `self: [..]` shorthand accepted for calculations with no required args, as in the reference) (struct calculation field selection, with args, nested, mixed).
const s1 = ["id", "title", { self: ["id", "title", "completed"] }] satisfies UnifiedFieldSelection<TodoSchema>[];
declare const r1: InferResult<TodoSchema, typeof s1>;
export const t1: string = r1.self.title;
export const t1c: boolean | null = r1.self.completed;
// @ts-expect-error description was not selected on self
export const t1bad = r1.self.description;

const s2 = ["id", "title", { self: { args: { prefix: "TEST" }, fields: ["id", "title"] } }] satisfies UnifiedFieldSelection<TodoSchema>[];
declare const r2: InferResult<TodoSchema, typeof s2>;
export const t2: string = r2.self.id;
// @ts-expect-error completed was not selected
export const t2bad = r2.self.completed;

const s3 = ["id", "name", { self: ["id", "name", { todos: ["id", "title"] }] }] satisfies UnifiedFieldSelection<UserSchema>[];
declare const r3: InferResult<UserSchema, typeof s3>;
export const t3: string = r3.self.todos[0].title;
// @ts-expect-error description was not selected on the nested todos
export const t3bad = r3.self.todos[0].description;

const s4 = ["id", "title", { user: ["id", "name"], self: ["id", "completed"] }] satisfies UnifiedFieldSelection<TodoSchema>[];
declare const r4: InferResult<TodoSchema, typeof s4>;
export const t4u: string = r4.user.name;
export const t4s: boolean | null = r4.self.completed;
// @ts-expect-error title not selected on self
export const t4bad = r4.self.title;
