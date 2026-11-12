# PROJECT-REVIEWS

Standing: UNVERIFIED

Read-only review findings for the user's other Elixir projects (lanes R1-R12). Findings are
as reported by each reviewer lane (code read, tests not run) and carry its CONFIRMED or
UNVERIFIED label. Re-verify before acting.

## R1 ash_a2a + ash_a2a_head

HIGH:
- `ash_a2a_head/lib/ash_a2a/authority/source/allow_all.ex:13` `check/_ -> :ok` has no prod
  guard (working tree adds one at `ash_a2a/.../allow_all.ex:15-25`, uncommitted). CONFIRMED.
- Tracked code depends on untracked files: `protocol/task/orphan_sweep.ex`,
  `telemetry/dispatch_event.ex`, `verifiers/verify_hddl_operators.ex`, `wire/jcs.ex`,
  `test/support/eventually.ex`, `scripts/sleep_gate.sh`. A clean checkout breaks. CONFIRMED.

MED: bare `rescue` falls back to unscoped vendored plug (`a2a_transport/plug.ex:319-321`);
orphan sweep `:ok = store_mod.put` MatchError inside runtime, unbounded `list_all`, no CAS,
local-only `live?`; sweep errors swallowed (`runtime.ex:440`); `ash_graphlaw` path-vs-Hex
build skew (`mix.exs:353-360`); `AshA2A.Schema` embedded recursion has no cycle guard
(`schema.ex:440-466`); `required` ignores defaults (`schema.ex:217`).

LOW: 53 unannotated `Process.sleep` in test/ and ungated by `sleep_gate.sh`; atom minting
from CLI args; narrow mock-discipline grep (misses hand-rolled fakes); stale CHANGELOG;
Decimal mapped to JSON number (UNVERIFIED).

Reusable for ash_surface: `schema.ex` for_action/build (typed unserializable-type errors),
`capability_index/compiler.ex` + `validator.ex` (stable ids, fail-closed gate),
`identity/canonical.ex` (JCS + sha256 digest), `transport/schema_endpoints.ex`.

Lesson applied to ash_surface: embedded cycle guard and defaults-vs-required are already
covered by `EmbeddedSchema` cycle_depth and ZodType optionality; re-check in S2 courts.

## R2 ash_affidavit + ash_atlassian

ash_affidavit (all CONFIRMED by reader):
- HIGH `signing.ex:457-463` `hex_arg/2` never validates hex: `Base.decode16/2` returns
  `{:ok,_}|:error`, both truthy as the last `and` operand, so any even-length binary passes
  as "hex" (raw bytes get JSON-encoded). Raw-bytes path untested.
- MED `signing.ex:352-356` `decode_subject_digest_payload/2` returns bare `:error` (no `else`),
  violating its spec; caller raises `CaseClauseError`.
- MED `chain_verifier.ex:29-42` verifies against a caller-supplied key only: self-consistency,
  not authenticity; docs never say so.
- MED stale docs: `Signing` moduledoc (`signing.ex:11-21`) denies ops it implements;
  `chain_verifier.ex:8-12` claims a delegation that does not exist.
- MED untracked `docs/diataxis/reference/descriptors/` referenced from `mix.exs` extras;
  old `reference/generated/*` deleted but unstaged: clean checkout fails the docs build.
- LOW `keys.ex:139-147` PQ/unknown algs pass structurally unchecked; mislabelled RFC 8032
  vector; vacuous `doctest ChainVerifier`.

ash_atlassian:
- MED `architecture_governance.ex:173-203` `verify_work_order/1` is self-referential: stale
  check cannot fail. MED untrusted floats/structs raise `ArgumentError` in `canonical_digest`
  instead of refusing (`:254`, `registry.ex:~110`). MED append-only ledger is policy-only,
  `verify_chain/2` cannot detect tail truncation; all governance resources define `:destroy`.
- LOW coarse error mapping in `Registry`; tautological ETS round-trip test
  (`closure_feedback_projection_test.exs:15-69`); `ggen_gates_test.exs:15-16` silently skips
  without ggen; README cites a nonexistent ARD.

Reusable for ash_surface: closed code->class refusal registry with compile-time atoms
(`ash_affidavit/refusal.ex:91-189`); key-shape laws as declarative refinements
(`signing/keys.ex:139-220`); canonical encode+digest with golden (`architecture_governance.ex:213-254`);
ontology->attribute map (`ash_atlassian/semantics.ex:12`).

## R4 ash_ex4pm + ex4pm (all CONFIRMED by reader unless marked)

HIGH:
- Idempotent replay skips the BRCE authority check: `ash_ex4pm/lib/ash_ex4pm/changes/
  receipted_action.ex:116-121,166-173,238-263`; store key `{resource, action, key}` and
  fingerprint omit actor/authority/tenant, so an actor lacking `:do` gets the sealed record.
- `ash_ex4pm/mix.exs:75` `files:` glob includes untracked `docs/jira/`; `hex.publish` ships
  internal tickets (`_LANES.md` Seam 1 says Lane 1 would prune it; the diff does not).

MED: version drift (ash_ex4pm pins `ex4pm == 26.10.17`, ex4pm is `26.11.10`; CHANGELOG claims
sync); `test/ash_ex4pm/evidence_court.exs` never runs under `mix test` (not `*_test.exs`);
stale `== 26.10.1` pin and version headers in README and 5 diataxis docs; NIF identity
admission skipped when no expected digest (`ex4pm/engine/adapters.ex:184-185`, degrades to
`:partial_alive`, downstream enforcement UNVERIFIED); atom minting from input
(`standing_coded.ex:59-62` fix in `priv/ggen/templates/standing_coded.ex.eex`,
`soundness_prover.ex:55`, `cognition/prolog.ex:163`); unguarded `apply` on `task.intent`
(`runtime/intent.ex:15-19`; local executor not BRCE-wrapped, origin UNVERIFIED).

LOW: outcome-write failure mislabelled `:blocked` (`receipted_action.ex:292-313`); idempotency
claim can stay `:in_flight` forever, no TTL (`:122-130`, `:271`); replay mismatch returned as
success (`:222-234`); `brce_gate.ex:85-95` no fallback clause; tautological
`upgrade_contract_test.exs`, `evidence_pack_test.exs`; fixed sleeps in
`call_log_bridge_test.exs:31,97` (silent give-up); `cli.ex:134` `to_existing_atom` raises.

Reusable for ash_surface: capability registry projected/alive/authorized split
(`capabilities.ex:224-279`); admission-from-evidence projection (`capability_projection.ex:69`);
Spark DSL + verifier + persist transformer template (`dsl.ex:158-299`, `verifiers/verify.ex`,
`transformers/persist.ex`); public-attributes-only introspection floor (`notifier.ex:~450-465`);
compiled-domain introspection wrapper (`info.ex:10-37`).

## R3 ash_dspy + ash_autofde (CONFIRMED by reader unless marked; nothing executed)

ash_dspy:
- HIGH court metrics/compiler can never pass a real impl: `court/runner.ex:27-37` returns raw
  `apply/3` result, not `{:ok,_}`; `metrics/provenance.ex:20-21` and `llm_residue.ex:20-28`
  raise on bare-atom `class/0`; `accuracy.ex:41-47` no clause for `{:refused,_}`;
  `court.ex:139-145` rescues into `{:refused,...}` so `Compiler.compile/3` refuses everything.
- HIGH ~3,000 lines of seed runtime untested: only `test/ash_dspy_dsl_test.exs` exists;
  `test/support/*.ex` not in `elixirc_paths` (`mix.exs:10-20`) and never required.
- MED untracked `HANDWRITTEN.md` referenced by README:71,75 and `ci.yml:52`; `:metric` option
  dropped (`compiler.ex:238-239` vs `court.ex:95-96,114`); DSL requirement/metric/minimize
  decorative, court gates at hard-coded 1.0 (`court.ex:34`); `Verify` no-op (`verify.ex:27-31`);
  Turtle injection via unescaped IRIs (`sa2a/agent_card.ex:168-169,187-188`); corpus never
  filtered by signature (`compiler.ex:198-236`); README evidence-trio claim false; `Route.standing`
  `:compiled` not in type (`route.ex:24`); `Receipt.for_route/1` raises without opts
  (`receipt.ex:92-98,129`); CI tripwire vacuous (`ci.yml:57,80`).
- LOW telemetry before apply validation; OCEL attributes can overwrite `ocel:*` keys
  (`ocel.ex:111-118`); `Court.digest` uses `term_to_binary` (`court.ex:80`); stale `priv/` cites;
  undeclared `:telemetry`/`:crypto` deps (`mix.exs:21-33`).

ash_autofde:
- HIGH `priv/` mode `drw-------`: tracked wasm unreadable, silent fallback to sibling path
  (`wasm_cmca.ex:122-123`); app fails to boot without Python bridge, hard-coded
  `/Users/sac/autofde-lab` path (`application.ex:8-10`, `port_bridge.ex:9-10,64-66`);
  governance fail-open: allocator hard-codes `"standing" => "ADMITTED"`
  (`cascade_allocator.ex:~120`), defaults 1.0/10.0/1.0, `ActuationReceipt` accepts any
  `receipt_hash` (`actuation_receipt.ex:20-28,85-87`).
- MED engine fallback to Python on any in-VM error (`cmca_cascade_plan.ex:36-39`); SSRF +
  premature side effect `Req.post` to caller URL inside a `change` (`actuation_receipt.ex:31-58`);
  `PortBridge` timeout/late-reply confusion and crashes (`port_bridge.ex:84-96`); `to_float`
  raises (`cascade_allocator.ex:~148`); tests cannot tell which engine ran, ping test needs live
  Python, suite skips on sibling artifact, `ash_autofde_test.exs` is a `hello/0` stub.
- LOW guest-memory leak on `cmca_rank_json` failure (`wasm_cmca.ex:175-195`); `:infinity`
  timeout accepted; stale resolution-order doc.

Reusable for ash_surface: `AshDspy.Compiler.Canonical.json/1` + `evidence_digest/2`
(`canonical.ex:33,47`, key-sorted at any size); deep fail-safe OCEL redaction (`ocel.ex:152-163`,
fix `:111-118` first); Court gating with `Metric.resolve/1` failing closed (`court.ex:148-167`);
atom-free JSONL traces import/export (`traces.ex:93,126,278-316`); SA2A AgentCard anti-grant
struct (`sa2a/agent_card.ex:102-106,140-190`, escape IRIs first); in-VM wasm JSON ABI host
(`wasm_cmca.ex:148`).

## R5 ash_expo + zoela_phx (CONFIRMED by reader unless marked; nothing executed)

HIGH:
- `ash_expo/lib/ash_expo/codegen.ex:274-300` `assertAdmitted` refuses `online_only` only when
  `options.getNetworkOnline` is supplied; README example omits it, so offline admission fails
  open (`README.md:114-118,215`).
- `codegen.ex:248-271` absolute URLs pass through `resolveInput` and `authenticatedFetch`
  attaches the bearer token with no origin check.
- `zoela_phx/lib/godslaw/coordination/receipt.ex:47-70` receipts are unkeyed checksums
  (forgeable); keyed API (`receipt_digest.ex:68-82`) used only in script/ and tests.
- Most Ash mutation policies are `authorize_if always()` (opportunity, evidence, listing, plan,
  agent task, relationship); `Capability` has no authorizer; only `Person.:mark_contactable`
  is gated.

MED: `CommandBus.dispatch` does not check `:record` belongs to `resource`, destroy ignores
params yet digest commits them (`command_bus.ex:75-107`); full receipt (result, actor) emitted
on telemetry (`:89`); absolute-microsecond bounds in `codegen_bench_bound_test.exs:20-72`;
generated TS verified only by substring matches (`ash_expo_test.exs:140-166`), no runtime
test; untracked `ash_expo/mix.lock` (CI keys cache on it) and `zoela_phx/script/
receipt_digest_tripwire.exs` cited by tracked code; `ggen.toml` `templates` dir missing.

LOW: stale jira docs; vacuous assertions in `receipt_digest_check.exs:56,100`; redundant
authorizer declaration; in-memory ETS resources vs "persists" docs; shared-ETS async tests.

Reusable for ash_surface (`projector/expo.ex` has no offline/token/channel admission, and
`castle_capability_intake.ex:15-21` already records ash_expo as a `:wrap` donor): offline-class
admission (`codegen.ex:274-300`, fix fail-open first), projection verifier
(`resource/verifiers/validate_projection.ex:6-110`), compile-env trace transformer
(`track_channel_config.ex:15-40`), deterministic write/check codegen (`codegen.ex:23-70`;
`expo.ex:57-63` writes unconditionally), SecureStore token store and socket helpers
(`codegen.ex:180,367`, fix origin leak first).

## R8 ash_r2rml + ggen_igniter (CONFIRMED by reader unless marked; nothing executed)

HIGH:
- `ash_r2rml/test/unit/ggen_runtime_ancestry_test.exs:123` pin-equals-HEAD test is vacuous:
  both pin sites are in `@staleness_allowlist` (`:30-41`), no expiry, `@today` hard-coded
  (`:43`); edit is uncommitted.
- Raw `postgresType` interpolated unquoted into DDL: `ingestion.ex:346` ->
  `semantic_renderers.ex:460,498-499`; `quote_ident` covers identifiers only. Non-ontology path
  at `admission.ex:120-135` not traced (UNVERIFIED).

MED: atom minting from ontology input (`ingestion.ex:804` `Module.concat` on `r2ml:ashType`;
`semantic_renderers.ex:123,221,277-278,304-310,373`); silent fail-open `storageStrategy` clause
`other -> other` (`ingestion.ex:808-817`, downstream behavior UNVERIFIED); atom minting from
event/receipt text (`telemetry/ocel_v2.ex:234,491`, `receipt_validator.ex:62`); ggen_igniter
atom minting from frontmatter/SPARQL vars/descriptor keys/CLI (`frontmatter.ex:357`,
`schema_dispatch.ex:460`, `reconcile.ex:307,313`, `reconcile_reactor.ex:1414`,
`semantic_jira/descriptor.ex:110`); `Code.eval_string` over any `*.livemd` as a verification
witness (`integrity.ex:1325`, `mix/tasks/ash_r2rml.test_livebooks.ex:90`); lock TOCTOU in
`pack_lock.ex:400-402,419`, `lock.ex:125-127`.

LOW: `Process.sleep` in `concurrency_test.exs:20-46` and
`dfcm_semantic_execution_integrity_test.exs:279`; git-ignored `ggen_igniter/doc/` copies can
drift.

Reusable for ash_surface: fail-closed SHACL property-term allowlist (`ingestion.ex:263-285`, not
the `:808-817` leak); `safe_atom` bounded admission (`ingestion.ex:821-831`); encrypted/private
attribute projection filter (`semantic_extensions.ex:41-42`); enum-module projection
(`semantic_extensions.ex:77,436`); pack pin/digest with symlink-escape refusal
(`ggen_igniter/pack_lock.ex:85-96,180-215`).

## R6 ash_graphlaw (AG) + ash_kudzu (AK) (CONFIRMED by reader unless marked; nothing executed)

HIGH:
- AK `sa2a_candidate.ex:10,14,15,64,67` aliases `AshKudzu.CapabilityContract` and
  `BindingCandidate`, no `defmodule` for either in lib/test/priv (compile failure inferred, not
  built); README/CLAUDE.md advertise `from_contract/2`, `attach_evidence/2`; no test.
- AK `shacl_admission.ex:47,49,144,148` bypass: a `#` comment line directly before a statement
  drops the chunk; `a  owl:Thing, owl:Class` slips the regexes. Only gate on extract_openapi.
- AK Turtle injection from OpenAPI names (`ontology_projector.ex:57-167` unescaped).
- AG signed-lease authority unproven: signature never checked in Elixir (`authority.ex:53,
  111-119`); every forged-lease test skipped with stale reason (engine pin is v26.11.10).
  Engine-side behavior UNVERIFIED.

MED: `Change.Admit` `law.data/2` unrescued (`admit.ex:284-288`) and result unvalidated;
`Admissible` falls back to default projection on junk (`admissible.ex:~245`); `check_op`
fail-open when no capabilities/lease (`authority.ex:207,236-237`); `blake3/1` shells to
undeclared `b3sum` (`canonical_json.ex:36-52`); wasm tests silently excluded, scripted
`admit_all` fake engine (`test_helper.exs:44-51`, `scripted_engine_helper.exs:1-20`);
`sa2a_evidence_admission.ex:85-100` self-consistency only; AK tests re-implement the digest
and committed vectors/SHACL shape never loaded; `ShaclAdmission` string-match false pass/fail;
atom minting + crashes on OpenAPI input (`openapi_extractor.ex:213,249,253-261`).

LOW: engine-load unpinned path (not reachable); `Coerce` enum/nullable unenforced; default
projection leaks via `inspect` (`projection/default.ex`); brittle refusal-message remap
(`admit.ex:243`); undeclared `Jason`; stale README counts and mix.exs comment.

Reusable for ash_surface: Ash resource reflection to map (`ash_kudzu/introspector.ex:20-89`);
OpenAPI<->Ash type table (`openapi_extractor.ex:132-342`, run in reverse); registry field-spec
coercion with structured errors (`ash_graphlaw/capability/coerce.ex:36-188`, enum/nullable
gap); canonical JSON + drift court (`canonical_json.ex:31-110`, `parity.ex:521-540`, avoid
b3sum); closed refusal vocabulary + declaration verifier (`contract.ex:130-228`, `refusal.ex`).

## R9 beam4pm + pm4exunit (CONFIRMED by reader unless marked; nothing executed)

HIGH:
- Tracked `beam4pm/lib/beam4pm_powl_model.ex:379` calls `BeamPM.Digest.hash/1`, defined only in
  untracked `lib/beam4pm_digest.ex`; also untracked `beam4pm_repop.ex`,
  `beam4pm_repop_ocel_verifier.ex`, `priv/repop/{MANIFEST.json,repop_kernel_wasm.wasm}`,
  `test/fixtures/repop_ocel/*` and four test files: clean checkout does not compile.
- `test/beam4pm_engine_dispatch_gate_test.exs` (~236-255) named skip became `if File.exists?`
  with zero assertions: silent green when engine sources are absent; `crate:graphlaw:src/abi.rs`
  can never exist.
- `pm4exunit/lib/pm4exunit/temporal.ex:92-99` missing/bad timestamps fall back to
  `DateTime.utc_now()`, so `assert_sla` passes and is nondeterministic.

MED: SLA check takes first occurrence of each activity, `to` before `from` gives negative diff
(`temporal.ex:30-37`); `RepopOcelVerifier` ignores `:canonical_form`
(`beam4pm_repop_ocel_verifier.ex:155-156,330`); verifier reads a test fixture in production and
can raise (`:509-529`); `Repop` resolves wasm from cwd, pin checked only at compile time
(`beam4pm_repop.ex:129-170`); non-reproducible `ash_a2a` path-vs-git dep with stale lock
(`mix.exs:132-151`); integrity chain omits most attributes and objects, fnv1a32, no
authenticity (`:330-336`).

LOW: dead code and stale comment in `conformance.ex`; empty-range `lcs_length`, cubic DFS;
DFS budget overflow reported as fitness 0 without diagnostic; undocumented `min_fitness`
semantics; TAP/XML reporter injection (`reporter.ex:~25-35`); atom minting in generated
codec (`beam4pm_codec.ex:14785`, reachability UNVERIFIED); `MatchError` on malformed receipt
(`beam4pm_process_governor.ex:776`); stale OCPQ claim in pm4exunit README; dirty
`native/ferroplan` submodule; card fixture compared to the live router it was generated from.

Reusable for ash_surface: fail-closed per-item validator with error paths
(`beam4pm_ocel_log_ingest.ex:143-247`); spec-table codec (`beam4pm_codec.ex:14765-14786`, swap
`to_atom` for an enum allowlist); injectable digest seam (`beam4pm_digest.ex:30-46`);
closed-vocabulary admission with typed refusals (`repop_ocel_verifier.ex:136-141,439-505`);
static AST mock scanner (`chicago/collaborators/mock_scan.ex:65,104`).

## R12 xaas (sampled breadth-first; ~1150 lib files mostly unread; nothing executed)

HIGH (CONFIRMED by reader unless marked):
- Chat service on :3021 is unauthenticated: `xaas_web/chat_router.ex:14-30` pipes only
  `:cors`, `:api`; identity is client header `x-user-id` (`chat_controller.ex:352`), nil-UUID
  fallback (`:17,259`), invalid sender id swapped for random UUID (`:261`); `config/dev.exs:86`
  binds all interfaces; `application.ex:59` starts it unconditionally; Ash calls carry no actor,
  resource policies UNVERIFIED (grep of `communications/*.ex` finds none); prod exposure
  UNVERIFIED.
- `pusher_auth` returns an unkeyed sha256 and a `"xaas_key:authorized"` fallback for any caller
  (`chat_controller.ex:312-320`).
- Tracked code references deleted modules: `router.ex:108` `NextRead.ReaderLive` (file staged
  for deletion); `test/xaas/zoe/candidate_admission_test.exs:5,25,62,176` calls deleted
  `Xaas.Zoe.PrivateMeetingInference`.

MED: tracked `router.ex`/`application.ex`/config need untracked files (`serv_engine_controller.ex`,
`chat_endpoint.ex`, `chat_router.ex`, `chat_controller.ex`, `serv_engine/communications*`,
`accounts/user_preference.ex`, `w9_sms_*`, `tenancy/client_team_assignment.ex`, migrations
20261109250000-20261109270000; ~88 changed paths, 20+ deleted tests); `mix.exs:133`
`{:ash_surface, path: "../ash_surface"}` CI/Docker resolution UNVERIFIED; tests that cannot
fail (`joe_socket_saboteur_court_test.exs:15-45` passes on `:econnrefused`, unannotated
sleeps; bare `assert true` at `eu_ai_act/title_ii_test.exs:230`, `xaas_verify_and_commit_test.exs:243`,
`ex4pm_staleness_test.exs:82`); unannotated `Process.sleep` in lib (`fabric_controller.ex:122`,
`sa2a/court.ex:290`, `ultracode/{dispatch:419,autonomic:744,1164,semantic_crown:421,858,
verifier:938,process_group:50}`, `actuation/quiescent_stop.ex:161`); atom minting
(`chicago/invariant_court.ex:377`, `semantics/counterfactual.ex:195`, `runtime/fond/capability.ex:5`,
`fabric.ex:138,150` UNVERIFIED); RPC payload `tenant` trusted on shared-token tier
(`ash_typescript_rpc_controller.ex:70-102`, `Map.put` on possible struct UNVERIFIED);
chat `block_user` returns success when `Ash.create` fails (`chat_controller.ex:332-336`).

LOW: `VERSION` 26.10.8 vs docs 26.11.9; inert `rpc_platform_view` marker
(`ash_typescript_rpc_controller.ex:21-24`); committed dev `secret_key_base`, `check_origin:
false` (`config/dev.exs:88-90`); unread rescue sites.

Reusable for ash_surface: `mix/tasks/xaas.ash_surface.ex:50-59` pipeline
(`from_manifest` -> `verify_surface_digest` -> `Compiler.compile` -> projectors);
`ash_typescript_manifest.ex:25-55,67` domain-tolerant manifest; `config/config.exs:208-221`
zod config (`generate_zod_schemas`, `assets/js/ash_zod.ts`, 719 lines, ~115 schemas);
`rpc/interpolating_error_handler.ex:37-60`; `plugs/validate_rpc_fields_spec.ex:49-98`
fail-closed typed-400 guard. xaas is the only runtime backend for servengine-frontend and
consumes ash_surface by path dependency: xaas parity feedback loop is the real consumer test.

## R7 ash_pplan (PP) + ash_planning_center (PC) (CONFIRMED by reader unless marked)

HIGH: PP `standing.ex:330-335,188-215` `standing/1` returns `:alive` on vacuous evidence
(empty events/consequence; only literal `false` fails; `receipt/2` alone refuses empty events
at `:458`); PP `standing.ex:265-269` provider-identity check fails open on nil provider.
MED: gate-skip passes FOND (`standing.ex:300`); WAL replay truncates silently on corrupt length
header, non-atomic `truncate_tail` (`reactor/durable/store/wal.ex:678,706`); atom minting in
`capability_pack.ex:83,90` and `workflow/project/hddl.ex:322,339`; silent engine fallback in
`htn.ex:598-650`; PC OpenAPI codegen interpolates unvalidated strings into Elixir source and
output path (`priv/ggen/.../resource.ex.eex:7-9`, `open_api.ex:37-68`); PC JSON:API decode does no
type casting (`json_api.ex:64`); PC silent 25-row truncation, filter/limit behavior untested
(`people/person.ex:22`); untracked `ash_planning_center/mix.lock`, CI unpinned.
LOW: lossy OpenAPI type mapping (`open_api.ex:93,137-142`); sensitive fields `public?: true`
(`generated/people/person.ex`); auth-shape echo (`client.ex:139`); stale AGENTS.md symlink claim,
HANDWRITTEN totals; dead 8-minute poll and self-comparing `op_of/1` in provider court tests;
tautological `Chain.verify` (`standing.ex:458`); `Standing.Cached` staleness (UNVERIFIED).
Reusable for ash_surface: `json_api.ex:43-71` name-based projection keeping unknown fields;
`open_api.ex:90-142` type table (inverse direction); `workflow/subject.ex:13,93-109`
`verify_projection/3` (projection covers exactly the bound ids); `execution_receipt.ex:260-275`
`escape_literal/1`; `chicago/collaborators/mock_scan.ex:64-104` AST mock scanner.

## R10 ex_noun_verb_cli + gno (CONFIRMED by reader unless marked)

ex_noun_verb_cli HIGH: handler results not sanitized, `Jason.encode!` crashes the escript
(`json_output.ex:20-22`, `escript.ex:98,104`); `Registry.Reflection` never scans the consumer app
(`reflection.ex:33`). MED: `--completions` without shell crashes (`escript.ex:68`,
`shell.ex:31-32`); optional options parsed then dropped (`dispatcher.ex:104-111`); positionals
unvalidated; `Jason.decode!` on stdin (`chaining.ex:99`); keyword-list `Verb.info` breaks dispatcher;
argument injection via `@{N.path}` chaining (`chaining.ex:72-78`). LOW: duplicate noun/verb
undetected, stale version docs, unescaped completion scripts, `Application.put_env` leak in a test.
gno HIGH: `mix gno.setup --on-existing-dataset` always crashes (string vs atom,
`setup.ex:22,47-48`, `fuseki.ex:375-380`). MED: dataset created before already-setup check, no
cleanup (`service/setup.ex:78-87`); `to_existing_atom` on free log level aborts commits
(`logger.ex:153`); `mix gno.teardown` destructive with no confirmation (`teardown.ex`,
`fuseki.ex:392-405`); env-dependent `utils_test.exs:26-30`; stale `gno.app` namespaces in docs.
Reusable: `Introspect.manifest/2` (`introspect.ex:29-124`), many-projections-from-one-manifest
(`help.ex`, `completions.ex`), `JsonOutput` envelope, deterministic dependency order
(`capability_registry.ex:119-167`).

## R11 kanban + smalt (CONFIRMED by reader; items 3,4,10 also executed read-only)

HIGH:
- kanban `lib/kanban/application.ex:37` supervises nonexistent `Kanban.Presence`: app and
  `mix test` fail at boot.
- kanban `prom_ex/cpu_plugin.ex:37-38` calls unaliased `AwsRepo` (undefined); poller crashes
  (PromEx alias injection not verified).
- smalt `scripts/sleep_gate.py:131` `SLEEP_RE` `\b(?:Process|:timer)\.sleep\b` never matches
  `:timer.sleep` (executed: False); 5 unannotated `:timer.sleep` in test/; the court has no timer
  case.
- smalt `scripts/sdk_coverage.py:278-295` `load_kd` reads stale six-column indices vs the 7-column
  register; statuses parse as `add`/`OPEN`/`a`/`probe`; CLOSED branches dead; `scripts/kd_flip.py:
  97-142` already fixed this (parsers disagree); row regex drops KD-KIN-*, KD-SQ-*, KD-SIGV4-*
  (20 of 28 rows load in v26.11.6).
- smalt `justfile.d/18-shim-court.just:40-49` aggregate exits 0 when courts SKIP or crash; five
  courts permanently skip "test file removed"; others name nonexistent subjects.

MED: `sdk_coverage.py` ignores failed grounding for surface cells (`:~705`), trivial `defmodule`
groundings (`:73-77`); `parse_receipt` can score all-pass with zero PASS lines (`:245-262`); a
closed KD row can launder new FAIL tokens (`:~625`); non-strict mode drops malformed workflow
receipts (`:425-457`, `:390`); smalt sleep gate red on HEAD with 7 violations
(`verification/py/test_wf9_kafka.py` etc.), allowlist by bare function name, `strip_comment` cuts
at `#{}`; `shim_court/lib.sh` marker check does not prove the file changed (`:136`), trap only at
AFTER (`:81-92,146`), self-check bypassable (`:56-79`); `KinesisRoutes` any non-blank
Authorization admitted when unpinned, pinned mode ignores region and key id, non-constant-time
compare (`:168-278`); kanban CPU metric reports idle on failure (`cpu_plugin.ex:44-49`,
`aws_adapter.ex:~95-101`); smalt tautological `bk69r_probe_tmp_test.exs:35`, async test with
global `put_env`.
LOW: kanban compose secrets, `decrypt.sh` colon split, `deploy.sh` TOFU `ssh-keyscan`, unbounded
`wait_for_swarm_ready_tag.sh`; kanban tracked `deps/` deleted in working tree, stock README, no
AwsRepo/CpuPlugin tests; smalt atom creation from request-derived account
(`data_plane/azure_cache.ex:95`), IP strings (`cluster.ex:234`); `discover_windows` sorts names
lexicographically (`sdk_coverage.py:508-513`).

Reusable for ash_surface (Q1 gate and Q2 shim-court are direct descendants of smalt's
`sdk_coverage.py` and `shim_court/lib.sh`; apply these fixes to our ports): layout-robust register
parser (`kd_flip.py:82-142`); per-cell assertion grammar with anti-smearing rollup
(`sdk_coverage.py:390-422`, FAIL > BLOCKED > SKIP > PASS, make strict the default);
cell-discovery fence (`sdk_coverage.py:333-387`); shim-court harness (`lib.sh:100-175`; assert
shimmed hash differs, trap before shim, aggregate fails on skips); typed allowlist with
annotation adjacency (`sleep_gate.py:96-195`, per-file not per-function allowlist).

## See Also

`PARITY-WAVE3-QUEUE.md`
