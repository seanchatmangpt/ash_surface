# Wave 3 RBX: Q2-Q4 and P1-P4 probes (SK-mutK residue)

Standing: PASS

Method: mutants recompiled in memory (`mix do run --no-start -r /tmp/rbx/mut.exs + test`,
MIX_ENV=test, MIX_BUILD_ROOT=_build-rbx); lib files never written (sha256 of the unmutated source
printed per run; support.ex a3c069f093fa4ed9, field_name.ex b8cdb92f78b90857). No lib edits.

## Q2-Q4 (test/ash_surface/adversarial/format_input_name_pool_test.exs, 5 tests, rc=0)

Real resource + real formatters via `Support.format_input_name/5`. Q2 `{m,f}` returning the
same binary: `other_arg`, `_x`, `x?` pass through. Q3 differing binary applies to unmapped names
only; mapped `is_open?` -> `q`. Q4 atoms/`?`/leading `_` under built-ins; non-binary, `""`, nil
custom results raise ArgumentError for unmapped names (KD-12) and are never reached by mapped names.
Mutants: arms swapped 5/5 red; `is_atom` 5/5 red; else returns raw `input_name` 4/5 red. Survivors: 0.
Findings: binary input names raise FunctionClauseError (atoms are the contract); empty-string
`argument_names` values are refused at compile time (`field_not_invalid`), so unreachable here.

## P1-P4 (test/ash_surface/adversarial/route_channel_emission_pool_test.exs, 25 tests, rc=0)

Hard-coded literals (no Macro.camelize in the file): HTTP_code->hTTPCode, a_bCd->aBCd,
ab_cD_eF->abCDEF, Foo_bar->fooBar, a_B->a_B, x1_->x1, a__b->aB, über_straße->überStraße,
user_ID->user_ID, A_b->aB; path/query/body; collisions refused (`emitted_key_collision`):
Foo_bar/foo_bar, A_b/a_b, a__b/a_b, x1_/x1. Self-correction: my first `user_ID` literal
(`userID`) was a hand-derivation error (`_` before uppercase is kept); lib was right.
conformance/vectors/field_name_emission.json agrees on every shared literal (no disagreement).
Mutants (field_name.ex): no lowercase-first 23/25 red; capitalize-instead-of-camelize 11/25 red;
full downcase 22/25 red.

## Gates

- `mix ash_surface.parity.tests` rc=0 (unaccounted=0, broken=0).
- `mix test test/ash_surface/adversarial test/ash_surface/ported/rpc` rc=0: 2287 tests, 0 failures,
  213 skipped. An earlier run had 1 failure in rbw/survivors_test (another lane in flight);
  passes alone and on rerun.

Cleanup: `_build-rbx` deleted; /tmp/rbx scratch.
