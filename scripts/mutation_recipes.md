# mutation_recipes.md — Chicago falsifiers for the golden guards

A golden that cannot go red is decoration, not a guard. This document holds the
mutation recipes for the three golden families: each recipe mutates the real
subject, shows the guarding tests **RED**, restores, and shows them **GREEN**.
Every recipe below was executed in-receipt on 2026-09-17
(ticket `chicago-golden-mutation-041`); the fast runner is
`bash scripts/mutation_recipes.sh`.

`scripts/mutation_recipes.sh` (the three golden families) is **not** wired to
default CI; run it by hand, in a clean scratch copy, whenever you touch a golden
family or its subject. `scripts/ci_falsifier.sh` (all recipes, including the
guard recipes below) **is** wired to CI as the `falsifier` job. Never commit a tree with a mutation applied — the runner
restores every subject and fails closed if any guard refuses to go red.

## The families

| # | Family | Guard (frozen constant) | Subject (the real thing mutated) |
|---|--------|--------------------------|----------------------------------|
| 1 | runtime behaviour | `test/js/transport_law.test.mjs` (post-dispatch classification) | `priv/static/ash_surface_runtime.mjs` |
| 2 | contract digest | `test/ash_surface/digest_test.exs` (`@golden`, 5 digests) | `lib/ash_surface.ex` (`contract/1` envelope) |
| 3 | IR codec golden | `test/ash_surface/ir_codec_golden_test.exs` (`@golden`, `@golden_json`) | the codec declared in that same file (`Codec.to_map/1`) |

All three guards assert on observable outcomes only: the runtime's dispatch
receipt, digest hex values and exact JSON bytes recomputed from the real
subject at test time. There is no whole-file runtime digest any more: a
byte-change-detector is not a correctness guard (a newline can not be wrong),
so family 1 mutates *behaviour*. `test/ash_surface/runtime_source_test.exs`
still pins provenance (served == disk, ordinary JS, version marker, export
surface) but is deliberately not a falsifier target.

## Recipe shapes

* **behavioural flip** — change what the subject *does* (a classification, an
  order, a check) while keeping it syntactically valid. Proves a behaviour test
  pins the law, not the bytes.
* **field rename** — rename one key the subject emits into its canonical
  serialization. Proves the guard pins field identity, not just field values.

---

## Recipe 1 — runtime behaviour, post-dispatch classification

Mutate: make the runtime's dispatch receipt report `SUCCESS` for every
outcome, instead of `UNKNOWN_AFTER_DISPATCH` for a post-dispatch failure
(transport law: a timeout/disconnect after dispatch is never "settled").

```bash
perl -pi -e 's/const outcome = dispatchState === "completed"[^;]*;/const outcome = "SUCCESS";/' \
  priv/static/ash_surface_runtime.mjs
node --test test/js/transport_law.test.mjs             # RED
git checkout -- priv/static/ash_surface_runtime.mjs    # restore
node --test test/js/transport_law.test.mjs             # GREEN
```

Executed in the ERRC lane (see `bash scripts/mutation_recipes.sh`,
`EXIT[M1_RED]=1`, `EXIT[M1_GREEN]=0`). The guard needs `npm install` (zod).
The pattern is deliberately tolerant of how the classification constants are
spelled (`"SUCCESS"` literal or a shared vocabulary constant).

## Recipe 2 — contract digest, field rename

Mutate: rename one envelope key in the contract builder
(`lib/ash_surface.ex`, `contract/1`).

```bash
perl -pi -e 's/"generatorIdentity" =>/"generatorIdentityRenamed" =>/' lib/ash_surface.ex
mix test test/ash_surface/digest_test.exs             # RED
git checkout -- lib/ash_surface.ex                    # restore
mix test test/ash_surface/digest_test.exs             # GREEN
```

**Executed 2026-09-17:** `mix test` exit **2** ("Result: 6/7 passed" —
`golden-frozen digest vectors` failed: `assert computed == @golden`), with all
five contract digests drifting, e.g. `minimal_read` recomputed
`3847c08bff5fea04cd34823781d4c7f0a6c17247c04b87c67844c17ffa9dc2e6` vs frozen
`c8f65e1c57ae9c644f67d39948075fd79b71f41646c17a91d7b7c49b91a134d5`. Restored:
exit **0**, "Result: 7 passed".

One renamed key moves the canonical bytes, `canonical_term/1` sorts and hashes
them verbatim, and every frozen vector diverges — the digest is a whole-contract
content address, so no field can be renamed without breaking the pin.

## Recipe 3 — IR codec golden, expected-field drop

Mutate: drop one expected presentation field from the golden's own field-shape
assertion (the codec itself now lives in `lib/ash_surface/ir/codec.ex`; the
golden pins its shape).

```bash
perl -pi -e 's/assert fields\.\(IR\.Presentation\) == ~w\(format group label order widget\)a/assert fields.(IR.Presentation) == ~w(format group order widget)a/' \
  test/ash_surface/ir_codec_golden_test.exs
mix test test/ash_surface/ir_codec_golden_test.exs    # RED (1 failed)
git checkout -- test/ash_surface/ir_codec_golden_test.exs
mix test test/ash_surface/ir_codec_golden_test.exs    # GREEN (33 passed)
```

(The previous `"presentation" => section_to_map` rename no longer lands: that
text left the golden file when the codec moved to `lib/`. The runner's
mutation-must-land probe and dead-guard check made the stale recipe fail
closed, as designed.)

## Guard recipes (CI only, `scripts/ci_falsifier.sh`)

Each removes or weakens one hardening guard and demands its named test RED:

| Recipe | Mutation (subject) | Guard that must go RED |
|--------|--------------------|------------------------|
| `rt-post-dispatch-classification` | outcome always `SUCCESS` (runtime) | `test/js/transport_law.test.mjs` |
| `rt-known-transports-order` | `KNOWN_TRANSPORTS` reordered (runtime) | `test/js/transport_law.test.mjs` |
| `rt-null-prototype-registry` | `actions = {}` instead of null-prototype (runtime) | `test/js/runtime_hardening.test.mjs` |
| `digest-hexcase-flip` | digest hex upper-cased (`lib/ash_surface.ex`) | `test/ash_surface/digest_test.exs` |
| `from-manifest-refused-prefix` | `REFUSED_` admission branch disabled (`lib/ash_surface.ex`) | `test/ash_surface/boundary_hardening_test.exs` |
| `irgolden-presentation-fielddrop` | golden field list shortened | `test/ash_surface/ir_codec_golden_test.exs` |
| `event-digest-second-slot` | `receiptRef` slot dropped from digest binding (`event_projection.ex`) | `test/ash_surface/boundary_hardening_test.exs` |
| `transport-duplicate-check` | duplicate-transport branch disabled (`transport.ex`) | `test/ash_surface/transport_coverage_test.exs` |
| `zodguard-allow-constructor` | `constructor` removed from denied members (`zod_guard.ex`) | `test/ash_surface/decode_boundary_zod_guard_test.exs` |
| `js-namespace-collision` | collision check returns nil (`projectors/js.ex`) | `test/ash_surface/projector_hardening_test.exs` |
| `mx-verifier-timeout` | timeout branch reports success (`mx_episode.ex`) | `test/ash_surface/mx_episode_verify_hardening_test.exs` |

The first `zodguard` run proved the existing suite was blind to a bare
`.constructor` member (only the doubly-chained, called form was tested and it
was refused by an unrelated trailing-token rule); `decode_boundary_zod_guard_test.exs`
was added to close that gap.

---

## Runner + discipline

`bash scripts/mutation_recipes.sh` executes the three golden-family recipes end-to-end:
preflight (refuses to start if any subject file is dirty), baseline GREEN,
per-family mutate → RED → restore → GREEN, final cleanliness check. It prints
`EXIT[<step>]=<code>` for every step and emits `MUTATION_RECIPES_OK` only if
every RED was red and every GREEN green; an EXIT trap restores all three
subjects even on failure.

* Run on a clean tree; never commit a mutated state.
* A mutation that does **not** turn the guard red means the guard is dead —
  fix the guard (tighten the frozen pin), not the recipe.
* Changing a golden family legitimately (e.g. a version bump) goes through
  `scripts/bump_version.sh`, which re-freezes these same constants; this file
  is only the falsifier.

<!-- ci_falsifier runner: scripts/ci_falsifier.sh executes the bounded subset; see chicago-ci-falsifier-049 -->
