# wave3-skmutj

Standing: PARTIAL

Adversarial mutation skeptic over RBE, RBF, RBG, RBH (RBI untouched). Scratch tar copy
`/tmp/skmj` (deps/node_modules symlinked, build root `/tmp/skmj/_b`); canonical never written
(scratch lib `cmp`-identical to canonical for 7 of 8 mutated files; field_selector.ex was
mid-mutation when the court was stopped and was re-copied from canonical). Court `court.py`:
per mutation sha256 baseline == restore True and mutated != baseline True on every row.
Baseline rbe+rbf+rbg+rbh: 51 tests, 0 failures. Mutation rc taken un-piped (python subprocess).
34 new mutations against the four new test dirs; survivors re-run against wider suites (full
`ported/rpc`, 2093 tests, or error/manifest globs). Stopped at coordinator request: H4/H6/H7
wider-suite runs UNVERIFIED; E7/E8/F2/F5/F6/G1/G2/H2/H3/H5/H8/H9 killed in own dirs.

## Results (K killed, S survived)

RBE (pipeline.ex / support.ex):
- E1 config-spelling unknown_field branch -> scoped: S own, K full rpc (rak test).
- E2 scoped find -> config: S own, K full rpc.
- E3 sort prefix regex drops `++`/`--`: S own; in full run only an rbf test failed (anomaly).
- E4 sort split "," -> ";": S own and full rpc.
- E5 nested-scope recursion disabled: S own and full rpc.
- E6 format_input_name true-branch uses input_name: S own and full rpc.
- E7 K, E8 K.

RBF (errors.ex / type_facts.ex):
- F1 exposed `fields: []`: S own and error globs. F4 drop :key from Map.take: S own and globs.
- F3 (show_raised? gate dropped) S own, K globs. F7 (scrub List.last -> first) S own, K globs.
- F2 K, F5 K, F6 K.

RBG (field_name.ex / action_manifest.ex):
- G3 `{m,f,[a,b,c]}` arg order: S own and field_name globs.
- G4 namespaces uniq dropped, G5 nil namespaces not rejected, G6 entry-vs-resource precedence
  swapped, G7 `to_string(ns)` dropped, G8 namespaces sort dropped: S own and manifest globs.
- G1 K, G2 K.

RBH (error_builder.ex / field_selector.ex / errors.ex):
- H1 type "invalid_pagination": S own, K full rpc.
- H4 (line 473 throw path), H6, H7 (lines 627/630 throws, path -> []): S own; wider UNVERIFIED.
- H2 K, H3 K, H5 K, H8 K, H9 K.

## Anomaly

E2 and E3 failed `rbf ... TypeFacts resource? on struct ... struct argument naming a resource`
in the full-rpc run; E3 (sort regex) has no causal link to it. Suggests that test depends on
global installed manifest state and is order/seed dependent. UNVERIFIED (baseline repeat not run).

## Equivalent-class

None proven. All survivors are coverage gaps.

## Repair requests

- pipeline.ex check_scoped_sort (E3 `^(\+\+|--|\+|-)`, E4 `String.split(s, ",")`): scoped-sort
  tests with `--f`, `++f` and comma lists under snake/pascal.
- pipeline.ex check_scoped_fields nested recursion (E5): refusal of an unknown name nested
  under a relationship scope.
- support.ex format_input_name `true ->` branch (E6): test a mapped non-binary argument.
- errors.ex exposed `fields: field_list(error)` (F1) and known Map.take :key (F4): assert
  exposed `fields` and InvalidKeyset `vars.key` in rbf.
- field_name.ex call_custom `[a,b,c]` arg order (G3): arity-4 formatter test.
- manifest/action_manifest.ex namespaces (G4-G8): duplicate/nil/unsorted namespaces,
  entry-vs-resource precedence, atom namespace rendered as string.
- field_selector.ex invalid_calculation_args nested paths (H4/H6/H7): wider run pending.
- Investigate rbf TypeFacts test order dependence (anomaly).

## Severity

MEDIUM. 11 confirmed non-equivalent survivors (E4 E5 E6 F1 F4 G3-G8) plus H4/H6/H7 unverified;
no lib defect found. Saturation count resets (not a LOW wave).

Cleanup: UNVERIFIED. `/tmp/skmj` (incl. `_b`) still exists; `rm -rf` was denied by the
permission layer. Coordinator must delete it.
