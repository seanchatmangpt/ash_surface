# gapfix-ontology-promo-017: promote 並 capacity fact into ontology with enforcement anchor
status: BLOCKED
created: 2026-09-17T05:30:00Z
## Mission
The 並 capacity fact (flash heavyweight ≤16; rider setpoint law; storm protocol) lives only in ~/.zcode/AGENTS.md prose — sync-drift hazard (延 law: every concept keeps a repo-side enforcement anchor). Promote into this repo's ontology.ttl as law rows (tier, ceiling, telemetry paths) with an enforcement anchor: a gate script or test that reads capacity-ride/log.ndjson and fails when target_n exceeded 16 for non-rider work (or equivalent cheapest anchor). Mirror-reference to dfcm-agent-pack noted for the operator (marketplace admission is an operator cut).
## Acceptance
- ontology.ttl carries the 並 rows with enforcedBy path that exists and runs; anchor exits 0 at HEAD; mix test 0.
## History
2026-09-17T00:09:51Z | IN_PROGRESS | ~/ash-surface-wt/g17 + exp/gapfix-ontology-promo-017 | dispatched by rider (target_n=9; 012's soft-order on 001 satisfied — 001 MERGED)
2026-09-17T00:24:29Z | DONE | exp/gapfix-ontology-promo-017 @ 69e57df | just capacity-gate 0; falsifier (non-rider target_n=17) exit 1 VIOLATION observed; mix format --check-formatted 0; mix compile --warnings-as-errors 0; mix test 783 passed/0 fail; npm test 220 passed/0 fail | remaining: operator cut only — admit the 並 rows into dfcm-agent-pack (this repo carries the mirror + anchor; nothing else open)
2026-09-17T00:30:39Z | BLOCKED (integration-red class, rider): rider's mechanical ledger/ontology conflict resolutions produced two regressions tonight (014 path-union ordering; this attempt 0-head-rows parse) — multi-file ledger+ontology+law-row conflicts exceed safe mechanical union. UNBLOCK: dedicated integration agent (single ticket) merges 017 (+013, +007-rebase) with full gates; branch green @69e57df; capacity_gate falsifier-proven; only the merge needs care (ledger +1 row successor-owned, ontology +4 並 law rows + bijection 32, dead-owner re-point per precedent).
