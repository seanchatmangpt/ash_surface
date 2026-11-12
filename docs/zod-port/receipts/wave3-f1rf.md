# Wave 3 F1-refs receipt

Standing: PARTIAL_ALIVE

## Decision
Option (a), narrowed. Exact recursion and shared-node declarations are implemented and
witnessed better than F1-embedref's inline-only/truncating output; the projector still calls
inline `EmbeddedSchema.render/2`, so wiring `render_program/2` into the artifact is open
(hence PARTIAL_ALIVE).

## Evidence (executed under node + zod 4.6.5)
- cycle_depth truncation (`z.record(z.string(), z.unknown())`) ACCEPTS an invalid value at
  depth 5 of a self-referential embedded resource (court asserts `true`). Inline-only was worse.
- `render_program/2`: cyclic resources become named consts with zod 4 getters; 5-deep valid
  accepted, invalid at depth 5 and depth 2 rejected, 40-deep valid accepted.
- Mutual cycle A<->B and diamond DAGs execute with declaration order REVERSED: no TDZ or
  ReferenceError (getters are lazy).
- Bytes, diamond DAG (depth, inline, named): (2, 109, 124), (3, 249, 209), (4, 529, 294).
  Inline is exponential in shared depth; named is linear; at depth 2 named costs 15 bytes more.
  Single-use acyclic resources stay inline (no declaration overhead).
- 1 MB cap: `cap_total/2` over all declarations plus expression -> `{:schema_too_large,..}`.
  `cycle_depth` + inline path of `render/2` unchanged.
- Nothing ash_typescript allows is impossible: named recursion is now exact. Cycles through a
  `union` stay inline (`{:cyclic_schema, _}` typed error).
- ZodGuard: `expression/2` / `admit/2` accept `identifiers: [...]` allowlist (value, chain root,
  `get key() { return <expr> }`); undeclared identifiers, `z`, dunder getters still refused;
  no allowlist = grammar unchanged.
- UnionSchema: member name / tag / discriminator `__proto__` -> `{:error, {:denied_field_name,
  "__proto__"}}` (court in embedded_program_court_test; union_schema_test re-pinned from
  guard-refusal to the earlier typed refusal).

## Commands
- `mix test embedded_program_court_test.exs`: 8 tests, 0 failures (exit 0).
- `mix test compiler/{embedded_schema,s1g_schema_courts,union_schema} projectors/ adversarial/
  no_local_do`: 282 tests, 2 failures, 3 skipped. Failure 1 (union_schema_test `__proto__`
  expectation) re-pinned and now green. Failure 2: RouteChannel adversarial seed=201 (RouteSchema
  emits `["__proto__"]` computed key, ZodGuard refuses) - not owned, pre-existing/other lane.
- union_schema_test + embedded_program_court: 21 tests, 0 failures. test/ash_surface_mock_discipline_test.exs NOT re-run (UNVERIFIED);
  no mocks added (Chicago, real node+zod).
- `mix format --check-formatted` on all changed files: exit 0.

## Files changed
lib/ash_surface/compiler/embedded_schema.ex, union_schema.ex,
lib/ash_surface/projectors/js/zod_guard.ex, docs/KNOWN_DIVERGENCES.md (KD-02 row, register
text), test/ash_surface/compiler/embedded_program_court_test.exs (new), union_schema_test.exs.

## Court-map ids for the coordinator (parity/court_map.json not edited)
- Divergence entry: `{"status":"divergence","kd":"KD-01"}` for embedded/typed-struct
  named-reference capability; court `test/ash_surface/compiler/embedded_program_court_test.exs`.
- Union `__proto__` refusal: same court file, describe "UnionSchema __proto__".

## Open
- Wire `render_program/2` declarations into JS projector (`ZodGuard.admit(zod, identifiers:)`).
- Renumbered KD-01 -> KD-02 by F1-refwire (filters keep KD-01).

`_build-f1rf` deleted.
