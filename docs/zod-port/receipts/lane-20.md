# Lane 20 Receipt: conformance, docs, integration run

Standing: PARTIAL

Wait-gate: lanes 02..19 receipts present at start; lane-01 receipt landed during the run
(19/19 present at 19:03 PST). No IN-FLIGHT-AT-FILL lanes. Test runs happened after lane-01
code (`compiler/zod_type.ex`) was on disk.

## Files changed (lane 20)

- `conformance/js/reference.mjs`: rewrote the JS zod twin (`zodFragment` etc.) to the Zod 4
  table of `AshSurface.Compiler.ZodType` (was stale Zod 3 style; 6 constraint vectors failed).
- `conformance/vectors/*.json`, `conformance/MANIFEST.json`: regenerated with
  `scripts/conformance_regen.exs` (572 vectors, 12 files; `ir_codec.json` changed,
  `constraints.json` new). Second regen is byte-identical (MANIFEST sha256 equal).
- `docs/CONFORMANCE.md` (constraints row), `CHANGELOG.md` (Zod 4 port section),
  `README.md` (line 221, Zod 4 runtime), `TESTING.md` (counts/floor),
  `scripts/chicago_census.txt` (floor 1424; suite list regenerated from disk: 206 suites).
- Golden refreezes (tests, no lane owned them; lane 17 asked lane 20):
  `test/ash_surface/ir_test.exs`, `ir_codec_golden_test.exs` (new IR.Schema fields as JSON
  nulls; full digest 44d02330... -> 85e3b3ca...), `ash_section_truth_test.exs` (inputs carry
  `constraints/subtype_of/subtype_constraints`), `schema_section_test.exs` (typed array items,
  `.nullable()` without implicit `.optional()`).

## Commands and real exit codes

- `npm install` rc=0.
- `MIX_ENV=test mix run scripts/conformance_regen.exs` rc=0 (572 vectors / 12 files).
- `npm test` rc=0: 371 tests, 367 pass, 0 fail, 4 skipped.
- `MIX_BUILD_ROOT=_build-lane20 mix test` (full) rc=1 and NO summary line: the VM aborts at
  exit with `UndefinedFunctionError AuditTrail.Dsl.Event.__struct__/0` (module not available;
  the 14 `audit_trail_* / notification_extension_* / ash_a2a_* / ash_r2rml_*` court files
  depend on unmounted generated modules, `lib/generated` absent). A real count was therefore
  obtained by running the 166 other files: `48 doctests, 23 properties, 1424 tests,
  23 failures, 5 invalid`, rc=2 (run after the golden refreezes; those 4 suites were green).
- `mix test.zero` rc=1 (scrubbed `mix test.all` exit 1, same VM abort). It uses the default
  `_build`, not `_build-lane20`.
- `stale_claim_tripwire_test.exs`: 3 tests, 0 failures (README edit safe).
- `_build-lane20` deleted.

## Remaining failures, attribution (baseline run was denied by the permission system, so
"pre-existing" below is inferred from content, not measured)

- Lane 17 / 01 / 19 / 15 (create-schema output): `ts/zod_codegen_test` (constraints missing:
  `title: z.string().min(1).max(80)` absent, every field `.nullable()` only),
  `ts/zod_runtime_test` ("minimal valid" fails: omittable fields not `.optional()`),
  `projector/generated_artifacts_exec_test` x3 (`act_decimal must accept {"f":2}`, `nullable
  must accept {}`, uuid mutation not caught): optionality (`required?:false`/default ->
  `.optional()`) and ArgumentConstraints are not reaching the IR/emitted zod.
- Lane 09: `no_local_do_test` falsifier `lib/ash_surface/error_handler.ex: Kernel-style apply`.
- Lane 16: `no_local_do_test` falsifiers `installer/package_json.ex` and `installer/tsconfig.ex`
  (`Rewrite.Source.update` flagged as action-named call; needs an allowlist entry or rename).
- Lane 12: `ash_surface_verifier_court_test` / `ash_r2rml_verifier_court_test` non-vacuous
  court: "spec declares no aex:Verifier rows" (ontology.ttl edit; resource.ex not regenerated
  via ggen, per lane-12 Request to coordinator). `formatter_registration_canary_test` x2
  (`unknown_module?(AshSurface.Resource)` false; decorative-subject scan finds nothing) is
  probably the same unregenerated-resource state (UNVERIFIED).
- Likely pre-existing / environmental (UNVERIFIED): `ash_surface_igniter_idempotence_court` x5
  and `ash_r2rml_igniter_idempotence_court` x5 ("Could not find module
  SparkClosureConsumer.Example.Post" in the scratch app; lane 16 did not re-run it);
  `ash_r2rml_verifier_court` happy path (AshR2RML data-layer transformer error);
  `path_truth_test`: TESTING.md lines 154/157/167/362/372/391 cite missing `~/xaas/.../plans/
  w901*/w984mf*`, `/tmp/ash_surface_court_quarantine/`, `lib/generated` (TESTING.md was
  unmodified at those lines).
- The 14 withheld court files (ash_a2a/ash_r2rml/audit_trail/notification_extension) crash the
  VM at exit; their results are not counted in 1424.

## Requests

- Lane 17/01: wire argument constraints and optionality (`.optional()`) into the IR zod used by
  `Compiler.Schema` create/update blocks; see failing ts and generated_artifacts_exec tests.
- Lane 09: replace `apply/3` use in `error_handler.ex` or add a reasoned allowlist entry.
- Lane 16: no_local_do allowlist/rename for `Rewrite.Source.update` in installer files.
- Lane 12 / coordinator: regenerate `lib/ash_surface/resource.ex` via ggen; re-run verifier
  courts and formatter canary.
- Coordinator: decide the 14 withheld court files (VM abort hides the mix summary, so the
  census floor check in `zero_config_v2.sh` cannot read a count); fix `path_truth` citations in
  TESTING.md.

## Falsifiers

- Floor 1424 is the sum over 166 files only; if the withheld files start reporting, re-measure.
- The refrozen IR digest comes from the current implementation; a later IR change must refreeze.
