# Wave 3 S2: adversarial courts for Phase-A renderers

Standing: PARTIAL_ALIVE

Reason for PARTIAL_ALIVE: 2 defects registered (skipped courts); RouteSchema and Section.Channel
courts are structural only (their emitted zod was not exercised with hostile names).

## Commands (MIX_BUILD_ROOT=_build-s2, dir deleted afterwards)

- `mix test test/ash_surface/adversarial` -> exit 0, 126 tests, 0 failures, 2 skipped.
- `mix test test/ash_surface/adversarial test/ash_surface/no_local_do_test.exs
  test/ash_surface_mock_discipline_test.exs` -> exit 0, 133 tests, 0 failures, 2 skipped.
- `mix format --check-formatted test/ash_surface/adversarial/*.exs` -> exit 0.
- `node --test test/js/adversarial/` -> 15 tests, 15 pass, 0 fail (real zod 4.6.5 via
  priv/static/ash_surface_runtime.mjs schemas).
- Not run: full `mix test` (shared tree, other lanes in flight).

## Files (new only)

- test/ash_surface/adversarial/support.exs (shared harness: one node process per
  expression, real zod, seeded `:rand`, ZodGuard.admit/1 first)
- test/ash_surface/adversarial/container_renderers_adversarial_test.exs
- test/ash_surface/adversarial/envelope_renderers_adversarial_test.exs
- test/js/adversarial/runtime_zod_adversarial.test.mjs

`mix test <dir>` prints a benign warning that support.exs matches no test pattern (it is
`Code.require_file`d by both test files).

## Method

`S2.classify/2`: renderer `{:error,_}` = lawful typed refusal; `{:ok, expr}` must pass
ZodGuard.admit/1, load in node without throwing, and agree with the Elixir-side accept/reject
expectation for every payload. Seeds are in test names (property style, no StreamData).
Inputs: quotes, backslashes, newline, CR, U+2028/2029, `__proto__`, `constructor`, `toString`,
unicode/emoji, NUL, `${x}`, empty/duplicate names, atom- vs string-keyed defs, nil defs, numbers
0/negative/2^53-1, depth 0/1/2/8.

## Per-renderer test counts (Elixir, 126 total)

EmbeddedSchema 23, ZodType 15 (bounds, depth, nil/atom-keyed), QuerySchema 12, UnionSchema
members 11 + tagged facts 4, ErrorSchema/ValidationErrorSchema 10, SelectionSchema 9,
FilterSchema 9, RelationshipSchema 8, IdentitySchema 8, CalculationSchema 8, Section.Channel 3,
RouteSchema 3, `__proto__` group 3 (1 run, 2 skipped).
Renderer files with no dedicated count: none from the Phase-A list is absent.

## Regression courts added for claimed S1 fixes (executed under zod)

S1-A: per-calc args binding (M5), `exposed:false` (M6), invalid `max_depth` typed error, many-
cardinality limit/offset vs page exclusivity. S1-B: variants load, base passthrough, junk type
no-raise. S1-F: invalid `max_limit` typed error (L4), limit required only when pagination
required and no default (`default_limit?: true` flips). S1-I: identity name collision typed error
(L1). S1-E (HTTP transport) is covered by its own node tests, not duplicated.

## Defect requests (courts skipped with `DEFECT <id>`)

### S2-01 EmbeddedSchema emits guard-refused expression for `__proto__`
- Input: `EmbeddedSchema.render(%{"type" => %{"kind" => "typed_map", "fields" =>
  [%{"name" => "__proto__", "type" => %{"kind" => "string"}}]}})`
- Expected: `{:error, _}` typed refusal, or an expression ZodGuard admits (consistent with
  UnionSchema/CalculationSchema which refuse typed, RelationshipSchema which returns
  `{:error, {:zod_guard_refused, _}}`).
- Actual: `{:ok, expr}` where `ZodGuard.admit(expr)` ->
  `{:error, {:zod_denied_key, "\"__proto__\""}}` (captured by un-skipped run).
- Court: `__proto__ field name ... EmbeddedSchema typed_map with __proto__ field`.

### S2-02 IdentitySchema emits guard-refused expression for `__proto__`
- Input: `IdentitySchema.render_get_schema([%{"name" => "i", "keys" => [%{"name" => "__proto__",
  "type" => %{"kind" => "string"}}]}], [])`
- Expected: `{:error, _}` or a guard-admitted expression.
- Actual: `{:ok, %{"i" => expr}}`, `ZodGuard.admit(expr)` -> `{:error, {:zod_denied_key,
  "__proto__"}}`.
- Court: `IdentitySchema with __proto__ key`.

(Downstream effect: any manifest field named `__proto__` fails the projector's guard late rather
than at the renderer.)

## Observations (no defect)

- Pagination `.optional()` accepts `undefined`, not JSON `null` (courts pin this).
- Seeded name generator excludes `__proto__` (covered by the dedicated group) so S2-01/02 do not
  mask other seeds.
- Untested depth: RouteSchema.build and Channel.build emitted zod under hostile names (no
  zod-bearing outputs were driven; only no-raise / typed-result courts).
