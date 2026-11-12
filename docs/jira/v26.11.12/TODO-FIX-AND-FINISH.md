# TODO-FIX-AND-FINISH (ash_surface)

Standing: UNVERIFIED

To-do index built from `docs/jira/v26.11.11/PARITY-WAVE3-QUEUE.md` and lane receipts in
`docs/zod-port/receipts/`. Receipt claims were not all re-run; confirmed = file read this lane.

Stop condition: `mix ash_surface.parity` exits 0 (task file exists at
`lib/mix/tasks/ash_surface.parity.ex`; Q1 lane still IN FLIGHT, exit code not observed here).

Divergence law: divergence from ash_typescript is acceptable only if ash_surface implements
something better, witnessed by an executed court. Otherwise implement to parity.

## Fix

- MED wave2-js: 4 schemas-runner failures, `read must reject` accepts uuid input
  (`compiler/zod_type.ex`); UNVERIFIED if still red. Check: `mix test test/js` green.
- MED wave2-js: GeneratedArtifactsExecTest tanstack/client shim lacks runtime .mjs copy
  (`test/ash_surface/projector/generated_artifacts_exec_test.exs`). Check: that file passes.
- MED wave3-07: validator must refuse unknown `show_metadata` / non-keyword
  `metadata_field_names` (`resource/validator.ex`). Check: un-skipped KD tests in
  `test/ash_surface/metadata_projection_test.exs` pass.
- MED wave3-07: `persist.ex` compiled state lacks `resource:` dsl module; pinned-bug tests need
  flipping. Check: the un-skipped desired-behavior test passes.
- LOW wave3-09: `lib/ash_surface/verify.ex` docstring says "enforces 8" (stale count).
  Check: docstring matches generator output.
- LOW wave3-10: `validator_action_types_test.exs` unformatted.
  Check: `mix format --check-formatted` exits 0.
- LOW wave3-08: `projectors/js/inference.ex` fails `mix format --check-formatted`. Check: exits 0.
- MED wave3-18: conformance `corpusVersion` and `c/match-backslash` vector unreconciled.
  Check: `conformance/js` replay passes with matching MANIFEST.
- MED wave2-zt: goldens containing `.regex(` backslashes, `.min(1)`, `.gt/.lt` need regeneration
  (`scripts/conformance_regen.exs`). Check: `ir_codec_golden_test.exs` green.
- Regression guard from R1: embedded cycle and defaults-vs-required re-check in S2 courts.
  Check: executed court under node with real zod.

## Finish

- Q1 `mix ash_surface.parity` (IN FLIGHT: Q1), Q2 shim-court non-vacuity (IN FLIGHT: Q2).
- Parity debts (must implement or upgrade with better-impl court):
  - w3-09: `type_name`/`field_names`/`argument_names`, domain `namespace`, nested selection in
    typed_query `fields` (F1-typedq).
  - S1-F: `uuid`/`naive_datetime` strictness, `limit_entry` required-limit.
  - S1-A: M5 per-calculation arg binding.
  - S1-H: path/query arg coercion.
  - w3-07: nine `verify_action_types/*` files.
  - w3-12: `zod_object_mode` consumer (only `config/verifier.ex:37` reads it; confirmed).
  - w3-15: `FieldName` wiring into compiler; per-action mapped-name consts.
- wave2-cf: `zod_import_into_generated`, `error_handler`, `error_output_formatter`,
  `show_raised_errors` validated but consumer unconfirmed. Check: grep shows a generator reader.
- wave2-er/id/em: renderers not routed (ErrorSchema.carry, identities in IR, container kinds via
  `EmbeddedSchema.render/2`); UNVERIFIED whether wave3 wired them. Check: projector court.
- wave2-js: package.json exports for `./http-transport`, `./channel-transport` undecided.
- Idempotence court green path needs fixture (wave2-cf, w3-16 IN FLIGHT).
- IN FLIGHT at write time: w3-01, w3-04, w3-11, w3-16, w3-19, w3-20, b1a-successor,
  S1-B, S1-C, S1-D, S1-F, S1-G, S1-H, Q1, Q2 (no receipt in `docs/zod-port/receipts/`).
- S1 register still READY/undispatched per queue: S1-B, C, D, F, G, H.

## Commit hygiene

Large untracked surface (CI-red risk on fresh checkout); stage explicit paths, never `git add -A`:
- `lib/ash_surface/{config,domain,envelope,errors,error_formatter,error_handler}*`,
  `field_name*`, `naming.ex`,
  `lib/ash_surface/compiler/*_schema.ex`, `zod_type.ex`, `type_facts.ex`, `parity/`, `installer/`,
  `lib/mix/tasks/ash_surface.parity.ex`. Check: `git status --short lib | grep '??'` empty.
- `priv/static/ash_surface_{http,channel}_transport.mjs`, `conformance/js/zod_eval.mjs`,
  `conformance/vectors/constraints.json`, `docs/KNOWN_DIVERGENCES.md`, `docs/zod-port/`.
- `test/support/{channel_fixtures,zod_fixtures}*`, `test/ash_surface/fixtures/`, `test/ts/`,
  `test/js/*_runner.mjs`; tracked tests reference these. Check: fresh clone `mix test` compiles.
- Lane build roots `_build-*` (about 18 dirs) are leases: delete before final commit.
  Check: `ls -d _build-*` empty.
- Known: `zod_guard_test.exs` untracked (R24 D-L24-2). Check: `git ls-files` lists it.
- `PARITY-REGISTER.md` rows pre-date wave 3 (Filters/Calculations/Aggregates marked MISSING).

## Decide

- package.json exports map vs file-copy-only for transport runtimes (wave2-js).
- Which parity debts upgrade to "better" vs implement-to-parity (divergence law).
- Enum order sorted vs source order (wave2-zt note).

## Reuse

- `ash_a2a/lib/ash_a2a/schema.ex` for_action/build typed unserializable errors.
- `ash_a2a/lib/ash_a2a/identity/canonical.ex` JCS + sha256 digest.
- `ash_affidavit/lib/ash_affidavit/refusal.ex:91-189` closed code-to-class refusal registry.
- `ash_affidavit/lib/ash_affidavit/signing/keys.ex:139-220` declarative key-shape refinements.
- `ash_atlassian/lib/ash_atlassian/architecture_governance.ex:213-254` canonical encode+digest.
- `ash_ex4pm/lib/ash_ex4pm/capabilities.ex:224-279` projected/alive/authorized split.
- smalt `scripts/sdk_coverage.py` and `scripts/shim_court/lib.sh` for Q1/Q2 prior art.

## See Also

`docs/jira/v26.11.11/PARITY-WAVE3-QUEUE.md` · `PROJECT-REVIEWS.md` · `docs/KNOWN_DIVERGENCES.md`
