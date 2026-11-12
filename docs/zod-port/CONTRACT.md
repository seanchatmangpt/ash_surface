# Zod Port Lane Contract

Standing: UNVERIFIED

Plan: /Users/sac/.claude/plans/launch-20-explore-agents-cheerful-island.md (read it first).
Repo: /Users/sac/ash_surface (ONE canonical checkout; source reference /Users/sac/ash_typescript, read-only).

## Laws

- Edit ONLY your owned files. New files are yours if under your owned names. Need a change in
  another lane's file: do NOT edit; record it under "Requests" in your receipt.
- NO git state commands (no add/commit/stash/checkout/reset). Coordinator owns git.
- The tree has pre-existing uncommitted edits by others (schema.ex, expo.ex, js.ex, zod_guard.ex,
  ir.ex, ...). Read before editing; never revert or reformat them.
- Build isolation: `MIX_BUILD_ROOT=_build-laneNN mix ...`; delete that dir before your receipt.
- Tests: Chicago style, real collaborators, assert final state, no mocks (a mock-discipline court
  exists). Every emitted Zod string must pass `AshSurface.Projectors.JS.ZodGuard.admit/1`.
- Zod 4 only. Output byte-deterministic. Never hand-edit `lib/ash_surface/resource.ex` (generated).
- Compile-freeze SLA: if your edit breaks the shared compile, fix/revert within ~10 min; any lane
  may apply a minimal unblock to another's file and must disclose it in its receipt.
- Receipt: write `docs/zod-port/receipts/lane-NN.md`: H1, `Standing: PASS|PARTIAL|BLOCKED|UNVERIFIED`,
  files changed, commands run + real exit codes, test output tail, Requests, falsifiers.
  Never claim unrun work as done.

## Shared API (lane 01 creates; others code against it)

`AshSurface.Compiler.ZodType`:
- `fragment(definition :: map) :: String.t()` — same string-keyed definition shape that
  `compiler/schema.ex` `zod_fragment/1` takes today (`"type" => %{"kind"=>..}`, `"constraints"`,
  `"allow_nil?"`, `"subtype_of"`); returns the Zod expression incl. constraint chain.
- `base(kind :: String.t()) :: String.t()` — base fragment for a kind.
- `kinds() :: [String.t()]`.
Behavior: enum -> `z.enum([...sorted])` standalone; uuid -> `z.uuid()`; decimal -> string;
date/time/datetime/duration -> `z.iso.*`; nullable vs optional split (allow_nil? => `.nullable()`,
omittable => `.optional()`); regex literal escapes `\` and `/`.

## Lanes and owned files (lib/ash_surface/ unless noted)

01 ZodType core: compiler/zod_type.ex, compiler/schema.ex, projector/expo.ex, compiler/union_schema.ex; tests test/ash_surface/zod_type_*_test.exs
02 ZodGuard: projectors/js/zod_guard.ex; tests test/ash_surface/zod_guard_*_test.exs
03 Embedded/typed containers: compiler/embedded_schema.ex + tests
04 Filter: compiler/filter_schema.ex + tests
05 Query/page/sort/get: compiler/query_schema.ex + tests
06 Selection+relationship: compiler/selection_schema.ex, compiler/relationship_schema.ex + tests
07 Calc/aggregate: compiler/calculation_schema.ex + tests
08 Error schema: ir/error_shape.ex, compiler/error_schema.ex + tests
09 Error runtime: error_formatter.ex, error_handler.ex, errors.ex + tests
10 Route schema: compiler/route_schema.ex + tests
11 Channel schema: compiler/section/channel.ex + tests
12 DSL spec: ontology.ttl, ggen.toml, ggen.lock, semantic/*, resource/validator.ex, resource/info.ex (+ regenerate resource.ex via ggen only) + tests
13 Naming: naming.ex, field_name.ex + tests
14 Config: config.ex, config/verifier.ex + tests
15 Codegen task: lib/mix/tasks/ash_surface.codegen.ex, projectors/js.ex (emit returns artifacts; sole js.ex owner) + tests
16 Installer: lib/mix/tasks/ash_surface.install.ex, installer/*.ex + tests
17 IR wiring: ir.ex, compiler/ir.ex, ir/codec.ex, projector/ir_entry.ex, compiler.ex, compiler/capability.ex (integrate new schema fragments; sole owner of IR/digest changes)
18 Inference block: projectors/js/inference.ex + tests (JSDoc/.d.ts UnionToIntersection/InferResult, outside ZodGuard)
19 TS/Node test tree: test/ts/**, test/ash_surface/ts/*, test/support/zod_fixtures.ex, package.json devDependencies
20 Conformance/docs (runs LAST; wait-gate: poll docs/zod-port/receipts/ for lane-01..19, bounded <=45 min with
   Instant-style deadline polling, <=60s step, typed IN-FLIGHT fallback): conformance/**, scripts/conformance_regen.exs,
   docs/**, CHANGELOG.md, README.md, TESTING.md (raise floor to real count), then run full `mix test`, `npm test`.

## Wave 2 / wave 3 lane index

Standing per lane is the `Standing:` line of its receipt; capability status is in
`docs/jira/v26.11.11/PARITY-REGISTER.md`.

| lane | subject | receipt |
|---|---|---|
| wave2-b1a | schema section carries full type facts | receipts/wave2-b1a.md |
| wave2-ca | calculation/aggregate schema | receipts/wave2-ca.md |
| wave2-cf | config, codegen task, installer | receipts/wave2-cf.md |
| wave2-ds | DSL options (ggen regen) | receipts/wave2-ds.md |
| wave2-em | embedded schema | receipts/wave2-em.md |
| wave2-er | error contract | receipts/wave2-er.md |
| wave2-fl | filter schema | receipts/wave2-fl.md |
| wave2-id | identity/tenant schema | receipts/wave2-id.md |
| wave2-js | JS HTTP/channel transports | receipts/wave2-js.md |
| wave2-qs | query schema | receipts/wave2-qs.md |
| wave2-rc | routes, channels, envelope | receipts/wave2-rc.md |
| wave2-rs | relationship + selection | receipts/wave2-rs.md |
| wave2-un | union schema | receipts/wave2-un.md |
| wave2-zg | zod guard regex | receipts/wave2-zg.md |
| wave2-zt | zod type port | receipts/wave2-zt.md |
| wave3-01 | IR wiring | receipts/wave3-01.md (absent at w3-11 fill) |
| wave3-02 | js.ex schema emission | receipts/wave3-02.md |
| wave3-03 | codegen runtime copy | receipts/wave3-03.md |
| wave3-04 | conformance + docs/CONFORMANCE.md | receipts/wave3-04.md |
| wave3-05..08 | fixtures, ts tree, validator dispatch, inference/metadata | receipts/wave3-0N.md |
| wave3-09 | ontology/typed-query DSL | receipts/wave3-09.md |
| wave3-10 | formatter/hash courts | receipts/wave3-10.md |
| wave3-11 | docs/registers | receipts/wave3-11.md |
| wave3-12..18 | errors config, naming, constraint validator, order tests, vocabulary, digest | receipts/wave3-NN.md |
| wave3-f1p, f1t | persist fix, naming/typed-query DSL | receipts/wave3-f1p.md, wave3-f1t.md |
| wave3-s1a..s1i | skeptic-defect fixes | receipts/wave3-s1*.md |
