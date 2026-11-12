# Wave 3 RAY Repair Receipt

Standing: PASS

Lane RAY. New files (no lib edits): `test/ash_surface/ported/rpc/ray/calc_branches_test.exs`
(inline Item/Emb/Domain; K3-K7) and `namespace_edges_test.exs` (RAL gap).

Findings: entry-level "" and "a b" pass through ActionManifest verbatim (namespaces `[""]`).
Resource- and domain-level "", "a b", "1x" are refused at compile
(`invalid_namespace: namespace "" must be a string usable as an identifier`, DslError).

Court `/tmp/ray/court.sh` (build root `_build-ray`, in-place mutation, sha256 restore
byte-exact, `restore_eq=True` x7). Baseline rc=0, 11 tests 0 failures; restored same.

| id | result |
|---|---|
| K3 length(args)>1 | killed (5 failures) |
| K4 required-args false | killed (1); reachable via RAU-style inline required arg |
| K5 {name,{args,fields}} | killed (1); needs an embedded-resource return (map fields never load) |
| K6 {name,args} | killed (3) |
| K7 fields on non-complex | killed (1) |
| N1 validator accepts "" | killed (1) |
| N2 namespace refusal removed | killed (1) |

`mix ash_surface.parity.tests` rc=0 (unaccounted=0, broken=0). No equivalents.
