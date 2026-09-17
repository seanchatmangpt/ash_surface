# chicago-ontology-producer-039: ontologyDigest/applicationReleaseIdentity: honest producer or enforced absence
status: DONE
created: 2026-09-17T06:30:00Z
## Mission
015 adjudicated keep-typed-optional-no-producer. Decide by evidence on the CURRENT tree (F4 landed since): either wire an honest producer from admitted state (surface.digest + generator identity — no fabrication) with state rows, OR encode the absence as an enforced contract test (fields absent from contract/2 output BY LAW, presence = RED) + doc note at the schema site.
## Definition of Done (Chicago school)
- State-based tests exercise the REAL subject — no test doubles for the unit under test (injected seams only where the law itself demands injection).
- Assertions on observable outcomes only: returned values, emitted artifacts, on-disk bytes, typed refusals — never internals (mock-call bookkeeping allowed solely where the law IS the boundary, e.g. bus-untouched proofs).
- EXECUTED falsifier in the ticket History: mutate the subject behavior, run the new tests, show RED, restore, show GREEN — commands + exits recorded.
- Gates exit 0: mix compile --warnings-as-errors; mix test; npm test (if JS touched); mix format --check-formatted.
## Acceptance
- one of the two landed with state rows + executed falsifier for the chosen side; no fabricated provenance; gates 0.
## Verdict
ENFORCED ABSENCE chosen. Honest producer REFUSED on post-F4 evidence (lib/ash_surface.ex is the real subject):
1. contract/2 receives Manifest + profile only — no ontology or release input crosses the surface boundary (Ash serializer omits extension custom data + entrypoint config).
2. F4 (MXEpisode.compose/1) binds surface.digest and subject repo/head at the EPISODE layer from operator-supplied inputs — it adds no surface input, so it cannot feed a contract-layer producer.
3. surface.digest -> ontologyDigest is circular: Surface.digest digests the very contract that would carry the field (ash_surface.ex digest/1 over contract/1 output).
4. generator identity -> applicationReleaseIdentity mislabels provenance: generatorIdentity already has its own envelope field; the witnessed upstream value (F5 fixture "ash-surface-wt/v43@282f3ca") is a generation-time repo/head fact, not derivable from the manifest.
5. environment reads (repo ontology.ttl, Mix version, git head) would make Surface.digest environment-dependent, breaking the frozen golden determinism law (AshSurface.DigestTest).
Absence now ENFORCED: presence of either field in contract/2 output is RED at test/ash_surface/from_manifest_test.exs (tripwire + closed seven-key envelope pin). Typed optional schema rows kept in priv/static/ash_surface_runtime.mjs — they admit witnessed upstream values; the Elixir producer never emits. Ledger row admitted (HANDWRITTEN.md + ontology.ttl UnsupportedLedgerRow44, in bijection per handwritten_ledger_test).
## History
2026-09-17T05:49:05Z | IN_PROGRESS | ~/ash-surface-wt/g39 + exp/chicago-ontology-producer-39 | dispatched by coordinator (chicago wave)
2026-09-17T06:49:55Z | REAPED: cluster death at ~30min (sustained-load grind; 5 simultaneous); branch preserved — successor reviews git log first
2026-09-17T07:39:37Z | IN_PROGRESS | successor re-dispatch (cohort 2 of 4; window confirmed by cohort 1 completing 3/3; branch preserved — review git log first)
2026-09-17T07:46:56Z | DONE | ~/ash-surface-wt/g39 exp/chicago-ontology-producer-39 @ af98822 (product) | successor resumed predecessor's uncommitted enforced-absence work; verified adjudication against the real subject (contract/2 emits exactly 7 keys; digest/1 circularity confirmed at ash_surface.ex:89-90,146,279; delegated facts flow via decorate_manifest -> IR.delegated read-back) | gates: mix compile --warnings-as-errors EXIT=0; mix test EXIT=0 845 passed (5 doctests, 840 tests); npm test EXIT=0 258/258; mix format --check-formatted EXIT=0 | falsifier EXECUTED: contract/2 mutated to emit "ontologyDigest" => manifest_digest -> mix test test/ash_surface/from_manifest_test.exs EXIT=2, 9/12 passed, 3 failures all in enforced-absence block (refute Map.has_key? fired); git restore lib/ash_surface.ex -> EXIT=0 12 passed, recompile EXIT=0 | remaining: merge via rider (never pushed)
