import type { InferResult, UnifiedFieldSelection, TodoSchema, UserSchema } from "../schemas";
type Eq<A, B> = (<T>() => T extends A ? 1 : 2) extends (<T>() => T extends B ? 1 : 2) ? true : false;
const assertType = <_T extends true>() => {};
void assertType;
// ref: testStructFieldSelection.ts - instance_of struct calculation supports field selection like a relationship.
const s1 = ["id", "title", { self: { args: { prefix: "TEST" }, fields: ["id", "title", "completed"] } }] satisfies UnifiedFieldSelection<TodoSchema>[];
declare const r1: InferResult<TodoSchema, typeof s1>;
export const id: string = r1.self.id;
export const done: boolean | null = r1.self.completed;
// @ts-expect-error description was not selected for self
export const bad1 = r1.self.description;

// ref: testWithoutArgs - empty args object is accepted.
const s2 = ["id", { self: ["id", "title"] }] satisfies UnifiedFieldSelection<TodoSchema>[];
declare const r2: InferResult<TodoSchema, typeof s2>;
export const t2: string = r2.self.title;
// @ts-expect-error completed was not selected
export const bad2 = r2.self.completed;

// explicit empty-args form stays accepted alongside the shorthand.
const s3 = ["id", { self: { args: {}, fields: ["id", "title"] } }] satisfies UnifiedFieldSelection<TodoSchema>[];
declare const r3: InferResult<TodoSchema, typeof s3>;
export const t3: string = r3.self.title;
