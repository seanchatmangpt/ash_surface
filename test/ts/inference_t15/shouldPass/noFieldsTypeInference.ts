import type { InferResult, UnifiedFieldSelection } from "../schemas";
type Eq<A, B> = (<T>() => T extends A ? 1 : 2) extends (<T>() => T extends B ? 1 : 2) ? true : false;
const assertType = <_T extends true>() => {};
void assertType;
import type { InferCreateUserResult, InferUpdateUserResult } from "../schemas";
// ref: noFieldsTypeInference.ts - actions without field selection infer an empty result; with fields they infer the selection.
type Rn = InferCreateUserResult<[]>;
assertType<Eq<Rn, {}>>();
export const empty: Rn = {};
declare const withFields: InferCreateUserResult<["id", "name"]>;
export const id: string = withFields.id;
export const name: string = withFields.name;
// @ts-expect-error email was not selected
export const email = withFields.email;
declare const upd: InferUpdateUserResult<[]>;
// @ts-expect-error empty selection has no id
export const nothing = upd.id;
