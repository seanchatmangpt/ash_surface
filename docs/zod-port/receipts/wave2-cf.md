# wave2-cf: config, codegen task, installer, formatter export

Standing: PARTIAL

Lane cf (census lane 17). Targeted tests PASS; the igniter idempotence court is
BLOCKED by a missing fixture (details below).

## Files

- lib/ash_surface/config.ex - .mjs defaults, output_file/output_dir alias, sibling
  derivation (`config_or_derive`), new keys show_raised_errors, error_handler,
  error_output_formatter, zod_import_into_generated.
- lib/ash_surface/config/verifier.ex - clauses for each new key; override shapes
  `%{kind => expr}` and `[{Module, "z.expr"}]` (same as ZodType.overrides) plus the
  legacy `{import, name}` shapes.
- lib/mix/tasks/ash_surface.codegen.ex - `--check` raises
  Ash.Error.Framework.PendingCodegen with per-file diff; `--dev` and
  `Config.always_regenerate` bypass the check; only changed files written;
  `--output` accepts a `.mjs` file or a directory; default from `Config.output_file`;
  Verifier.verify! before generation.
- lib/mix/tasks/ash_surface.install.ex - AshSurface.Formatter plugin removed; configure_new
  for real keys; next-steps notice; `--yes` accepted; Verifier.verify!.
- lib/ash_surface/installer/installer.ex (new) - `AshSurface.Installer.default_config/0`.
- .formatter.exs - exports `projection: 1/2` (the only DSL call in resource.ex).
- Tests: config_test (unchanged), NEW config_deep_test, NEW formatter_export_test,
  codegen_task_test (extended), installer/installer_test (extended; first coverage of
  Mix.Tasks.AshSurface.Install), formatter_registration_canary_test (premise rot:
  `AshSurface.Resource` now exists, self-proofs re-pinned to sentinel
  `AshSurface.RetiredFormatterTarget`), ash_surface_igniter_idempotence_court_test
  (formatter_plugin? -> formatter_wired?: import_deps present, AshSurface.Formatter
  absent; vendored formatter stub removed).

## Commands

`MIX_BUILD_ROOT=_build-cf MIX_ENV=test mix test test/ash_surface/config_test.exs
test/ash_surface/config_deep_test.exs test/ash_surface/formatter_export_test.exs
test/ash_surface/formatter_registration_canary_test.exs
test/ash_surface/codegen_task_test.exs test/ash_surface/installer/installer_test.exs`

    41 tests, 0 failures   (exit 0)

`mix format --check-formatted` over owned files: exit 0.

Idempotence court, alone: `mix test test/ash_surface_igniter_idempotence_court_test.exs`

    6 tests, 5 failures   (132.5s)
    ** (RuntimeError) Could not find module SparkClosureConsumer.Example.Post

The court needs the `spark-closure-consumer` fixture app (or AEX_IGNITER_FIXTURE_ROOT /
ASH_PACK_GENERATED); none exists in this checkout, so it copies the repo itself and
the `--target SparkClosureConsumer.Example.Post` patch has no module to find. The
install task itself ran to that point (config, formatter, verifier passed). Not
verified against the pre-edit tree (no git state commands allowed).

## UNVERIFIED

- Idempotence court green path (fixture absent).
- `zod_import_into_generated`, `error_handler`, `error_output_formatter`,
  `show_raised_errors` are validated and exposed but no generator consumes them yet.
- Codegen tests run against this project's real manifest; artifact content is whatever
  the compiler lane currently emits.

## Requests

- projectors/js.ex should read `Config.zod_import_path` and `Config.zod_import_into_generated`.
- Codegen task should copy the runtime .mjs files once the adapter lane lands.
