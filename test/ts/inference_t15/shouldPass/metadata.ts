import type { InferResult, UnifiedFieldSelection } from "../schemas";
type Eq<A, B> = (<T>() => T extends A ? 1 : 2) extends (<T>() => T extends B ? 1 : 2) ? true : false;
const assertType = <_T extends true>() => {};
void assertType;
import type { InferReadTasksWithMetadataResult, ReadTasksWithMetadataMetadata } from "../schemas";
// ref: metadata.ts - read actions expose selected metadata fields next to selected record fields.
declare const all: InferReadTasksWithMetadataResult<["id", "title"], ["someString", "someNumber", "someBoolean"]>;
export const metaString: string = all[0].someString;
export const metaNumber: number = all[0].someNumber;
export const metaBool: boolean | null = all[0].someBoolean;
declare const some: InferReadTasksWithMetadataResult<["id", "title", "completed"], ["someString"]>;
export const only: string = some[0].someString;
// @ts-expect-error someNumber was not requested
export const notRequested = some[0].someNumber;
declare const none: InferReadTasksWithMetadataResult<["id", "title", "completed"]>;
export const completed: boolean = none[0].completed;
// @ts-expect-error no metadata requested
export const noMeta = none[0].someString;
export const keys: keyof ReadTasksWithMetadataMetadata = "someString";
// @ts-expect-error unknown metadata name is rejected
export const badKey: keyof ReadTasksWithMetadataMetadata = "nope";
