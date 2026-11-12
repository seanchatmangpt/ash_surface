# wave3-ral

Standing: PASS

Lane RAL. Domain-level namespace in the action manifest.

## Finding

`AshSurface.Domain` already has the `namespace` DSL option, verifier and
`Info.effective_namespace/1` (resource > domain). Only the manifest path ignored the
domain: `ActionManifest.resource_namespace/1` used `Info.namespace/1`.

## Change

- lib/ash_surface/manifest/action_manifest.ex: resource fallback uses
  `effective_namespace/1` (entry > resource > domain, as in the reference); manifest gains
  top-level `namespaces` (sorted unique non-nil action namespaces).
- test/ash_surface/ported/rpc/c/namespace_manifest_surface_test.exs: new test with a real
  domain namespace, exact-value per-action namespaces and `namespaces` list.
- Invalid/empty namespace refusal already present in domain.ex verify_namespace and
  resource validator (unchanged). No IR change; no regen.

## Commands (MIX_BUILD_ROOT=_build-ral, rc un-piped)

- mix test test/ash_surface/ported/rpc/c test/ash_surface/ported/manifest: rc=0, 479 tests,
  0 failures, 42 skipped.
- mix ash_surface.parity.tests: rc=0, unaccounted=0 broken=0.
- Mutation (scratch /tmp/ral, tar of live repo): effective_namespace -> namespace in
  action_manifest.ex: new test red (25 tests, 1 failure, rc=2). Restore sha256 ==
  baseline 903bb517...2ef.
