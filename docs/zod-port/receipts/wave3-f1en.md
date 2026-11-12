# Wave 3 F1-enum receipt

Standing: PASS

Scope: top-level `test/ash_surface/schema_section_test.exs` enum goldens re-pinned; new executed
enum court `test/ash_surface/enum_zod_court_test.exs`. No lib change (no regression found).

## Baseline

`MIX_BUILD_ROOT=_build-f1en mix test test/ash_surface/schema_section_test.exs` -> 18 tests,
6 failures, rc=2 (reports cited ~6-10; measured 6 this run). The compiler/ copy
(`test/ash_surface/compiler/schema_section_test.exs`) already passes 23/0 (its `:311` map/any
expectation no longer fails; map fragments there and here are `z.record(z.string(),
z.unknown())`, consistent with KD-05, docs/KNOWN_DIVERGENCES.md; nothing to re-pin).

## Who / why

`lib/ash_surface/compiler/zod_type.ex` `enum_fragment/2` (lines ~330-348) and `base_for("enum")`:
`one_of` / enum `values` render a sorted, uniq'd, string-coerced `z.enum([...])` (numeric kinds:
literal union). The goldens in the top-level file predate this and pinned the old
`z.unknown()` canon. Reference: `~/ash_typescript/lib/ash_typescript/codegen/schema_core.ex`
`format_enum_values/2` (sort_by `to_string`, quoted) + `zod_schema_generator.ex:110`
`format_enum` -> `z.enum([...])`; atoms without one_of -> plain string. Ours is byte-identical
to the reference for string/atom values. Nil-able decoration `.nullable().optional()` is the
documented rule (zod_type.ex moduledoc; expo.ex:478).

## Per-test decisions

| # | test (line pre-edit) | expected (old) | actual | decision | evidence |
|---|---|---|---|---|---|
| 1 | golden zod strings :271 (enum, allow_nil?, nested array allow_nil?) | `z.unknown()`, `z.unknown().nullable()`, `z.array(z.guid()).nullable()` | `z.enum(["active","paused"])`, `z.enum(["a"]).nullable().optional()`, `z.array(z.guid()).nullable().optional()` | RE-PIN | reference parity + enum court; nullable rule per zod_type.ex doc |
| 2 | no-rediscovery :310 | `status: z.unknown()` | `status: z.enum(["active","paused"])` | RE-PIN | same; `@enum_ap` |
| 3 | enum values projects to unknown canon :209 | `z.unknown()` | `z.enum(["active","archived","paused"])` (sorted) | RE-PIN | reference sorts by to_string |
| 4 | allow_nil key :246 | `z.unknown()` | `z.enum(["a"]).nullable().optional()` | RE-PIN (allow_nil now decorates) | zod_type.ex omittable/nullable |
| 5 | no enum literal fabricated :214 | refute `z.enum(`/`active` | `z.enum([...])` present | RE-PIN (renamed: asserts z.enum, refutes z.literal) | reference |
| 6 | mixed nested resource :236 | `status: z.unknown()` | `status: z.enum(["active","paused"])` | RE-PIN | same |

No regression: values kept, sorted, string wire (atoms -> strings), none lost.

## Court added

`test/ash_surface/enum_zod_court_test.exs`: real node + real zod. Members accepted; `deleted`,
``, `Active`, `":active"`, 1, null, array, object rejected; verdicts identical to the reference
form `z.enum(["active","archived","paused"])`; atom/string/one_of/kind:"enum" inputs project to
one string.

## Commands (all `MIX_BUILD_ROOT=_build-f1en`)

- enum court + schema_section (both copies): 43 tests, 0 failures, rc=0.
- `test/ash_surface_mock_discipline_test.exs test/no_local_do_bang_court_test.exs
  test/no_local_do_test.exs`: 2 tests, 0 failures, rc=0.
- grep Process.sleep/Mox/mockall in new court: 0 matches.

## Conformance movement (not regenerated; FINAL-REGEN)

`test/conformance/conformance_replay_test.exs`: 28 tests, 2 failures, rc=2. Drift only in
`filter_operators.json` (10 vectors; string fields now admit gt/gte/lt/lte ops: not enum
rendering, other lane). No vector drift attributable to enum projection.

## Falsifier

Reverting `enum_fragment/2` to `z.unknown()` must fail the enum court and the 6 re-pinned tests.
Not executed as a shim court this lane (UNVERIFIED).
