# Wave 3 Lane 11 Receipt (docs and registers)

Standing: PARTIAL

## Files

- docs/jira/v26.11.11/PARITY-REGISTER.md (rewritten: 19 capability rows, 6 NON-GOAL rows)
- docs/jira/v26.11.11/{_LANES,OVERVIEW,COMPARISON-ash-typescript}.md (status tables replaced
  by links to the register; no counts restated)
- docs/jira/v26.11.11/{L04-constraint-zod,L09-filter-operators,L10-query-envelopes,
  L21-union-types,L22-calculations}.md (stale claims fixed: regex rendering, `match`,
  discriminatedUnion -> z.union, uuid -> z.uuid(), no doubled backslashes)
- CHANGELOG.md ("In flight" only), docs/zod-port/CONTRACT.md (wave 2/3 lane index)
- Not edited: README.md (no factual error found; no-.d.ts stance intact), L20, L23,
  PARITY-WAVE2-BACKLOG.md (L20/L23 carry no stale claims per grep; backlog is a dated census).

## Commands

- Wait-gate poll (<=30s steps): wave2-b1a, wave3-02, -09, -17 landed; wave3-01 and wave3-04
  absent at ~45 min. wave3-04 landed afterwards (PARTIAL) and is cited; wave3-01 still absent.
- Evidence: `grep -n` of `def render*` in lib/ash_surface/compiler/*.ex and
  `compiler/ir.ex:124-130,230,318,341,355,377,387` (renderer call sites), exit 0.
- `grep -rn QuerySchema test` -> query_schema_test.exs, query_schema_wave2_test.exs (D-L24-1 closed).
- Read-only `git status --short test/ash_surface/projectors/js/` showed `??` (D-L24-2 open).
- source-of-truth-check skill not invoked (Skill tool not run); the single-source rule was
  applied by hand: register holds statuses, others link.

## UNVERIFIED

- wave3-01 (IR wiring) absent: IR-dependent rows are IN-FLIGHT-AT-FILL.
- No mix/node gate was run by this lane (docs only); no markdown line-length lint run.
  PARITY-REGISTER table rows exceed 100 chars (table cells).
- Status values copied from receipts read at fill time; receipts may change afterwards.
- Whether the filter `not` single-filter and aggregates-as-name-enum divergences are
  closed: register lists them as OPEN, not acceptable.

## Requests

- Coordinator: confirm D-L24-2 (`test/ash_surface/projectors/js/` tracked) before commit.
- Re-run this register fill after wave3-01 lands.
