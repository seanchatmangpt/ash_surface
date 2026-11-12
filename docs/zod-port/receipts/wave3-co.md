# Wave 3 Lane CO Receipt (I19 verify.ex count)

Standing: UNVERIFIED

Coordinator note: the lane did not write this file; the coordinator transcribed the lane's final
report. Nothing below was re-run by the coordinator.

## Result

`lib/ash_surface/verify.ex` already says "enforces 8"; no file changed.

- `ontology.ttl` has 8 `aex:Verifier` rows (lines 312-354); a raw grep shows 9 because one comment
  also contains the string.
- Template `verify.ex.tmpl` computes `enforces {{ verifiers | length }}`.
- `ggen sync run --skip-ea-admission` in scratch `/tmp/co-ggen-scratch` (copies of ggen.toml,
  ggen.lock, ontology.ttl, templates, semantic, fixture, .ggen-v2) renders "enforces 8"; the only
  diffs against the repo file are blank lines and one line wrap.

## Commands

- `MIX_BUILD_ROOT=_build-co mix test test/ash_surface_verifier_court_test.exs
  test/ash_surface/ontology_enforced_by_test.exs`: 9 tests, 0 failures. Exit code not captured
  (piped through tail), so UNVERIFIED.
- Output carried a compile-time warning trace from
  `Specimen.UnknownActionProjection.__verify_spark_dsl__/1`; not investigated.

## Cleanup

`_build-co` and the scratch directory deleted.

## See Also

`wave3-09.md`
