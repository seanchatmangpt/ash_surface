# L01-constraint-intake

## Goal

Ash constraint intake in the discovery adapter canon
(`AshSurface.Compiler.AshTruth`): constraints declared on action arguments
survive into the compiler output (IR inputs + rendered `ash` section), with
NewType unwrapping, per the shared IR contract. Fail closed: unknown
constraint keys are dropped (never guessed), nil constraints normalize to
`%{}`.

## Design

- Admitted constraint vocabulary (the only keys that survive):
  `:min`, `:max`, `:min_length`, `:max_length`, `:match`, `:one_of`.
- `inputs/1` per argument:
  - `constraints` = `argument.constraints` filtered through the admitted
    vocabulary (`Keyword.take` -> `Map.new`); nil -> `%{}`.
  - NewType detection via `Ash.Type.NewType.new_type?/1`; `subtype_of` =
    `type_name(Ash.Type.NewType.subtype_of/1)` (recursive unwrap);
    `subtype_constraints` from the module's `constraints/0` +
    `subtype_constraints/0` (declared wins over own on key collision),
    same admitted-key filter.
  - `match` normalization: Ash hands Spark's regex cache tuple
    (`{Spark.Regex, :cache, [source, opts]}`) or a `%Regex{}`; the declared
    source string is extracted — the cache is evaluation machinery.
- Verifier: input maps move from exact-keys to subset law — the four v29 keys
  (`name`, `type`, `required`, `default`) remain required; the three L01 keys
  (`constraints`, `subtype_of`, `subtype_constraints`) are admitted
  additions; anything else is still refused as
  `{:fabricated_fact, :input, keys}`. `admitted_keys/0` exposes the extended
  input key list. `input_fact/1` always renders the three new keys
  (`%{}` / `nil` / `%{}` defaults) for downstream consumers (L02 schema
  rendering reads `subtype_of` / `subtype_constraints`).

## Decisions

- **Struct-attach is dual-mode.** `IR.Input` (ir.ex) is owned by a concurrent
  lane and did not carry the three new fields at L01 landing. The canon sets
  them directly once the struct supports them (`Map.has_key?`), and until
  then attaches via `Map.merge` ONLY when there is real intake data, so
  unconstrained inputs stay byte-identical to the v29 emission (existing
  exact-equality courts in `ash_section_test.exs` stay green). When the ir.ex
  extension lands, always-carry behavior activates without further edits.
- **No guess, ever.** Ash's DSL validator rejects unknown constraint keys at
  resource-compile time (witnessed: `[:weird]` refused for `:integer`), so the
  take-only filter is defense in depth, not the primary gate.
- **Atoms verbatim.** `one_of: [:a, :b]` stays atoms — it is the declared
  truth; stringification belongs to the renderer, not the intake.

## L16 hand-off (test need)

`test/ash_surface/compiler/ash_section_test.exs` L105-112 exact-equality
fixtures must gain `constraints: %{}` / `subtype_of: nil` /
`subtype_constraints: %{}` once the ir.ex struct extension lands (defaults
nil make bare fixtures unequal to built structs). New courts wanted: integer
`min`/`max`, string `min_length`/`max_length`/`match` (incl. Spark cache-tuple
normalization), `one_of`, NewType subtype unwrap, nil constraints -> `%{}`.

## See Also

`receipts/L01.md` · `lib/ash_surface/compiler/schema.ex` (L02 consumer) ·
`test/ash_surface/compiler/schema_constraint_test.exs` (L04/L05/L16 courts)
