import type { InferResult, UnifiedFieldSelection } from "../schemas";
type Eq<A, B> = (<T>() => T extends A ? 1 : 2) extends (<T>() => T extends B ? 1 : 2) ? true : false;
const assertType = <_T extends true>() => {};
void assertType;
import type { TodoSchema, CreateTodoConfig } from "../schemas";
// ref: customTypes.ts - custom type selection (priorityScore -> number, colorPalette -> object) and create input.
const sel = ["id", "title", "priorityScore", "colorPalette", "createdAt"] satisfies UnifiedFieldSelection<TodoSchema>[];
declare const r: InferResult<TodoSchema, typeof sel>;
export const score: number | null = r.priorityScore;
export const primary: string | undefined = r.colorPalette?.primary;
export const createdAt: string = r.createdAt;
export const createConfig: CreateTodoConfig = {
  fields: ["id", "title", "colorPalette", "createdAt"],
  args: { title: "Color Palette Todo", status: "pending", userId: "u", colorPalette: { primary: "#FF5733", secondary: "#33FF57", accent: "#3357FF" } },
};
// @ts-expect-error colorPalette input requires accent
export const badInput: CreateTodoConfig = { fields: ["id"], args: { title: "t", status: "s", userId: "u", colorPalette: { primary: "a", secondary: "b" } } };
