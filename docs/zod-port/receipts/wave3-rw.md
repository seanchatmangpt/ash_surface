# Wave 3 Lane RW Receipt

Standing: PASS

Subject: `test/ash_surface/compiler/formatter_single_emission_test.exs` (RT court). Scratch
`/tmp/rw` (explicit-path tar, symlinked node_modules/deps, build root in scratch), simple
one-purpose commands, hook did not refuse. Live tree edited: the court file only (new tests).

## Part 1: RT double-emit mutations (scratch, baseline 8 tests green)

sha256 baseline == restore for every row (script prints equality).

| mutation | result | failures |
|---|---|---|
| M1 record_schema.ex `mark_wire` only for mapped names | RED (pascal only) | 2 of 8 |
| M2a ir.ex drop `"wire" => true` on top-level inputs | RED (pascal only) | 1 of 8 |
| M2b ir.ex drop `formatter: &FieldName.emitted/1` | RED (pascal, snake, camel, custom) | 4 of 8 |
| M3 validation_error_schema.ex ignore `wire?` | RED (pascal only) | 1 of 8 |

Survivors: none.

## Part 2: channel payload and route args

- Channel payload (EmbeddedSchema, typed_map + nested typed_map, url_id, is_active?, éa_b,
  id2_x, __x): single emission under formatter; no defect. New test per formatter (pascal,
  snake, camel, custom): payload spelled `FieldName.compute/2` accepted, internal spelling
  rejected where it differs, wrong-typed value per key (top and nested) rejected; node+zod.
- Route args (route_schema.ex `object/2`): keys are emitted VERBATIM, unformatted under every
  formatter (probe: pascal query keys `url_id`, `"is_active?"`). Not changed: these are the HTTP
  request surface (path template, query string, body) read by the user's controller and there
  is no ash_surface runtime consumer; formatting would desync the key from the router path
  param and fail the divergence law (no executed court shows ash_surface better). Pinned by a
  new test per formatter (raw accepted, formatted spelling rejected, wrong types rejected).
  Intent of raw route args is UNVERIFIED against ash_typescript; flagged for operator.

## Part 3: shim-court of the new tests (scratch, sha256 baseline == restore)

| mutation | new tests red |
|---|---|
| M4 embedded_schema.ex double emitted/1 | channel pascal (+2 older) |
| M5 embedded_schema.ex raw name, no formatting | channel pascal, snake, camel, custom |
| M6 route_schema.ex formats arg keys | route args x4 formatters |

## Gates (MIX_BUILD_ROOT=_build-rw, un-piped rc)

- court file live tree: 16 tests, 0 failures, rc=0.
- `mix ash_surface.parity.tests`: rc=0 (files=264 unaccounted=0 broken=0).
- Full suite not run (UNVERIFIED). No lib file touched; compiler/embedded_schema.ex and
  record_schema.ex untouched live. Build roots deleted.
