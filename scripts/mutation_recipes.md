# Mutation recipes — proven-deadly mutations for the golden guards

Chicago-school law: a guard that cannot fail guards nothing. Each recipe below
is a minimal, deterministic mutation of a REAL subject (an on-disk artifact or
a producer module) that MUST flip its guarding test RED, and must return GREEN
when the subject is restored. `scripts/ci_falsifier.sh` executes the bounded
subset wired into CI (ticket chicago-ci-falsifier-049); the full-family
execution receipts live in `docs/jira/v26.9.17/chicago-golden-mutation-041.md`.

Every recipe is executed against the working tree, then reverted with
`git checkout -- <subject>`. The falsifier refuses to run on a dirty tracked
tree so the restore is lossless by construction.

## Family 1 — runtime SHA (`test/ash_surface/runtime_source_test.exs`)

Guarded artifact: `priv/static/ash_surface_runtime.mjs`, pinned whole-file by
`@golden_runtime_sha256` (SHA-256 law).

### Recipe `runtime-sha-whitespace` (whitespace injection)

```console
$ printf '\n' >> priv/static/ash_surface_runtime.mjs
$ mix test test/ash_surface/runtime_source_test.exs   # RED: golden SHA-256 mismatch
$ git checkout -- priv/static/ash_surface_runtime.mjs
$ mix test test/ash_surface/runtime_source_test.exs   # GREEN
```

One appended newline byte changes the whole-file SHA-256, so both the frozen
golden and the source==disk equality assertions fail.

## Family 2 — contract digest (`test/ash_surface/digest_test.exs`)

Guarded subject: the private digest canon in `lib/ash_surface.ex`
(`canonical_term/1 -> term_to_binary -> sha256 -> Base.encode16(case: :lower)`),
pinned by the five `@golden` fixture digests.

### Recipe `digest-hexcase-flip` (producer mutation)

```console
$ perl -pi -e 's/Base\.encode16\(case: :lower\)/Base.encode16(case: :upper)/' lib/ash_surface.ex
$ mix test test/ash_surface/digest_test.exs           # RED: every golden is lowercase hex
$ git checkout -- lib/ash_surface.ex
$ mix test test/ash_surface/digest_test.exs           # GREEN
```

Flipping the hex encoding case deterministically mismatches all five frozen
lowercase digests. (Note: un-sorting `canonical_term/1` is NOT a valid recipe —
`to_map`-shaped fixtures are already key-sorted, so the golden may survive;
that silence is exactly why the recipe pins the encoding step instead.)

## Family 3 — IR codec golden (`test/ash_surface/ir_codec_golden_test.exs`)

Guarded subject: the locally declared codec producer (the canonical modules are
declared inside this test file at this commit — see its header block), pinned
by frozen golden JSON bytes and digests.

### Recipe `irgolden-presentation-fielddrop` (field drop)

```console
$ perl -pi -e 's/\@presentation_fields ~w\(format group label order widget\)/\@presentation_fields ~w(format group order widget)/' test/ash_surface/ir_codec_golden_test.exs
$ mix test test/ash_surface/ir_codec_golden_test.exs  # RED: golden JSON loses "label"
$ git checkout -- test/ash_surface/ir_codec_golden_test.exs
$ mix test test/ash_surface/ir_codec_golden_test.exs  # GREEN
```

Dropping `label` from `@presentation_fields` starves `to_map/1`: the canonical
JSON loses `"label"` from the presentation section, so the frozen-byte
assertions fail. The subject lives in the guard's own file at this commit; the
mutation edits the producer half (field list), never the frozen goldens.

## Tripwire canaries

The falsifier also re-proves, on pristine HEAD, that the standing tripwire
suites are GREEN (a red canary fails the job before any mutation runs):

```console
$ mix test test/ash_surface/no_local_do_test.exs \
           test/ash_surface/handwritten_ledger_test.exs \
           test/ash_surface/standing_test.exs \
           test/ash_surface/transport_falsifiers_test.exs \
           test/ash_surface/refactor_safety_net_test.exs
```
