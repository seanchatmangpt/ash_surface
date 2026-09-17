# gapfix-ledger-011: HANDWRITTEN ledger repair + UNSUPPORTED ontology rows
status: DONE
created: 2026-09-17T05:30:00Z
## Mission
Ledger cannot shrink: 18 rows all name owner "ash-extension-core (ggen-marketplace)" — pack nonexistent (successor ash-extension-pack contains none of the capabilities); ZERO UNSUPPORTED(generator, element) rows in ontology.ttl despite 帳 law requiring one per HANDWRITTEN row; unledgered same-class debt (docs/PROJECTORS.md, scripts/README.md, compiler/{ash,ir,schema,semantic,ash_truth}.ex); 15 rows mis-dated (dated 09-15, committed 09-16; two dated 09-17 committed 09-16 — use commit-verified dates). Re-point rows to the real successor owner; add the missing rows; add UNSUPPORTED rows to ontology.ttl for every open row; fix dates from birth-commit timestamps.
## Acceptance
- every open row: real owner path + verified date + matching UNSUPPORTED ontology row; missing rows added; mix test 0.
## History
2026-09-16T23:51:15Z | IN_PROGRESS | ~/ash-surface-wt/g11 + exp/gapfix-ledger-011 | dispatched by rider (target_n=7)
2026-09-17T00:12:40Z | DONE | ~/ash-surface-wt/g11 + exp/gapfix-ledger-011 @ f3d26a1 | mix compile --warnings-as-errors 0; mix test 765 passed 0 failures (incl. 4 new ledger tripwire tests); npm test 220 pass 0 fail; mix format --check-formatted 0 | remaining: the 26 ledger/UNSUPPORTED pairs retire only when ash-extension-pack (ggen-marketplace) grows each missing capability family
