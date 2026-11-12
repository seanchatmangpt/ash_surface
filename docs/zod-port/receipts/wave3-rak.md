# wave3-rak

Standing: PASS

Lane RAK (repair of the "Not covered by any in-scope file" section of wave3-skmute1).
Live runs used `MIX_BUILD_ROOT=_build-rak` (deleted at end). Mutations ran in scratch
`/tmp/rak/w` (explicit-path tar of lib test mix.exs mix.lock config parity priv README.md
ontology.ttl conformance scripts docs; deps and node_modules symlinked; build root
`/tmp/rak/w/_b`). Harness `/tmp/rak/mut.py`, output `/tmp/rak/mut.out`.

## New files (not ledger rows; no ported file or ledger row edited)

- test/ash_surface/ported/rpc/rak/value_formatter_branches_test.exs (12): tuple by-index,
  keyword, vector branches of `Rpc.ValueFormatter`.
- test/ash_surface/ported/rpc/rak/validator_refusals_test.exs (11): duplicate, transport and
  offline kind, admission (unknown / non-public), typed-query name and kind refusals,
  malformed compilation. Real inline resource, pure validator.
- test/ash_surface/ported/rpc/rak/pipeline_scoped_get_by_test.exs (13): extra and missing
  get_by, scoped sort and filter refusals under `FieldName.with_formatter`, tenant fragments of
  `IdentitySchema`, exact-row typed-query style cross-domain read (replaces the weak
  assertion set of the e/ typed_query cross-domain surface test; that file left untouched).

## Verification (rc captured un-piped)

- `mix test test/ash_surface/ported/rpc/rak` live: 36 tests, 0 failures, rc=0.
- `mix test test/ash_surface/no_local_do_test.exs` + rak: 41 tests, 0 failures, rc=0.
- `mix ash_surface.parity.tests`: rc=0, `unaccounted=0 broken=0`.

## Shim court (scratch; every restore sha256 == baseline: True)

Baseline scratch 36/0. Red under each mutation: M1 tuple `elem(value,0)` 3 fail; M2 keyword
`%{}` 1; M3 vector passthrough 1; M4 duplicate `count > 9` 2; M5 kind check `true` 3; M6
admission reject-all 2; M7 extra get_by guard off 2; M8 scoped sort off 2; M9 scoped filter
off 1; M10 tenant required fragment 3; M11 tenant `.optional()` dropped 2; M12 global? ignored
1; M13 output_formatter key = internal_key 1.

## UNVERIFIED / not done

- Gap files left as loud skips as instructed. Mutation `field_formatter` mapped-name ->
  compute survives the new typed_query test (compute yields the same spelling for those
  fixture names; not a defect).
- The other skmute1 repair items (namespace, composite PK, aggregates, exotic_type_facts,
  private_arguments baseline) were not in this lane's named areas.
