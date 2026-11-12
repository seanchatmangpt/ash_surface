# Wave 3 RBF Repair Receipt

Standing: PASS

Lane RBF. New `test/ash_surface/ported/rpc/rbf/exposed_and_type_facts_test.exs` (9 tests, 0
failures). No lib edits. Note: the contract's `runtime_parity/rpc/errors.ex` does not exist; the
`exposed/1` survivor lives in `lib/ash_surface/errors.ex`.

Court `/tmp/rbf/court.py` (in-memory recompile, MIX_ENV=test, `_build-rbf`; sha256 restore_eq
True for both):
- E-f (`exposed/1` vars `%{}` -> `%{a: 1}`): killed, 3 failures.
- S-d (struct `resource?` false -> true): killed, 2 failures. Real fact pinned: a struct with
  `instance_of` is `resource?` false even when it names a resource; no equivalents.

`mix ash_surface.parity.tests` rc=0 (unaccounted=0, broken=0).
