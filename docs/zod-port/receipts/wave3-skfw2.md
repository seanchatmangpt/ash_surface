# Wave 3 Lane SK-fw2 Receipt

Standing: PARTIAL

Read-only re-audit of RN/RO/RP. Scratch /tmp/skfw2 (explicit-path tar, deps and node_modules
symlinked, `MIX_BUILD_ROOT=_build-sk` inside the scratch tree). Probes /tmp/skfw2/p/*.exs, n.mjs.
Not run: RN collision cases (calc args, destination-only, aggregates, identity keys): UNVERIFIED.

## Failing inputs (real output)

1. Pascal response schema double-formats keys. Resource with `url_id`, `is_active?`, `éa_b`,
   `id2_x` compiled with `output_field_formatter: :pascal_case`: IR facts field_names say
   `UrlId`, `IsActive`, `ÉaB`, `Id2X`; emitted `response_zod` keys are `Urlid`, `Isactive`,
   `Éab`, `Id2x` (`embedded_schema.ex` field_key calls `FieldName.emitted/1` on an already
   wire-named field; pascal camelize is not idempotent). Node+zod: payload keyed by facts
   spelling fails `Urlid:invalid_type ... unrecognized_keys`. camel, snake, custom `{m,f}`
   (upcase) parse client-spelled payloads and reject internal-spelled ones.
2. `Errors.to_errors(resource: R)` ignores the `with_formatter` scope: under pascal, snake and
   custom scope, `fields`/`path`/`vars.field` stay camel (`urlId`, `isActive`, `__x`, `éaB`)
   while schema keys are `UrlId`/`url_id`/`URL_ID`. Path segments after the first are `a1`
   for `:a_1` (schema key `A1`/`a_1`). Explicit `formatter: :snake_case` opt does match.
3. Scope is process-local: `Task.async` inside `with_formatter(:snake_case)` sees
   `scoped_formatter() == nil`, `wire(R, :url_id) == "urlId"`, and `Rpc.parse` in that Task
   accepts camel `createdAt` (`check_scoped_spellings` bypassed).
4. Nested paths still lenient: snake and pascal scope accept `%{"user" => ["isSuperAdmin"]}`
   and the other spelling alike; snake scope accepts camel filter/sort keys.

## Held

Scope restored after raise, throw, exit and an unsupported formatter; nested compile scope
restores the outer value.
