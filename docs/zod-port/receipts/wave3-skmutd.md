# wave3-skmutd

Standing: PARTIAL

Lane SK-mutD (read-only skeptic; scratch `/tmp/skmd`, own `MIX_BUILD_ROOT=/tmp/skmd/_b`, real
deps copy and node_modules symlink; lib sha256 baseline == after-restore, `cmp` identical).
Baseline (typed_controller+typed_channel+ts): 365 tests, 1 failure (codegen_test.exs:324,
tmp-dir symlink collision, flaky, not mutation-related). Raw: `/tmp/skmd/out/*.txt`, `resAB.txt`,
`resZD.txt`, `resZD2.txt`, harness `/tmp/skmd/mut.py`. Scratch left in place (rm may be denied).

## Results

| file | mutation | verdict |
|---|---|---|
| router_introspection_test | introspector path_params->[] / drop plug_opts name match / ambiguity check off / scope_prefix->helper | red |
| router_introspection_test | drop `plug == controller` match; sort_by->reverse (mount list and introspect_router); method downcase removed | SURVIVED (vacuous for these) |
| codegen_enforcement_test | verify off; zod map -> unknown/any | red |
| codegen_enforcement_test | `.strict()` removed | SURVIVED |
| typed_channel/channel_verify_test | s_chkind (`resolved_kind` -> "unknown", type_ref branch -> "type_ref") | red (3 and 1 failures) |
| typed_channel/channel_payload, runtime_gap | s_chkind | green (no coverage) |
| zod fail files | accept-anything, drop chain/regex/maxlen | red |
| zod pass files | tighten: optional off, +1/-1 bounds, string max(1), integer max(0), refine-false | red (z_tight_num: setup-invalid) |
| ts/should_fail typed_controller_results_fail | drop `.strict()` | green; tighten red |
| tsc negatives | UnifiedFieldSelection->any, Leaf->string, Fields->any[], args->any | red |
| tsc negatives | filter/sort/metadata -> any | SURVIVED |

## Repair requests

- `typed_controller/router_introspection_test.exs`: assert controller identity in match, mount
  ordering (path, method), method lowercase normalization, `introspect_router/1` ordering.
- `typed_controller/codegen_enforcement_test.exs`: add an extra-key rejection case (strict).
- `ts/should_fail/typed_controller_results_fail_test.exs`: add extra-key refusal.
- `typed_channel/channel_payload_test.exs`, `channel_runtime_gap_test.exs`: no `returns_kind`
  assertion.
- `ts/should_pass/inference_cases_test.exs`, `inference_fail_cases_test.exs`: add negatives
  for filter, sort-string and metadata types (all survive `any`).

## UNVERIFIED

Item 1 census of the 153 ported files not named by basename in skmuta/b/c: not run. Per-negative
(9 `@ts-expect-error`) kill not isolated; only file-level kill shown.
