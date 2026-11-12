# Wave 3 Lane CP: I03 igniter idempotence courts

Standing: PARTIAL_ALIVE

Each file run alone: `MIX_BUILD_ROOT=_build-cp perl -e 'alarm 720; exec @ARGV' mix test <file>`
(machine load average 65-105 throughout). Stale-snapshot recheck: on the original tree
all four failed to complete (ash_surface rc=142 at 720s alarm, 1 test done; the other
three rc=142/2 with File.CopyError from sibling `_build-*` dirs or missing fixture).

## Test-only defects fixed (all four files)

1. Fixture-copy skipped only `_build`; sibling lanes' `_build-*` roots were copied and
   vanished mid-copy (File.CopyError). Now `_build*` prefix excluded.
2. ash_r2rml/audit_trail/notification_extension lacked the `fixture/spark-closure-consumer`
   fixture-root candidate (ash_surface had it); they copied the whole repo. Added.
3. `snapshot/1` excluded only `_build/`; a relative `MIX_BUILD_ROOT` builds
   `_build-*-igniter-court` inside the scratch, making installs look unstable. Now `_build*`.
4. ash_surface: `@vendor_files` stale (persist.ex now needs FieldName.Mapping, Event,
   CanonicalJSON, Compiler.TypeFacts). Added field_name.ex field_name event.ex
   canonical_json.ex compiler/type_facts.ex. Failed installs now write full output to
   `$TMPDIR/ash_surface_install_failure.txt`.

## Per file (final)

| file | rc | result |
|---|---|---|
| ash_surface_igniter_idempotence_court_test.exs | 0 | 6 tests, 0 failures (530.5s) |
| ash_r2rml_igniter_idempotence_court_test.exs | 2 | 6 tests, 6 failures; BLOCKED (I02): `mix ash_r2rml.install` task could not be found (6/6) |
| audit_trail_igniter_idempotence_court_test.exs | 2 | 6 tests, 6 failures; BLOCKED (I02): `The task "audit_trail.install" could not be found` (6/6) |
| notification_extension_igniter_idempotence_court_test.exs | 2 | 6 tests, 6 failures; BLOCKED (I02): `The task "notification_extension.install" could not be found` (6/6) |

The three BLOCKED files were last run after fixes 1-3 (rc=2, 12-22s each); pack libs are
absent (no lib/ash_r2rml, audit_trail, notification_extension), not fixed here.
