# Wave 3 Lane RT Receipt

Standing: PARTIAL

Fix of SK-fw2 defect 1 (pascal double-format of response_zod keys). Non-vacuity red run
BLOCKED: the scratch copy (explicit-path tar to /tmp/rt) was refused by the permission
system, so the double-emit reintroduction was not run; no red evidence (UNVERIFIED).

## Root cause and fix

- `record_schema.ex`: `wire_name/2` already formats once, but only mapped names were marked
  `"wire" => true`, so `EmbeddedSchema` re-ran `FieldName.emitted/1`. Now every record field
  and relationship is marked wire (emission at the record layer; embedded resources reached
  directly still emit once in EmbeddedSchema).
- Same class found by sweep: `validation_error` (ir.ex + validation_error_schema.ex) ran
  `ErrorFormatter` camel on already-wired top-level names (`__x` became `X`) and left nested
  names raw (`urlId`, `isActive?`). ir.ex now marks top-level inputs wire and passes
  `formatter: &FieldName.emitted/1`; `object_body` honours `"wire"`.

## Court

`test/ash_surface/compiler/formatter_single_emission_test.exs`: real resources (url_id,
is_active?, éa_b, id2_x, __x; embedded, typed map, union, calculation, relationship, sortable
resource), compiled per formatter (pascal, snake, camel, custom {m,f}), projected to .mjs,
run in node+zod: response, create input (key bound by type), filter, sort, selection,
calculations load/result, relationship load, validation_error (incl. nested) accept payloads
spelled as IR `facts["field_names"]` and refuse internal spelling; standalone embedded/
typed-map/route renderers checked. Channel payload and route args render via EmbeddedSchema
with raw names (single emission by construction; route only weakly asserted).

## Commands (MIX_BUILD_ROOT=_build-rt)

- court file: 8 tests, 0 failures.
- `mix test test/ash_surface/compiler test/ash_surface/divergence_close test/ash_surface/ported/top`:
  737 tests, 0 failures, 16 skipped, rc=0 (un-piped).
- `mix ash_surface.parity.tests`: rc=0 (unaccounted=0 broken=0).
- IR digest and conformance not regenerated (will move).

Disclosure: none of RU's files edited. Build root deleted at finish.
