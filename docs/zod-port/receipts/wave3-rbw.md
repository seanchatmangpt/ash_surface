# wave3-rbw

Standing: PASS

Repair lane for skeptic survivors N2, N3, O1, O3, O4, O5 (wave3-skmutk). New file only:
`test/ash_surface/ported/rpc/rbw/survivors_test.exs` (7 tests, own inline resources, real
`Pipeline.parse_request`, `Errors.to_errors`, `FieldName.format`; no mocks, no sleeps).
No lib change.

## Mutation proof (in-memory recompile of the CURRENT lib; disk sha256 unchanged, True each)

All six mutations still applied to current lib. Each: `RESULT failures=1 total=7`, the
matching test red; restored baseline 7 tests, 0 failures.

- N2 nested logical map value -> :ok: red (nested not/or/and map with `shortTitle`).
- N3 list value -> :ok: red.
- O1 exposed short_message "Error": red.
- O3 drop UnknownError guard: red.
- O4 args swapped (b, a): red.
- O5 empty-string result accepted: red.

Equivalents: none.

## Gates

- `mix test test/ash_surface/ported/rpc/rbw`: 7 tests, 0 failures.
- `mix ash_surface.parity.tests`: rc=0 (unaccounted=0 broken=0).
- `mix test test/ash_surface/ported/rpc` (un-piped rc): rc=0, 2123 tests, 0 failures, 213 skipped.
- Harness: /tmp/rbw/muts.py, run.py, mut.exs. Build root `_build-rbw` removed at end.
