# Wave 3 F1-refwire receipt

Standing: PASS

Scope: named-reference wiring, KD renumber, `__proto__` path-param refusal; courts below green.
Unrelated failures in other lanes' files are listed under Commands.

## KD collision

F1-refs and F1-divclose both used KD-01. Filters (`not` array) keep KD-01; embedded/typed-struct
named references are now KD-02 (KD-03/KD-04 already taken by F1-kd rows). Updated:
`docs/KNOWN_DIVERGENCES.md` (row id, court -> `test/ash_surface/projectors/js_named_refs_test.exs`,
receipt -> this file, close condition -> none), `docs/zod-port/receipts/wave3-f1rf.md` (cited ids),
`parity/court_map.json` (`codegen.module.Codegen.ZodSchemaGenerator` pass -> divergence KD-02;
the two prior pass tests remain in the suite, they no longer are that cell's evidence).

## Wiring

- `Compiler.Schema.render_zod/4` uses `EmbeddedSchema.render_program/2`; declarations are
  emitted as `const <Name>ZodSchema = ...;` lines before the `export const ..._inputSchema` pair
  (same identifier with a different body -> `{:declaration_conflict, name}`).
- `ZodGuard.admit/2` accepts the leading declarations, admitting every body and the program with
  the declared-identifier allowlist; new `ZodGuard.declarations/1`; duplicates refused
  (`{:zod_duplicate_declaration, n}`), declarations without a program refused.
- `Projectors.JS` carries the declarations beside the admitted form, dedups them across
  entries, emits them once at top level before the schema consts, checks them in
  `check_bindings` (collision -> `{:js_binding_collision, n}`).
- Court `test/ash_surface/projectors/js_named_refs_test.exs` (real Compiler.Schema -> IR ->
  Projectors.JS -> node + zod 4): cyclic 5-deep (valid/invalid-at-5/invalid-at-2/40-deep),
  mutual cycle with declaration order reversed in the artifact, diamond, guard refuses
  undeclared identifier.

## `__proto__`

RouteSchema argument `__proto__` was already refused (S2b-b). Residual closed:
`check_path_params/3` returns `{:error, {:denied_path_param_name, route, "__proto__"}}` for
`/a/:__proto__` and `/a/*__proto__`; court in `test/ash_surface/route_schema_test.exs`.

## Commands (MIX_BUILD_ROOT=_build-f1rw)

- `mix test projectors/js_named_refs_test.exs route_schema_test.exs`: 14 tests, 0 failures.
- `mix test test/ash_surface/adversarial`: 133 tests, 0 failures (RouteChannel seed=201 green).
- `mix test projectors compiler adversarial parity route_schema no_local_do mock_discipline`:
  582 tests, 3 failures, none in my files: (1) schema_section_test Expo canon `z.record(..,
  z.unknown())` vs `z.any()` (other lane); (2) no_local_do
  `runtime_parity/requested_fields/field_selector.ex` `Ash.Query.for_read` (other lane);
  (3) parity gate_test live-register lint: receipt for KD-02 was missing until this file;
  KD-03/KD-04 cite `wave3-f1kd.md` (F1-kd, not yet landed at run time).
- `mix format --check-formatted` on schema.ex, route_schema.ex, zod_guard.ex, js_named_refs_test:
  clean. `projectors/js.ex` and `route_schema_test.exs` were already unformatted before this lane
  (blank-line / long-line hunks outside my edits); left untouched (shared files).

## Conformance

Not regenerated (F1-confregen owns it). Moves expected: any vector rendering an action whose
arguments reference cyclic or multiply-referenced embedded resources (schema zod text, hence IR
digest); JS projector artifacts for such IRs. No vector was run or compared by this lane.

## Open

- Declaration identifiers are planned per argument; a conflict across arguments is refused, not
  merged (a single cross-argument plan would remove that refusal).
- `_build-f1rw` deleted.

## Re-witness (F1-missing)

- PASS: `mix test test/ash_surface/projectors/js_named_refs_test.exs` (28 tests across the F1-missing
  run with the codegen task and errors courts, 0 failures, exit 0): the KD-02 named-reference court.
