import type { InferResult, UnifiedFieldSelection } from "../schemas";
type Eq<A, B> = (<T>() => T extends A ? 1 : 2) extends (<T>() => T extends B ? 1 : 2) ? true : false;
const assertType = <_T extends true>() => {};
void assertType;
import type { InferListTodosResult, InferListTodoCommentsKeysetResult, ListTodosConfig } from "../schemas";
// ref: precisePaginationTypes.ts - the paginated result narrows by the page input actually passed.
declare const offset: InferListTodosResult<["id", "title"], { offset: 0; limit: 10 }>;
export const hasMore: boolean = offset.hasMore;
export const off: number = offset.offset;
export const type: "offset" = offset.type;
// @ts-expect-error offset pages carry no keyset cursor
export const offsetAfter = offset.after;
declare const afterPage: InferListTodosResult<["id", "title"], { after: "cursor123"; limit: 10 }>;
export const next: string | null = afterPage.nextPage;
export const ktype: "keyset" = afterPage.type;
// @ts-expect-error keyset pages carry no offset
export const koff = afterPage.offset;
declare const before: InferListTodosResult<["id", "title"], { before: "c"; limit: 10 }>;
export const prev: string | null = before.previousPage;
declare const limitOnly: InferListTodosResult<["id", "title"], { limit: 10 }>;
export const limitType: "keyset" = limitOnly.type;
declare const none: InferListTodosResult<["id", "title"]>;
export const first: string = none[0].id;
// @ts-expect-error unpaginated results are a plain array
export const noHasMore = none.hasMore;
declare const emptyPage: InferListTodosResult<["id", "title"], {}>;
export const emptyFirst: string = emptyPage[0].id;
declare const counted: InferListTodosResult<["id", "title"], { offset: 0; limit: 10; count: true }>;
export const count: number | null | undefined = counted.count;
declare const nested: InferListTodosResult<["id", "title", { user: ["id", "name"], comments: ["id", "content"] }], { offset: 0; limit: 5 }>;
export const nestedUser: string = nested.results[0].user.name;
export const nestedComment: string = nested.results[0].comments[0].content;
declare const keyset: InferListTodoCommentsKeysetResult<["id", "content"], { limit: 1; count: true }>;
export const kcount: number | null | undefined = keyset.count;
export const cfg: ListTodosConfig = { fields: ["id"], page: { offset: 0, limit: 10 } };
