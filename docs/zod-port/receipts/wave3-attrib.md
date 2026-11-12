# Wave 3 Lane ATTRIB: Untracked File Attribution

Standing: PARTIAL

Subject: /Users/sac/ash_surface, HEAD 28d97201 plus dirty tree (peer session may edit). Read-only
except `docs/jira/v26.11.11/INTEGRATION-PLAN.md` (appended section `## Attribution`) and this
receipt. No git state commands run beyond `git ls-files -o`/`git status` reads.

## Counts (397 untracked files excluding `_build-*`, `node_modules`)

- OWNED: 362 (23 of them weak: directory-only evidence, single receipt)
- GENERATED: 11 (10 conformance vectors via `scripts/conformance_regen.exs`;
  `parity/test_inventory.json` via `mix ash_surface.parity.tests --regenerate-inventory`)
- SCRATCH: 1 (`304_trial.mjs`)
- UNKNOWN: 23 (left unstaged; listed in the plan)

## Method

Path, basename/stem, defmodule, and directory token matches across `docs/zod-port/**/*.md` and
`docs/jira/v26.11.11/**/*.md` (excluding the plan, gitplan, and this receipt). First-matching
receipt is the commit-group lane; multi-receipt files list up to 3 in the table. Doc files
(CONTRACT, SHIM-COURTS, README, PARITY-*) group under their own name, not a lane. mtimes unused.

## Falsifiers and limits

- Match = receipt names the file, not proof that lane authored it; peer ash-surface-39 can
  overlap. Re-run `git status --porcelain` before staging.
- The 397 vs plan's 390 delta is tree movement since the plan snapshot (new receipts landed).
- UNKNOWN includes lib/ash_surface/parity_tests/*, parity_deepen, parity_kinds, transformers,
  transport_phase_classification.test.mjs, kinds_runner.mjs (zero textual evidence).
