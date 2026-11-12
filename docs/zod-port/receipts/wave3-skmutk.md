# wave3-skmutk

Standing: PARTIAL

Adversarial mutation skeptic over RBN, RBO, RBP, RBQ. Scratch tar copy `/tmp/skmk` (deps and
node_modules symlinked, build root `/tmp/skmk/_b`, MIX_ENV=test, copy of an existing test build);
canonical never written. Court `/tmp/skmk/court.py`: per mutation sha256 baseline == restore
(True on every completed row, mutated != baseline True). Baseline rbn+rbo+route test: 30 tests,
0 failures, rc=0. Stopped at coordinator request (~45 min, heavily loaded host). N1-O4 ran on
the pre-RBS tree; field_name.ex was re-synced from canonical (RBS/KD-13 landed mid-run) and
O5..Q1 re-run on the new tree. UNVERIFIED (not run): Q2, Q3, Q4, P1, P2, P3, P4.

## Results (K killed, S survived; own = new test files, wide = full ported/rpc, 2116 tests)

RBN (pipeline.ex): N1 filter key check off: K own. N4 nested dest -> resource: K own.
- N2 nested logical filter value (`check_scoped_filter_value(%{})`) -> :ok: S own, S wide.
- N3 filter list value -> :ok: S own, K wide (non-RBN test).

RBO: O2 exposed path -> []: K. O6 nil namespace -> "": K. O7 resource namespace -> nil: K.
- O1 exposed short_message "Error": S own, K wide.
- O3 drop `not UnknownError` guard in transform: S own, K wide.
- O4 `{m,f,[a,b]}` args swapped: S own, K wide.
- O5 empty-string formatter result accepted: S own, K wide.

RBQ (support.ex, against rbe+rbn+rbo): Q1 else-branch returns raw input_name: K (5 failures).

## RBP oracle probe (in memory, lib FieldName vs Macro.camelize + lowerFirst)

Pre-RBS lib diverged from the reference on `HTTP_code` (lib `HTTPCode`, ref `hTTPCode`),
`a_bCd` (`aBcd` vs `aBCd`), `ab_cD_eF`, `user_ID`, `x_Y`; the oracle pool is lowercase-only
(`@conformant` filter) so it could not see them. Post-RBS lib agrees on all 9 probed pairs
(`a__b`, `x1_`, `HTTP_code`, `a_bCd`, `user_ID`, `a_1_b`, `x_Y`, `a_`, `ab_cD_eF`).
Caveat: lib and oracle now share `Macro.camelize` by construction (it is the reference rule),
so a Macro.camelize change is invisible to both, and the pool still has no uppercase names.
RBQ custom `{m,f}` / atom / empty-mapped probes: UNVERIFIED (Q2 unrun).

## Equivalent-class

None proven.

## Repair requests

- rbn/scoped_spelling_survivors_test.exs vs pipeline.ex check_scoped_filter_value(%{}) (N2):
  unknown spelling inside a nested logical filter map must be refused (survives full rpc).
- same file vs check_scoped_filter_value(list) (N3): same under a list value.
- rbo/errors_and_formatter_test.exs: exposed `short_message` (O1), UnknownError routing with
  show_raised? false (O3), arity-3 `{m,f,[a,b]}` order (O4), empty-string result (O5).
- route_channel_adversarial_test.exs: add uppercase/acronym names (`HTTP_code`, `a_bCd`).

## Severity

MEDIUM. N2 is a non-equivalent survivor against the full suite; no lib defect shown.
N3/O1/O3/O4/O5 are own-file gaps killed elsewhere. First wave of the new count.

Cleanup: UNVERIFIED. `/tmp/skmk` (incl. `_b`) created by this lane; `rm -rf` denied by the
permission layer. Coordinator must delete it.
