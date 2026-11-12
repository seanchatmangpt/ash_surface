# wave3-f1nd

Standing: PASS

Lane F1-nodo. Subject: `lib/ash_surface/runtime_parity/requested_fields/field_selector.ex` vs
TRIPWIRE no-local-DO (`test/ash_surface/no_local_do_test.exs`).

## Finding

The violation was already gone on re-read: lane T5 (wave3-t5.md) replaced
`Ash.Query.for_read` with `Ash.Query.new` plus `Ash.Resource.Info.action` struct attach
(field_selector.ex ~785-795). No edit made by this lane. The builder never runs the query:
no `Ash.read`/`Ash.load` call in `lib/ash_surface/runtime_parity`; the only remaining
`for_read` text in field_selector.ex is a comment.

## Commands

- `MIX_BUILD_ROOT=_build-f1nd mix test test/ash_surface/no_local_do_test.exs
  test/ash_surface/runtime_parity` -> `17 tests, 0 failures`, rc=0 (includes the
  no_local_do tripwires and field_selection courts). Before-count not taken: the violation
  predated this lane's first run (the baseline run was stopped, never completed).
- A later re-run (separate invocations) hit a compile error in
  `lib/ash_surface/runtime_parity/rpc/pipeline.ex:1115` (another lane mid-edit); not this
  lane's file. UNVERIFIED for that later tree state.
- `_build-f1nd` deleted.

## Allowlist

Not widened by this lane. Disclosure: the working-tree diff of no_local_do_test.exs shows an
uncommitted addition of `[:Rewrite, :Source]` to `data_structure_module?/1` (installer
package.json patches) made by another lane; operator decision may be needed on that entry.
