#!/usr/bin/env bash
#
# capacity_gate.sh — enforcement anchor for the 並 capacity law rows
# (ontology.ttl v26.9.17, ticket gapfix-ontology-promo-017).
#
# WHAT IT ENFORCES
#   Reads the capacity-ride telemetry log (NDJSON, one JSON object per
#   dispatch observation: ts, tier, weight, target_n, rider) and fails when
#   a NON-RIDER observation reports target_n above the flash-heavyweight
#   ceiling of 16 (ontology row surf:FlashHeavyweightCeiling).
#
#   Rider rows (rider true) are exempt: a rider-supplied target_n is the
#   operator setpoint and overrides tier ceilings (surf:RiderSetpointLaw).
#
# FAIL-CLOSED SEMANTICS
#   - missing/blank target_n on a non-rider row -> exit 1 (an unverifiable
#     observation is not a passing one)
#   - malformed JSON on any line               -> exit 1 (silent skip would
#     be a fabricated pass)
#   - absent log file                          -> exit 0 with a note: no
#     telemetry is no evidence of violation, and the gate must be green at
#     any HEAD that has not yet started capacity-ride logging
#
# STORM CONTEXT
#   Refusals above 30 concurrent dispatches answer [1302]; the response is
#   the storm protocol (stop, drain, resume at half pace; repeat -> halve
#   again) — surf:StormProtocol in ontology.ttl. This gate anchors the
#   ceiling side of the same law family.
#
# USAGE
#   bash scripts/capacity_gate.sh
#   CAPACITY_RIDE_LOG=/path/to/log.ndjson bash scripts/capacity_gate.sh
#   Exit 0 -> no violation on record; exit 1 -> violation or bad telemetry.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "${SCRIPT_DIR}/.." rev-parse --show-toplevel)"
LOG="${CAPACITY_RIDE_LOG:-${REPO_ROOT}/capacity-ride/log.ndjson}"

if [[ ! -f "${LOG}" ]]; then
  printf 'capacity_gate: no telemetry at %s — nothing to falsify (exit 0)\n' "${LOG}"
  exit 0
fi

# Ceiling literal mirrors ontology.ttl surf:capacityCeiling 16; the pin is
# cross-checked by test/ash_surface/capacity_gate_test.exs (16 passes, 17
# fails) and test/ash_surface/ontology_enforced_by_test.exs (TTL says 16),
# so drift between this constant and the law row fails mix test.
node -e '
const fs = require("fs");
const CEILING = 16; // surf:FlashHeavyweightCeiling
const path = process.argv[1];
const lines = fs.readFileSync(path, "utf8")
  .split("\n").map((l) => l.trim()).filter((l) => l.length > 0);
let checked = 0;
let riderRows = 0;
let violations = 0;
for (const [i, line] of lines.entries()) {
  let row;
  try {
    row = JSON.parse(line);
  } catch (e) {
    console.error(`capacity_gate: malformed telemetry at ${path}:${i + 1}: ${e.message}`);
    process.exit(1);
  }
  if (row.rider === true) { // surf:RiderSetpointLaw — operator setpoint, exempt
    riderRows += 1;
    continue;
  }
  checked += 1;
  const n = row.target_n;
  if (typeof n !== "number" || !Number.isFinite(n)) {
    console.error(`capacity_gate: non-rider row ${path}:${i + 1} has missing/non-numeric target_n`);
    process.exit(1);
  }
  if (n > CEILING) {
    console.error(`capacity_gate: VIOLATION ${path}:${i + 1}: non-rider target_n=${n} exceeds flash-heavyweight ceiling ${CEILING}`);
    violations += 1;
  }
}
if (violations > 0) {
  console.error(`capacity_gate: FAIL (${violations} violation(s))`);
  process.exit(1);
}
console.log(`capacity_gate: OK (${checked} non-rider row(s) checked, ${riderRows} rider row(s) exempt, ceiling ${CEILING})`);
' "${LOG}"
