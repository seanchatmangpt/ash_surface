# wave3-cw

Standing: PASS

Lane CW fix of CT findings in `lib/ash_surface/compiler/route_schema/fold.ex`.

- Allowed key set is per kind: `Ash.Type.constraints/1` of the resolved Ash type (kind table
  `@ash_types`) plus fold-injected keys (`match_flags`; array `min_items`/`max_items`/
  `unique_items?`). Kinds with no Ash type (ltree, enum) keep key-shape-only checks.
- CT false refusals now admitted: string/ci_string `length_count`, atom `unsafe_to_atom?`,
  map/struct `preserve_nil_values?`, utc_datetime `cast_dates_as`/`timezone`, duration
  `signs`/`units`.
- CT false admissions now refused with typed
  `{:invalid_argument_constraints, route, arg, key, reason}`: integer match/casing/one_of:5/
  items/storage_type; boolean min_items/precision; array min_items:-5, max_items:"x",
  unique_items?:"no". Wrong-kind keys give `:not_applicable`; bad values give value reasons.
- Extra probes (CT did not): decimal (numeric or numeric-string bounds, int precision/scale),
  float (`scale`/`precision` refused, bounds numeric), array item constraints per item kind.
  `__proto__`/`constructor` refused `:unknown_constraint` on 9 kinds.
- Tests: 6 added to `test/ash_surface/ported/typed_controller/fold_argument_constraints_test.exs`.
- Command: `MIX_BUILD_ROOT=_build-cw mix test test/ash_surface/ported/typed_controller`
  (output redirected to file, rc captured un-piped) -> rc=0, 101 tests, 0 failures, 13 skipped.
