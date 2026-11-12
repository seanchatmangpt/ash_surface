# wave3-rah

Standing: PASS

Lane RAH (repair of survivors in wave3-skmute1). Scope: 5 test files under
test/ash_surface/ported/rpc/c/. Only test files edited; no lib change.

## Mutations (scratch /tmp/rah/w, build root /tmp/rah/_b, driver /tmp/rah/court.py)

Each run executes all 5 files (67 tests baseline, 0 failures). Every restore sha256 == baseline.

| id | lib file | mutation | red file (failures) |
|---|---|---|---|
| M1 | manifest/action_manifest.ex | namespace precedence resource over entry | namespace_manifest (1) |
| M2 | manifest/action_manifest.ex | actionType constant "read" | namespace_manifest (2) |
| M3 | manifest/action_manifest.ex | enableSort ignores action type | namespace_manifest (1) |
| M4 | manifest/action_manifest.ex | get? `or` -> `and` | namespace_manifest (1) |
| N1 | info.ex | effective_namespace domain before resource | namespace_resolution (3) |
| N2 | domain.ex | Domain namespace default "dom" | namespace_resolution (6) |
| N3 | info.ex | domain fallback dropped | namespace_resolution (5) |
| G1 | compiler/resource_facts.ex | no-projection fact constant true | global_config (1) |
| G2 | compiler/resource_facts.ex | not_found_error? set for non-get | global_config (1) |
| G3 | projectors/js/inference.ex | never `\| null` | global_config (1) |
| G4 | compiler/resource_facts.ex | primary_key identity dropped | composite_pk_ir (6) |
| C1 | runtime_parity/rpc/pipeline.ex | composite guard `> 1` -> `> 9` | composite_pk (3) |
| C2 | runtime_parity/rpc/pipeline.ex | PK filter order reversed | composite_pk (3) |
| C3 | runtime_parity/rpc/pipeline.ex | all-parts-present -> any | composite_pk (3) |

Restored BASELINE: rc=0, 67 tests, 0 failures.

## Live tree (MIX_BUILD_ROOT=_build-rah, rc un-piped)

- mix test (5 files + test/ash_surface/no_local_do_test.exs): rc=0, 72 tests, 0 failures.
- mix ash_surface.parity.tests: rc=0, unaccounted=0 broken=0.

Added assertions are non-actuating (facts, manifest build, Pipeline.resolve_identity, zod via node).

Note: ActionManifest namespace ignores the domain-level namespace (resource and entry only);
recorded as observed, not changed.
