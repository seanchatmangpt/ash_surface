# L23-identities-tenant

Lane L23 (v26.11.11): get-by/identities + multitenancy parity with ash_typescript.

## Parity subject

ash_typescript exposes identity-based reads (`get?`/`get_by`) and
`require_tenant_parameters`. L23 makes both executable as pure zod renderers in
`AshSurface.Compiler.IdentitySchema`:

- `render_get_schema/2` — for each admitted identity, a
  `z.object({ ... }).strict()` over its key fragments (fragments from the
  shared `@zod_kinds` contract, byte-mirror of `Compiler.Schema` ↔
  `Projector.Expo.map_zod_type/1`). A get_by lookup becomes parseable
  admission: fields outside the identity (`.strict()`) or of the wrong shape
  (typed fragments) fail parse instead of silently selecting nothing. An
  identity whose keys equal the primary key is admitted under the name
  `primary_key` (the get-by spelling of `get?` by id).
- `render_tenant_schema/0` — `z.string().min(1)`, require_tenant_parameters
  made executable: an empty tenant string fails parse.

## Refusal terms

Empty or structurally inadmissible identity lists refuse with
`{:error, :no_admitted_identities}` — never a silently empty projection.

## Input shape

String-keyed manifest idioms:

    %{"name" => "email",
      "keys" => [%{"name" => "email", "type" => %{"kind" => "string"}}]}

## Scope

Pure renderers only: no projector integration, no manifest changes, no edits
to shared files (schema.ex / expo.ex). Evidence in
`docs/jira/v26.11.11/receipts/L23.md`.

## See Also

`lib/ash_surface/compiler/identity_schema.ex` · receipts/L23.md
