import type { UnifiedFieldSelection } from "../schemas";
import type { TodoSchema } from "../schemas";
// ref: shouldFail/nestedQueryOpts.ts - nested relationship query envelope: filter/sort/page capability gating.
type Sel = UnifiedFieldSelection<TodoSchema>[];
export const filterDisabled: Sel = [
  "id",
  // @ts-expect-error filter is not offered when the relationship has no filter input
  { unfilterableComments: { filter: { rating: { greaterThan: 2 } }, fields: ["id"] } },
];
export const sortDisabled: Sel = [
  "id",
  // @ts-expect-error sort is not offered when the relationship has no sortable field
  { unsortableComments: { sort: "-rating", fields: ["id"] } },
];
export const pageUnpaginated: Sel = [
  "id",
  // @ts-expect-error relationship read action has no pagination
  { unpaginatedComments: { page: { limit: 1 }, fields: ["id"] } },
];
export const envelopeOnToOne: Sel = [
  "id",
  // @ts-expect-error to-one relationships take a plain field list
  { user: { limit: 1, fields: ["id"] } },
];
export const envelopeOnEmbedded: Sel = [
  "id",
  // @ts-expect-error embedded maps take a plain field list
  { meta: { limit: 1, fields: ["k"] } },
];
export const filterWrongField: Sel = [
  "id",
  // @ts-expect-error bogusField is not a filter field of the relationship
  { comments: { filter: { bogusField: { eq: 1 } }, fields: ["id"] } },
];
export const sortWrongField: Sel = [
  "id",
  // @ts-expect-error bogusField is not a sort field of the relationship
  { comments: { sort: "-bogusField", fields: ["id"] } },
];
export const pageMixedFamilies: Sel = [
  "id",
  // @ts-expect-error offset (offset family) and after (keyset family) are exclusive
  { comments: { page: { offset: 0, after: "cursor" }, fields: ["id"] } },
];
export const pageWithLimit: Sel = [
  "id",
  // @ts-expect-error page and bare limit are mutually exclusive
  { comments: { page: { limit: 2 }, limit: 3, fields: ["id"] } },
];
export const pageWithOffset: Sel = [
  "id",
  // @ts-expect-error page and bare offset are mutually exclusive
  { comments: { page: { limit: 2 }, offset: 1, fields: ["id"] } },
];
export const keysetKeysOnOffsetOnly: Sel = [
  "id",
  // @ts-expect-error after is a keyset key; the relationship is offset-only
  { offsetComments: { page: { limit: 2, after: "cursor" }, fields: ["id"] } },
];
export const offsetKeysOnKeysetOnly: Sel = [
  "id",
  // @ts-expect-error offset is an offset key; the relationship is keyset-only
  { keysetComments: { page: { limit: 2, offset: 1 }, fields: ["id"] } },
];
export const missingFields: Sel = [
  "id",
  // @ts-expect-error fields is required inside a query envelope
  { comments: { limit: 2 } },
];
export const validEnvelope: Sel = [
  "id",
  { comments: { filter: { rating: { greaterThan: 2 } }, sort: "-rating", page: { limit: 2 }, fields: ["id"] } },
];
