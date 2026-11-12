# Wave 3 F1-unowned: unowned-defect triage

Standing: PARTIAL

PARTIAL because the four idempotence courts were bounded and one of six tests re-run (not the
full files), the filter_schema_size real-zod test is still moving (another lane), and the
extension-fixture cluster is classified PRE-EXISTING, not fixed. Tree was moving; no SHA bound.

## Per-defect table (MIX_BUILD_ROOT=_build-f1un, MIX_ENV=test, each file re-run alone first)

| defect | before | after | layer / evidence |
|---|---|---|---|
| zod_type_parity_test:6 | FAIL in census | PASS alone (3 tests) | fixed upstream by the kind lane; no edit |
| projectors_coverage_test:180,:189 | 2 fail, `{:error,{:unknown_resource,..}}` | 15 tests, 0 fail | substrate moved (wave3-s1h: unknown resource is a typed error; find_resource matches `"name"`/`"module"`). Fixture now carries the resource; neither-map-nor-list case re-pinned to the typed error; empty-fields passthrough kept as its own test |
| ash_surface_transformer_court_test:212 (determinism) | FAIL | 3 tests, 0 fail | persist.ex stores `resource: <draft module>` (pure fn of DSL state); two drafts necessarily differ by module name. Court now canonicalises the draft's own module atom before comparing; every other byte still compared |
| 4 idempotence courts >300s | TIMEOUT | legit slow, not hung: real `mix ash_surface.install` subprocesses, 175-580s per test at load avg ~120 (first test also seeds the build root). `System.cmd` now runs under `Task.yield(@install_deadline_ms)`/`Task.shutdown`, typed exit 124 on overrun; `@moduletag timeout: 720_000`, deadline 600_000, documented. No sleep | ash_surface court test at :90 PASS (307.9s); other three compile-checked (`--exclude test`, 0 errors), full-file runs UNVERIFIED |
| filter_schema_test:98 | FAIL | 8 tests, 0 fail | not a regression: `note` keeps the string catalog (incl. lt), same kind+op share one enum, so `["note","title"]` is correct. filter_schema.ex/test had no diff vs HEAD (pre-existing). Re-pinned |
| parity_deepen/schema_courts_test:172 (4) | FAIL | 57 tests, 0 fail | KD-05 (wave3-f1kd.md) keeps `z.unknown()` for map/keyword/tuple/struct; table re-pinned |
| g3_verifiers_test:109 (no Zod kind) | FAIL | PASS | premise moved: `:string` storage now derives z.string() (wave3-t8 KD-06). Opaque specimen storage -> `:some_unmappable_thing` |
| verify_mappable_types_surface_test (6) | FAIL | PASS | same premise move; BareCustomType storage re-pinned to un-derivable |
| type_mapping_overrides_test:79 | FAIL | PASS | same; split into derivable-storage-admitted and un-derivable-storage-refused (local OpaqueStorage type) |
| custom_type_schema_test (flaky once) | passes alone (14 tests, 73.9s) | PASS | cause not reproduced (UNVERIFIED); tmp dirs already pid+unique_integer, env scoped by T2.with_env, async false. Hardening: `@moduletag timeout: 600_000` (default 60s per test is exceeded under load) |
| filter_schema_size_test (2) | 2 fail early in run | 8 tests, 0 fail in two later runs; 1 fail (`real zod ...` [false,false]) once in a 440-test run | another lane re-pinned the oversize fixture to 600 relationships (measured 4,250,680 B at max_depth 3; 120 rels = 849,880 B now under the cap) and edited filter_schema.ex mid-run. Still moving: owner = the filter_schema.ex lane; re-run at quiescence |

## Extension-fixture cluster (15 files): PRE-EXISTING, not fixed

Evidence at HEAD: `git archive HEAD` export at /tmp/f1un-head with a copy of the build root
(`MIX_DEPS_PATH` = checkout deps): audit_trail_composition, ash_a2a_composition,
ash_r2rml_transformer_court, notification_extension_composition = 5 tests, 5 failures, rc=2
(`AshA2A.Dsl.Info` not available; AshR2RML Persist "active Ash data layer does not expose a
supported relational logical table"; transformer-source path not found). `git grep` at HEAD:
`AuditTrail.*` and `NotificationExtension.*` are defined nowhere in lib/ or deps/; the test
files landed in 68f77041b (withheld court battery) against pack code this repo does not carry.
Same failures on the current tree. Not small, not in scope: owner = pack-battery landing
(needs the packs' generated libs vendored or the files removed from this repo's test/).

## Commands and exit codes

- `MIX_ENV=test mix compile` (cold, _build-f1un): rc=0 after ~30 min under load
- 9-file batch (parity, projectors, transformer court, filter, schema_courts, g3, mappable,
  overrides, custom_type_schema): 126 tests, 0 failures, rc=0
- 440-test batch (compiler/, parity_deepen/, touched files): 1 failure (filter_schema_size real zod)
- no_local_do_test, no_local_do_bang_court_test, ash_surface_mock_discipline_test: 0 failures
- `grep Process.sleep` over the touched courts: 0 matches; no mocks introduced
- idempotence court :90: rc=0, 307.9s; HEAD cluster: rc=2, 5/5 fail

## Files changed (tests only; no lib/ edits)

test/ash_surface/projectors_coverage_test.exs, test/ash_surface_transformer_court_test.exs,
test/*_igniter_idempotence_court_test.exs (4), test/ash_surface/compiler/filter_schema_test.exs,
test/ash_surface/parity_deepen/schema_courts_test.exs, test/ash_surface/verifiers/g3_verifiers_test.exs,
test/ash_surface/ported/manifest/verify_mappable_types_surface_test.exs,
test/ash_surface/ported/top/type_mapping_overrides_test.exs,
test/ash_surface/ported/rpc/a/custom_type_schema_test.exs. `mix format` also normalised
whitespace in the court files that were unformatted at HEAD.

## Falsifiers

Any row above failing alone on a quiescent tree retracts that row; an idempotence court that
exits 124 means a real install hang, not slowness.

## See Also

[[wave3-f1tr]] · [[wave3-f1kd]] · [[wave3-opd2]] · [[wave3-t12]] · [[wave3-s1h]]
