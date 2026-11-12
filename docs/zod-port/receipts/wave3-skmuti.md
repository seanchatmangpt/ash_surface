# wave3-skmuti

Standing: PARTIAL

Adversarial mutation skeptic over RAI, RAW, RBA, RBB, RBC, RBD repairs. Scratch tar copy
`/tmp/skmi` (deps/node_modules symlinked, build root `/tmp/skmi/_b`), canonical never written
(scratch lib byte-identical to canonical for all 13 mutated files, `cmp`). Court `court.py`:
per mutation sha256 baseline == restore True and mutated != baseline True, every row.
Baselines green: RBA+RBB+RBC 15/0; RAI 66/0. Mutation rc un-piped. 49 new mutations
(+8 re-runs on an extended namespace set). Wave severity: MEDIUM (survivors are test gaps; no
lib defect found).

## Probe of RAI lib edit (error_formatter.ex format_name/2 {m,f}/{m,f,args})

- I3 `{m,f,args}` clause returns plain name: SURVIVES. I4 `{m,f}` result upcased: SURVIVES.
  I1 `{m,f,[a]}` arg order swapped (FieldName.call_custom): SURVIVES. I2 `to_string(result)`
  dropped (non-binary result passes through): SURVIVES.
  The custom-clause tests pin only "does not raise" (mutation F), not the formatted value.
- Not probed (no bad-formatter test exists to attack): non-binary/nil/raising `{m,f}`;
  call_custom validates and `to_string`s, so a nil result becomes "" (I2 shows no test observes it).
- Single-emission: no test asserts it. I10 (fmt_key binary clause dropped): SURVIVES.

## Results (K=killed, S=survived)

RAI: I1 S, I2 S, I3 S, I4 S, I5 (clean `?` -> `_`) S, I6 (gt->gte) S, I7 (max_length->min) K,
I8 (leading underscores dropped) S, I9 (pascal ErrorFormatter) K, I10 S.
RAW: W1 K, W2 (short_message text) S, W3 K, W4 (value_formatter ForbiddenField leak) S, W5 K,
W6 K, W7 K, W8 (unknown-keys message) S, W9 (keys join) S, W10 (fields: keys) S.
RBA: A1 (:count) S, A2 (InvalidToken text) S, A3 source_path_prefix default S,
A4 show_raised_errors default S, A5 require_tenant_parameters parity default S, A6 K.
RBB: B1 K, B2 K, B3 (`!arg.allow_nil?` flipped) S, B4 (path -> [] branch 1) S,
B5 (path -> [] branch 4) S, B6 K.
RBC: C1 K, C2 K, C5 K; C3 (`/` unescaped) S, C4 (match_flags accepts atoms) S,
C6 (js_flags non-binary -> "i") S.
RBD (own tests ray+raz+typed_query_fields): D2 K; D1 (precedence swapped), D3 (uniq dropped),
D4 (nil not rejected), D5, D6, D7 (reverse sort), D8, D9 S. Extended set
(namespace_resolution, namespace_manifest_surface, decorator_surface, projector_hardening,
ray, raz; 99 tests): D1,D3,D4,D5,D6,D7 killed; D8 (manifest/dsl.ex namespace put effective),
D9 (`b["namespace"]` -> nil, action_manifest.ex:96) SURVIVE.

## RBD consumer probe

`namespace_refusals`/`verify_namespace`/`invalid_namespace` grep over lib, parity, conformance,
ontology.ttl, scripts: zero lib consumers (only js.ex `invalid_namespace_prefix/_names`, a
different option). Namespace flows through ActionManifest.namespace/1,
Info.effective_namespace/1, manifest/dsl.ex:26. No reliance on the removed refusal found.
Precedence/uniq/sort/nil-reject are pinned only by the namespace_resolution/manifest tests,
not by RBD's own files.

## Repair requests

- error_formatter.ex format_name/2 {m,f}/{m,f,args}: add a test asserting exact formatted value
  and arg order via a real custom formatter module (kills I1-I4); also non-binary result.
- field_name.ex clean/1 `?` strip (I5) and leading-underscore camelize (I8); zod_type.ex
  `greater_than` -> `gt` (I6): RAI tests do not pin them.
- error_builder.ex short_message "Pagination not supported" (W2), unknown-keys message (W8),
  keys join (W9), `fields: keys` (W10); value_formatter.ex drop_unavailable ForbiddenField (W4).
- errors.ex `:count` in Map.take (A1), InvalidToken short message (A2); config.ex defaults
  source_path_prefix (A3), show_raised_errors (A4), require_tenant_parameters (A5).
- field_selector.ex `!arg.allow_nil?` (B3) and throw path of invalid_calculation_args (B4, B5).
- zod_type.ex escape_slashes `/` (C3), js_flags non-binary default (C6); fold.ex
  check_value("match_flags") atom acceptance (C4).
- manifest/dsl.ex:26 namespace (D8) and action_manifest.ex:96 `b["namespace"]` (D9).

Cleanup: `/tmp/skmi`, `/tmp/skmi_c` deleted after receipt.
