# Wave 3 lane S1-I: identity / selection / field-name defects

Standing: PASS

## Commands
- `MIX_BUILD_ROOT=_build-s1i mix test` (new s1i test, identity_schema, field_name,
  field_name_mapping, naming, relationship_selection_schema, relationship_load_behaviour,
  no_local_do) -> 56 tests, 0 failures, exit 0
- `mix format --check-formatted` on 4 changed files -> exit 0
- Wave-gate wave3-13.md was already Standing: PASS; no collision.
- _build-s1i deleted.

## Files changed
- lib/ash_surface/compiler/identity_schema.ex
- lib/ash_surface/compiler/selection_schema.ex
- lib/ash_surface/field_name.ex
- test/ash_surface/s1i_identity_selection_fieldname_test.exs (new; node+zod, real Ash Account)

## Fixed
- L1: non-identifier key renders as JSON-quoted property (executed under zod) instead of
  vanishing; embedded_resource/typed_struct/typed_map and untyped keys are non-scalar
  (not z.unknown()); colliding identity names -> `{:identity_name_collision, name, [declared]}`;
  primary key normalized via to_string.
- L6: relationships validated first (`{:invalid_relationship, rel}`); dotted name ->
  `{:relationship_name_ambiguous, name}`.
- L8: parse_input/2 documented (VM-atom existence, not admission); new
  `parse_input/3,4` admitted-set variant (also inverts custom formatters; /2 returns :error
  for custom); parse_sort("-") and parse_input("") -> :error; leading "_" preserved by
  camelize; new `format_checked/3` + client_to_internal detect non-invertible forward
  mappings (a__b vs a_b -> `{:not_invertible, field, client}`).

## Open
- Callers outside owned files (none found in lib/) were not switched to parse_input/3.
- Unquoted-key identities still pass through QuerySchema's identifier path unchanged.
- Existing "no_admitted_identities" skip for non-scalar kinds kept (pinned by prior test);
  it is the typed refusal, not a silent z.unknown().
