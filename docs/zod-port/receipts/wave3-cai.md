# Wave 3 Lane CAI: derived vendor set for the igniter idempotence court

Standing: PASS

Subject: `test/ash_surface_igniter_idempotence_court_test.exs` (only file edited).

## Change

The hand-kept `@vendor_files` list is removed. `vendor_closure/1` derives the vendored
set from the AST of `lib/ash_surface`: seeds are the module under test
(`@extension_module`) plus every module `lib/mix/tasks/ash_surface.install.ex` references;
edges are alias-expanded module references (transitive) plus the `foo.ex` -> `foo/`
namespace convention; files whose compile-time edges (struct, use/import/require,
@behaviour) cannot be satisfied by the vendor deps (spark, ash and their application
closure) or fall outside the closure (ash_r2rml/a2a-bound compiler files) are pruned
to a fixpoint. No list can go stale. The failed-install output is written in full to
`$TMPDIR/ash_surface_install_failure.txt`.

## Evidence

| run | command | rc | result |
|---|---|---|---|
| before (CP receipt) | wave3-cp.md | 0 | 6 tests, 0 failures, 530.5s |
| after | `MIX_BUILD_ROOT=_build-cai perl -e 'alarm 720; exec @ARGV' mix test <file>` | 0 | 6 tests, 0 failures, 332.7s (wall 334s) |
| non-vacuity | same command in `/tmp/cai` (tar copy, deps symlinked, `_build-cai-nv`) with `lib/ash_surface/config/verifier.ex` removed | 2 | 6 tests, 6 failures (red, loud) |

Non-vacuity sha256 baseline == restore: `fd47310bf3a3ffed0a887b9e5c552adf8484dbb959041273fe2aa862834c3172`.

Intermediate runs (same command) showed the derivation under-including without the task-file
seeds and namespace rule (rc=2, `Config.Verifier.verify!/0` undefined); fixed in-file.

## Not done

Sibling igniter courts (ash_r2rml_, audit_trail_, notification_extension_) untouched: BLOCKED
by I02 (pack libs absent), no shared helper exists. Machine load was high; seconds are
single-run wall times, UNVERIFIED as stable.
