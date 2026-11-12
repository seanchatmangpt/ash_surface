# L14-conformance-constraints

Standing: PARTIAL_ALIVE — Tier A (fragment vectors) landed and green on both
replays; Tier B (value pass/fail + safeParse issue shapes) BLOCKED.

## Tier A — constraint -> zod projection vectors (LANDED)

New corpus kind `constraints` (`conformance/vectors/constraints.json`, 25
vectors, minted by `MIX_ENV=test mix run scripts/conformance_regen.exs` via
`AshSurface.Compiler.Schema.build/2` — no hand-typed expected values):

- Input = the schema section's discovery shape. Constraints ride on the
  ARGUMENT definition (`{"name","type","constraints"}`), NOT inside `type` —
  `Schema.zod_fragment/1` reads `definition["constraints"]`. Constraints nested
  inside `type` are silently ignored (an input-shape trap for projections).
- Expected = `{zod: {actionId: projection}, actionCount, argumentCount}` or the
  section's typed refusal `{error: {kind, detail}}` (kind normative).
- Coverage: one_of (strings/numbers/mixed/empty), min/max on numeric kinds,
  min_length/max_length and match on string kinds, ill-typed or non-applicable
  constraints silently dropped, frozen chain order
  (enum -> min/max -> min_length/max_length -> regex), allow_nil? composition,
  NewType subtype_of/subtype_constraints, quoted keys (`default?`),
  multi-argument order, malformed-discovery refusals.

JS side: `zodFragment`/`zodProjection`/`schemaProjection` twins in
`conformance/js/reference.mjs`; `HANDLERS.constraints` in
`conformance/js/replay.mjs` (error vectors compare `kind` only). All 25 PASS;
the mutation-detection ("replay can fail") test covers the new kind.

## Recorded divergence found while minting (c/match-slash)

`Schema.regex_constraint/2` escapes backslashes but NOT `/`: a `match` pattern
containing `/` renders `regex(/a/b/)` — an invalid JS regex literal. The
`AshSurface.Projector.Expo.map_zod_type/1` byte-mirror DOES escape `/`
(`escape_js_regex`). Per schema.ex's header law the two must not drift: this is
a mirror-contract break, pinned in the vector notes rather than fixed here
(schema.ex/expo.ex are outside this lane's owned files). Fix lane should escape
`/` in `regex_constraint/2` and regenerate the corpus — the `c/match-slash`
expected will flip.

## Tier B — BLOCKED: value pass/fail + safeParse issue shapes

The task asked for enum/min/max/min_length/match pass/fail against VALUES and
safeParse issue shapes `{path, message, code}` for representative failures.
Nothing in `lib/` evaluates a value against constraints: `safeParse` exists
only in JS-land (zod), and the corpus law (every `expected` minted by the real
Elixir implementation) forbids hand-fabricating or JS-minting issue shapes.

Missing exactly: a public Elixir evaluation surface, e.g.

    validate(definition, value) :: {:ok, value} | {:error, [%{path, message, code}]}

Once it lands, add `constraints_validation` vectors (`{definition, value}` ->
`{admits, issues}`) through the same regen path. Falsifier for that lane:
mutating one constraint must flip the recorded issue set for the value vectors
that exercise it (the corpus mutation test enforces this mechanically).

## Files

- `conformance/vectors/constraints.json` (minted, 25 vectors)
- `conformance/elixir/runner.exs` (+`run("constraints", _)`, +Schema alias)
- `scripts/conformance_regen.exs` (+constraints inputs)
- `conformance/js/reference.mjs` (+projection twins)
- `conformance/js/replay.mjs` (+HANDLERS.constraints)
- `docs/CONFORMANCE.md` (kind row, counts)
- `conformance/MANIFEST.json` (regenerated; 12 files, 572 vectors)

## See Also

`docs/CONFORMANCE.md` · `docs/jira/v26.11.11/receipts/L14.md`
