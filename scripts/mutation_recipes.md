# mutation_recipes.md — Chicago falsifiers for the golden guards

A golden that cannot go red is decoration, not a guard. This document holds the
mutation recipes for the three golden families: each recipe mutates the real
subject, shows the guarding tests **RED**, restores, and shows them **GREEN**.
Every recipe below was executed in-receipt on 2026-09-17
(ticket `chicago-golden-mutation-041`); the fast runner is
`bash scripts/mutation_recipes.sh`.

**NOT wired to default CI.** Run it by hand whenever you touch a golden family
or its subject. Never commit a tree with a mutation applied — the runner
restores every subject and fails closed if any guard refuses to go red.

## The families

| # | Family | Guard (frozen constant) | Subject (the real thing mutated) |
|---|--------|--------------------------|----------------------------------|
| 1 | runtime SHA | `test/ash_surface/runtime_source_test.exs` (`@golden_runtime_sha256`) | `priv/static/ash_surface_runtime.mjs` |
| 2 | contract digest | `test/ash_surface/digest_test.exs` (`@golden`, 5 digests) | `lib/ash_surface.ex` (`contract/1` envelope) |
| 3 | IR codec golden | `test/ash_surface/ir_codec_golden_test.exs` (`@golden`, `@golden_json`) | the codec declared in that same file (`Codec.to_map/1`) |

All three guards assert on observable outcomes only: SHA-256 / digest hex
values and exact JSON bytes recomputed from the real subject at test time. No
test doubles — the tests read the shipped file (`AshSurface.runtime_source/0`
is `File.read/1` at call time), build real surfaces through
`AshSurface.from_manifest/2`, and run the real codec functions.

## Recipe shapes

* **whitespace injection** — add one invisible byte to the subject. Proves the
  guard is byte-exact, not "close enough".
* **field rename** — rename one key the subject emits into its canonical
  serialization. Proves the guard pins field identity, not just field values.

---

## Recipe 1 — runtime SHA, whitespace injection

Mutate: append a single newline to the shipped runtime artifact.

```bash
printf '\n' >> priv/static/ash_surface_runtime.mjs
mix test test/ash_surface/runtime_source_test.exs     # RED
git checkout -- priv/static/ash_surface_runtime.mjs   # restore
mix test test/ash_surface/runtime_source_test.exs     # GREEN
```

**Executed 2026-09-17:** mutated SHA-256
`85e44fc92e638999a9332545496fb96bc6d7da51c4bef2e55898d73622266779` vs frozen
`8373790caa0659073d8010aea16683d472e0e91bd62ba46354e08016585e8e42`;
`mix test` exit **2** ("Result: 3/4 passed" — `hashes to the golden-frozen
SHA-256 digest` failed on the byte drift; the disk-vs-source test correctly
stays green because both sides read the same mutated file). Restored: exit **0**,
"Result: 4 passed".

Note why the guard cannot be fooled by re-hashing after the fact: it compares a
fresh `:crypto.hash(:sha256, ...)` of the file **as served** against a frozen
hex literal. Any byte, even `0x0a`, breaks the equality.

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

## Recipe 3 — IR codec golden, field rename

Mutate: rename one canonical section key emitted by `Codec.to_map/1` (declared
locally in the guard file until admitted `lib/ash_surface/ir.ex` /
`ir/codec.ex` land).

```bash
perl -pi -e 's/"presentation" => section_to_map/"presentation_renamed" => section_to_map/' \
  test/ash_surface/ir_codec_golden_test.exs
mix test test/ash_surface/ir_codec_golden_test.exs    # RED
git checkout -- test/ash_surface/ir_codec_golden_test.exs   # restore
mix test test/ash_surface/ir_codec_golden_test.exs    # GREEN
```

**Executed 2026-09-17:** `mix test` exit **2** ("Result: 18/33 passed",
**15 tests failed**) — the golden JSON byte pins (both fixtures), the canonical
key-set pin, the frozen `@golden` digests, the digest-determinism pin, and the
`from_map` round-trip all rejected the renamed key. Restored: exit **0**,
"Result: 33 passed".

One rename fans out into every law the file guards (canonical key set, byte
JSON, digest preimage, reader/writer agreement) — exactly the blast radius a
golden codec pin is supposed to have.

---

## Runner + discipline

`bash scripts/mutation_recipes.sh` executes all three recipes end-to-end:
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
