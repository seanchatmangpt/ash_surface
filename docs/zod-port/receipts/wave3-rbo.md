# Wave 3 RBO: Repair of SK-mutJ Survivors F1 F4 G3-G8

Standing: PASS

Tests added: test/ash_surface/ported/rpc/rbo/errors_and_formatter_test.exs (3),
rbo/manifest_namespaces_test.exs (4; real compiled manifest, 3 namespace levels).

## Shim-court (in-memory recompile of scratch copies, /tmp/rbo/court.exs)

All RED under mutation; sha256 of errors.ex, field_name.ex, action_manifest.ex, info.ex
identical before/after (`sha256sum -c` OK).
- F1 exposed `fields: []`: 1 fail. F4 drop `:key` from Map.take: 1 fail.
- G3 arity-4 args reordered: 1 fail.
- G4 no sort, G5 no uniq, G6 no nil-reject, G7 precedence swapped, G8 no to_string: each
  1-3 fails. Bonus G9 (domain beats resource in info.ex): 3 fails.
No equivalents. Note: F1 is only reachable via UnknownError (Ash wraps raw exceptions, so
their `fields` is []); test uses real UnknownError.

## Anomaly (rbf)

Root cause: rbf test used `Rbb.Emb` from another test file. Defined (full run) it is a real
embedded resource -> kind `embedded_resource`, so the "kind struct" assertion held only when
the module was undefined (isolated run) = load-order dependence. Disclosed fix in rbf: own
`Rbf.Emb`; test split into undefined-module (struct, resource? false) and real embedded
(`embedded_resource`). Not global manifest state.

## Verification

- `mix ash_surface.parity.tests` rc=0 (unaccounted=0 broken=0).
- `mix test test/ash_surface/ported/rpc` rc=0: 2116 tests, 0 failures, 213 skipped.
- KD-12 re-check: G3 pin uses binary results; compatible.
