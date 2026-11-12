# wave3-rbh

Standing: PASS

Lane RBH: repair of SK-mutI survivors (RAI I5/I6/I8, RAW W2/W4/W8/W9/W10, RBA A1-A5,
RBB B3-B5, RBC C3/C4/C6). I1-I4, I10, D8, D9 belong to lane RBG (not touched).

New files (no landed file edited): `test/ash_surface/ported/rpc/rbh/pins_test.exs` (11 tests),
`test/ash_surface/ported/rpc/rbh/field_selector_paths_test.exs` (3 tests).

## Shim-court (scratch `/tmp/rbh/s`, canonical lib never written)

`/tmp/rbh/court.py`: per mutation sha256 baseline == restore True, mutated != baseline True,
RED rc=2 under mutation (rbh dir 14 tests, 1 failure; C6 2), GREEN rc=0 restored (14/0).
Killed (20 rows): I5 I6 I8 W2(2 occ) W4 W8 W9 W10 A1 A2 A3 A4 A5a(accessor) A5b(parity table)
B3 B4 B5 C3 C4 C6.

## Disclosures

- A1 (`:count` in Map.take): no struct in `@table` that is loadable here has a `:count` key
  (script over all 19 table modules, none); AshAuthentication modules are not loadable
  (UNVERIFIED). A1 is killed only via a simple fake `InvalidToken` struct carrying `:count`
  (Module.create, stated in the test moduledoc); on real Ash errors it is unobservable.
- No lib defect found.

## Gates

- `mix ash_surface.parity.tests` rc=0 (unaccounted=0 broken=0).
- `mix test test/ash_surface/ported/rpc` rc=0 un-piped to file: 2093 tests, 0 failures, 213 skipped.
