import type { InferResult, UnifiedFieldSelection } from "../schemas";
type Eq<A, B> = (<T>() => T extends A ? 1 : 2) extends (<T>() => T extends B ? 1 : 2) ? true : false;
const assertType = <_T extends true>() => {};
void assertType;
import type { UpdateTodoWithUntypedDataConfig, InferUpdateTodoWithUntypedDataResult } from "../schemas";
// ref: untypedMaps.ts - untyped map arguments accept arbitrary nested JSON; the untyped map result is Record<string, any>.
export const basic: UpdateTodoWithUntypedDataConfig = { fields: ["id", "customData"], args: { additionalData: { stringValue: "test", numberValue: 42, booleanValue: true, nullValue: null } } };
export const nested: UpdateTodoWithUntypedDataConfig = { fields: ["id", "title", "customData"], args: { additionalData: { nested: { level2: { level3: "deep" } }, arrayOfObjects: [{ id: 1, name: "Item 1" }] }, metadataUpdate: { version: "2.0", timestamp: 1 } } };
export const without: UpdateTodoWithUntypedDataConfig = { fields: ["id", "customData"], args: { additionalData: { simpleKey: "v" } } };
declare const r: InferUpdateTodoWithUntypedDataResult<["id", "customData"]>;
export const customData: Record<string, any> | null = r.customData;
// @ts-expect-error an untyped map argument is an object, not a string
export const wrong: UpdateTodoWithUntypedDataConfig = { fields: ["id"], args: { additionalData: "no" } };
