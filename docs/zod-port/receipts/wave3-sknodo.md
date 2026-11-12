# wave3-sknodo

Standing: PASS

Verdict: LAWFUL-NARROW (entry itself); one PRE-EXISTING, allowlist-independent hole found.

## Subject
test/ash_surface/no_local_do_test.exs working-tree diff: `[:Rewrite, :Source]` added to
`data_structure_module?/1`. Real tree untouched (no edit to lib/ or test/).

## Call sites that needed it (entry removed in scratch copy, rc=2)
- lib/ash_surface/installer/package_json.ex: `Rewrite.Source.update(source, :content, ...)`
- lib/ash_surface/installer/tsconfig.ex: `Rewrite.Source.update(source, :content, ...)`
Exactly these two; nothing else trips with the entry removed.

## Receiver types (elixir -pa _build/dev/lib/*/ebin)
`Igniter.create_or_update_file` and `Igniter.update_file` callbacks both receive
`Rewrite.Source` structs (printed `s.__struct__`); `Rewrite.Source.update/3` exists. These are
in-memory file buffers, not Ash resources.

## Narrowness
Matching is on the syntactic alias list `[:Rewrite, :Source]` (module-qualified, exact list
equality). Scratch mutations with entry present: `Foo.Rewrite.Source.update` (tripped),
`Rewrite.create` (tripped), `Rewrite.Source.destroy` was also allowed (any fun on that module), a minor breadth note.
`Ash.create(Resource, %{})` beside a `Rewrite.Source.update` in the same file: tripped (rc=2).
Aliasing is not a bypass: resolution is syntactic, an `alias ... as: Rewrite.Source` onto an
Ash module would not match the list.

## Commands (scratch: /tmp/sknodo, copy of lib + test with module renamed; run via elixir)
- baseline with entry: 5 tests, 0 failures, rc=0
- mutation file (scratch only, sha256 a3f589eb...df9d unchanged before/after): rc=2, 1 failure
- entry removed: rc=2, the two installer sites listed above
- scratch excluded untracked lib/ash_surface/runtime_parity/rpc/pipeline.ex, which currently has
  a syntax error (line 1115, other lane's in-flight edit); the real test cannot compile-walk
  while that file stands (UNVERIFIED on the real tree, session-external).

## Pre-existing finding (not caused by the entry)
`Ash.create!(Some.Resource, %{})` is NOT caught: `@action_funs` lists `:create` but not bang
variants (`create!`, `update!`, `destroy!`), and `ash_framework_call?([:Ash], fun)` uses the same
list. Absent from the violations list with the entry present (rc=0, 0 failures) and with it removed (only the two installer sites listed). Proposed fix (not applied): add
`:create!, :update!, :destroy!, :calculate!, :bulk_create!, :bulk_update!, :bulk_destroy!,
:run_action!` to `@action_funs`.
