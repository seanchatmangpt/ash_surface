# PARITY-REGISTER

Standing: PARTIAL

Source of truth for capability parity: ash_typescript capability surface x ash_surface status
(milestone v26.11.11). Other docs link here and do not restate counts. Re-derived at fill time
(wave 3 lane w3-11; refilled by lane REG-refill from receipts on disk) from `lib/` on disk and from `docs/zod-port/receipts/`; no remembered
counts. Superseded the lane-L24 register (which predated wave 2/3).

Vocabulary: ALIVE = code + executed court cited by a receipt with Standing PASS/ALIVE;
PARTIAL = code on disk, receipt Standing PARTIAL/PARTIAL_ALIVE or open items named;
MISSING = no surface in `lib/`; NON-GOAL = excluded with a reason (below); UNVERIFIED =
code seen on disk but no receipt backs it (IN-FLIGHT-AT-FILL when the receipt is pending).

Divergence law (2026-11-11): a divergence from ash_typescript is not an acceptable end state
unless ash_surface is better and a court witnesses it. Rows marked BETTER cite the court.

Refill gate: `wave3-01.md` (Standing PARTIAL) is now on disk; the IR wiring row is re-read from
it. `wave3-04.md` (PARTIAL) is cited for conformance only.

## Register

| Capability | Status | Evidence | Closing receipt / open items |
|---|---|---|---|
| Filters | PARTIAL | `lib/ash_surface/compiler/filter_schema.ex:145` `render_filter_schema/2`; IR call `compiler/ir.ex:244`; emitted by `projectors/js.ex` (`<id>_filter_schema`) | `wave2-fl` PASS, `wave3-02` PARTIAL_ALIVE. BETTER: zod `discriminatedUnion("op")` throws at first `safeParse` (duplicate discriminator); every union is now `z.union`, pinned by `filter_schema_executed_test.exs`. CLOSED (F1-divclose, KD-01): `not` accepts single filter or array; related destinations accept nested and/or/not (depth 1), `wave3-f1dc` PASS. Open: `max_depth` capped 0..3; `functions` is metadata only |
| Sorts | ALIVE | `compiler/query_schema.ex:71` `render_sort_schema/2` | `wave2-qs` PASS; zod 4 string-arg `.regex` fixed to regex literal in `wave3-s1f` and `RegExp` at embed site in `wave3-02` |
| Pagination | ALIVE | `compiler/query_schema.ex:50` `render_pagination_schema/0`, offset/keyset/page result schemas | `wave2-qs` PASS. Open: fallback `max_limit` 500 is not an Ash fact |
| Field selection | PARTIAL | `compiler/selection_schema.ex:49` `render_selection_schema/3`; IR call `compiler/ir.ex:396`; typed-query nested selection `resource/typed_query_fields.ex` | `wave2-rs` PASS, `wave3-09` PARTIAL, `wave3-f1t` PASS, `wave3-s1i` PASS. Server-side evaluation is NON-GOAL |
| Aggregates | PARTIAL | `compiler/calculation_schema.ex` (kinds incl. last/custom; sum/avg nullable) | `wave2-ca` PASS, `wave3-s1a` PASS. CLOSED (F1-divclose, a): aggregate names selectable in `fields` as in ash_typescript (court `divergence_close/aggregate_selection_test.exs`, `wave3-f1dc`); per-aggregate result schemas live in `render_aggregate_schemas` |
| Calculations | PARTIAL | `compiler/calculation_schema.ex:71` `render_calculation_schema/1`; IR call `compiler/ir.ex:406` | `wave2-ca`, `wave3-s1a` (H1 envelope strict object). UNVERIFIED: union_facts path of complex results not exercised (`wave2-ca`) |
| Relationships | PARTIAL | `compiler/relationship_schema.ex:66` `render_load_schema/2`; IR call `compiler/ir.ex:373` | `wave2-rs` PASS, `wave3-s1a`, `wave3-s1i` (ambiguous-name refusal). Open: relationship-facts discovery producer (request in `wave2-rs`); `z.literal(true)` shorthand kept |
| Embedded | PARTIAL | `compiler/embedded_schema.ex:87` `render/2` (arrays, unions, typed containers, cycle -> record) | `wave2-em` PARTIAL; `wave3-15` PARTIAL_ALIVE (declaration order via inlining; shared-const Kahn order is a loud skip: embedded resources are inlined) |
| Unions | ALIVE | `compiler/union_schema.ex:54` `render_members/2` (member-keyed `z.union`), tagged `render_union_schema/1,2` retained | `wave2-un` PASS (node+zod executed). Open: real `EmbeddedSchema` container members only exercised via `map` kind |
| Identities / get | PARTIAL | `compiler/identity_schema.ex:56` `render_get_schema`, `:104` `render_tenant_schema`; IR call `compiler/ir.ex:335`; get input canonical in `QuerySchema.render_get_input_schema/1` (`query_schema.ex:302`) | `wave2-id` PARTIAL, `wave3-s1i` PASS. Open: `identity_schema.ex` treats missing `require_tenant_parameters` as required; `config.ex` default is false (`wave3-s1b` M12) |
| Multitenancy | PARTIAL | `compiler/identity_schema.ex:104`; IR call `compiler/ir.ex:358`; DSL `AshSurface.Domain` (`lib/ash_surface/domain.ex`) | `wave2-id`, `wave3-f1t` PASS. Open: M12 divergence above; no tenancy runtime projection beyond the schema |
| Typed queries | PARTIAL | `compiler/query_schema.ex:264` `render_typed_query_input_schema/2`; DSL entity `resource/typed_query_fields.ex`, `Info.typed_query/2` | `wave3-09` PARTIAL, `wave3-f1t` PASS |
| Channels | PARTIAL | `compiler/section/channel.ex:42` `build/2`; `compiler/channel_discovery.ex:36`; `ash_surface_channel_transport.mjs:47` | `wave2-rc` PASS, `wave2-js` PARTIAL. Integration of discovery into `compiler.ex` UNVERIFIED (`wave2-rc`). Phoenix channel DSL: NON-GOAL |
| Routes | PARTIAL | `compiler/route_schema.ex`, `route_schema/introspector.ex` | `wave2-rc` PASS (node-executed params/query/body). Router wiring into IR UNVERIFIED |
| Errors | PARTIAL | `errors.ex:148` `classify/1`, `compiler/error_schema.ex:114`, `compiler/validation_error_schema.ex`, `error_formatter.ex` | `wave2-er` PARTIAL, `wave3-12` PASS, `wave3-s1b` PARTIAL_ALIVE. Open: `zod_object_mode` has no render consumer; `ErrorFormatter.apply_field_names/3` unwired to `Errors`/`ErrorSchema.carry/2` |
| Config / codegen / installer | PARTIAL | `config.ex`, `config/verifier.ex`, `mix/tasks/ash_surface.codegen.ex` (`--check`, `--runtime`), `installer/installer.ex:6` | `wave2-cf` PARTIAL (idempotence court BLOCKED by fixture then), `wave3-03` PASS, `wave3-10` PARTIAL. Formatter plugin retired; `.formatter.exs` exports `projection: 1/2` |
| Runtime transports | ALIVE | `priv/static/ash_surface_http_transport.mjs:117`, `ash_surface_channel_transport.mjs:47`; `transport.ex:226` `classify_failure/2`; `ash_surface.ex:434` `digest/1` | `wave2-js` PARTIAL, `wave3-s1e` PASS, `wave3-17` PARTIAL, `wave3-18` PARTIAL_ALIVE (real `node:http` server courts) |
| Constraints | PARTIAL | `compiler/zod_type.ex:132` `fragment/2`, `:364` `regex_safe_for_js?/1`; `compiler/constraint_validator.ex:35`; schema-section facts via `compiler/type_facts.ex` | `wave2-zt` PARTIAL, `wave2-zg` PASS, `wave2-b1a` PARTIAL, `wave3-14` PASS (AGREEMENT 424/424 vs real zod), `wave3-s1f` PARTIAL_ALIVE. BETTER: `uuid`/`uuid_v7` -> `z.uuid()` (`wave3-s1f`). `wave3-04` PARTIAL (conformance corpus; replay goes RED if a renderer changes before regen) |
| Metadata | PARTIAL | `lib/ash_surface.ex` (profile metadata under `custom.ash_surface`); `show_metadata`/`metadata_field_names` DSL; `projectors/js/inference.ex` | `wave3-08` PARTIAL (2 loud skips) |
| IR wiring of the above renderers | PARTIAL | `compiler/ir.ex:244,331-335,358,373,396,406` call the renderers; `compiler/resource_facts.ex`; `test/ash_surface/compiler/ir_wiring_test.exs` | `wave3-01` PARTIAL (owned tests pass; 9 failures in the run set outside owned files). IR digest re-pinned; `conformance/vectors/ir_codec.json` stale until `wave3-04` regen. UNVERIFIED: `get` result schema and `response_zod` stay nil (`no_record_schema`); manifest path tested with hand-built actions only |

## NON-GOAL rows

| Capability | Reason |
|---|---|
| valibot | Zod 4 is the single validation calculus; N implementations of one calculus drift (CONTRACT law "Zod 4 only") |
| Typed controllers codegen | Phoenix controller surface is not part of the manifest projection; routes are descriptors plus a JS analogue only |
| Lifecycle hooks | No client hook surface; the only "hook" in `lib/` is a comment in `zod_guard.ex` |
| Server-side field evaluation | `fields` is admitted and refused at the client boundary; evaluation belongs to Ash |
| `.ts` / `.d.ts` emission, `tsc` | README stance: "There is no TypeScript support contract in ash_surface: no generated .ts, no .d.ts, no tsc build step". The inference block (`projectors/js/inference.ex`) is JSDoc-side and not wired into `js.ex` |
| Phoenix channel DSL / interception | Channels are descriptor + JS analogue; interception is a server runtime concern |

## Defects

- **D-L24-1: CLOSED.** `test/ash_surface/query_schema_test.exs` and
  `test/ash_surface/query_schema_wave2_test.exs` cite `QuerySchema` (node+zod executed per
  `wave2-qs`).
- **D-L24-2: OPEN, UNVERIFIED.** `test/ash_surface/projectors/js/` showed `??` in a read-only
  status snapshot at fill. This lane cannot run git; coordinator to confirm it is tracked
  before commit.

## See Also

`_LANES.md` · `OVERVIEW.md` · `COMPARISON-ash-typescript.md` · `PARITY-WAVE2-BACKLOG.md` ·
`../../zod-port/receipts/` · `../../zod-port/CONTRACT.md`
