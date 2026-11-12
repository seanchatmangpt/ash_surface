# wave3-f1fs

Standing: PARTIAL

Subject: `test/ash_surface/compiler/filter_schema_size_test.exs` "real zod accepts legal nested
filter" (`[false, false]` once in a 440-test batch, wave3-f1un). Tree moving, no SHA bound
(filter_schema.ex and the test are untracked in git; `lib/ash_surface/field_name.ex` and
sibling tests edited by other lanes during this run). MIX_BUILD_ROOT=_build-f1fs (deleted).

## Verdict: not a regression in filter_schema.ex; NOT REPRODUCED (UNVERIFIED cause = in-flight edit)

- File alone, 5 runs: 8 tests, 0 failures each, rc=0 (real-zod test 1.2-2.6s; oversize 1.2-1.9s).
- Combined batch (compiler + ported/rpc/d + divergence_close, 552 tests) x4: filter_schema_size
  passed in all 4. Batch 1: 0 failures. Batches 2-4: 14 failures, none in filter_schema_size:
  EmbeddedSchemaTest, IRWiringTest(3), StructArgumentZodCourtTest, SortAndFilterTypesIrSurfaceTest(8).
  Those coincide with other lanes editing lib/ash_surface/field_name.ex and
  divergence_close/field_naming_divergence_test.exs (mtime after batch 1); owner = that lane.
- The legal payload (and -> not -> related, f1 eq) is accepted by the current emitted schema and
  unknown field rejected: [true,false] 5/5 alone. `[false,false]` means the schema rejected the
  legal payload, consistent with the functions->operators / nullable-aggregate edits landing
  mid-run (mtime filter_schema.ex 00:11:33), not with a rule in the current file.
- Race audit: tmp dir is `System.unique_integer`, no global state, no sleeps, Task.await 10s on
  the guard only. No structural race found; no code-layer fix needed.

## Test hardening (test only, court stays strict `[true,false]`)

`@moduletag timeout: 180_000` (documented: node + 600-rel render under load); the node script now
also emits zod issues to stderr and the assertion message prints the full node output, so a future
`[false,false]` carries the zod issue list.

## Size cap: what is proved

Enforced in `render_filter_schema/2` (filter_schema.ex:178): `byte_size(zod) > @max_bytes (1_000_000)`
returns `{:error, {:filter_too_large, bytes, 1_000_000}}`. The oversize court asserts that typed
tuple with `bytes > cap` for 600 relationships at max_depth 3 (4,250,680 B measured by f1un, which
is the unrestricted size; the cap court proves refusal, not that value). The 5-rel fixture proves
admit-under-cap plus ZodGuard admission in bounded time. Oversize test wall time: 1.2-1.9s.

## Commands

- `mix test <file>` x5: rc=0, 8 tests 0 failures
- batch x4: rc=1 on 3 (14 foreign failures), 0 filter_schema_size failures
- post-edit file x2: 8 tests, 0 failures; `grep Process.sleep` in file: 0; no mocks
- no_local_do courts: NOT RUN this lane (glob matched no file; build root already deleted) - UNVERIFIED

## Falsifier

A `[false,false]` on a quiescent tree retracts this; the assertion message now carries zod issues.

## See Also

[[wave3-f1un]] · [[wave3-f1dc]] · [[wave3-f1dm]] · [[wave3-tsa11]]
