# flash-capacity-ladder-001: measure flash-tier max safe concurrency
status: OPEN
created: 2026-09-17T03:20:00Z
## Mission
Re-measure the concurrency ceiling with flash-tier subagents (default tier changed 2026-09-17). Two ladders, same methodology as the 2026-09-17 probe: (a) trivial single-tool probes (timestamp-to-file) dispatched at 20/50/100; (b) heavyweight agents (real ticket work, multi-turn) held at in-flight 10 -> 16 -> 24 via top-up, watching peak overlap AND any [1302]. Re-ratify the AGENTS.md concurrency law with the measured flash numbers (per-tier table if they differ from the 8-heavyweight default-tier law). Coordinator request volume held roughly constant during probes.
## Acceptance
- probe artifacts (timestamps) on disk under ~/.zcode/workspace/default/capacity-probe/
- zero unexplained failures at the declared new max, across 2+ repeats
- AGENTS.md amended with measured numbers + this ticket's History records exits
## History
