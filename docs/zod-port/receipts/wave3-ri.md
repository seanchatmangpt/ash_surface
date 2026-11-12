# wave3-ri

Standing: PASS

Lane RI (repair of vacuous/weak tests from wave3-skmutb). Scratch-only mutation in `/tmp/ri`
(explicit-path tar copy, build root `/tmp/ri/_build-ri`, sha256 baseline == restore for every
shim). Shared checkout mutated only via the three owned test files.

## Changes

1. `test/ash_surface/ported/rpc/d/rpc_pipeline_surface_test.exs`: the three-branch `assert true`
   test replaced by (a) parse of multitenant `list_org_todos`: request.tenant nil, `"org-1"` via
   opts, `"org-2"` via params; (b) `Pipeline.error_response({:tenant_required, OrgTodo})` exact
   envelope (unknown_error / "Unknown error" / errorId). No Ash.read/create/update/destroy.
2. `test/ash_surface/ported/rpc/c/private_arguments_surface_test.exs`: added describe asserting
   parsed action inputs omit `public?: false` args, input parse atomizes the public key but never
   resolves the private key, and the action manifest JSON never names private arguments.
3. `test/ash_surface/ported/rpc/c/nested_query_opts_surface_test.exs`: added test asserting exact
   envelope keys and byte-identical opaque values for each of page/filter/sort/limit/offset.

## Shim-court (rc from `mix test <file>`)

| mutation | baseline | mutated | restored |
|---|---|---|---|
| atomizer.ex drop `:offset` from `@query_opt_atom_keys` | rc0 29/0 | rc2 29/1 | rc0 29/0, sha equal |
| pipeline.ex `tenant = nil` | rc0 36/0 | rc2 36/1 | rc0 36/0, sha equal |
| pipeline.ex parse_action_input returns raw input | rc0 8/0 | rc2 8/1 | rc0 8/0, sha equal |

First tenant baseline run showed 1 failure (cold compile after copy); three reruns and a court
rerun: 36/0. Cause UNVERIFIED.

## Gates

- 3 owned files + `test/ash_surface/no_local_do_test.exs`: 78 tests, 0 failures.
- `mix ash_surface.parity.tests` in scratch: rc=1, broken=45 (pre-existing unindexable-dynamic-test
  rows in other files; none name the three owned files; unaccounted=0). Ledger rows untouched.
- Private-argument input parse does not refuse; it leaves private keys unresolved (asserted as
  observed). Tenant-required has no lib clause (asserted as observed).

## Falsifier

Any of the three mutations above leaving its file green.
