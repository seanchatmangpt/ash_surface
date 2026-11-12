# Wave 3 RAZ Receipt

Standing: PARTIAL

Lane RAZ. Finding: entry-level namespace "" / "a b" passes verbatim (RAY).

Reference ash_typescript@5d6e80ae: `lib/ash_typescript/rpc.ex:128-133` declares the
rpc_action `namespace` as `type: :string` only; resource (`:226`) and domain (`:271`) the
same. `git grep` of lib/ finds no verifier, regex or normalizer for namespace. Verdict:
pass-through is parity; no KD. ash_surface resource/domain `invalid_namespace` refusal is
stricter than the reference (left unchanged).

Change: no lib edits; RAY test unchanged. New
`test/ash_surface/ported/rpc/raz/entry_namespace_parity_test.exs` pins "", "a b", "1x",
" pad ", "Mixed-Case.x" verbatim in actions and namespaces.

Verify: `MIX_BUILD_ROOT=_build-raz mix test test/ash_surface/ported/rpc` (rc not captured:
run was backgrounded; summary line): 2031 tests, 0 failures, 213 skipped. `_build-raz` deleted.

UNVERIFIED: mutation (normalizing namespace in ActionManifest) not run; the pin test asserts
exact equality so it would fail under normalization, but no red run is witnessed.
