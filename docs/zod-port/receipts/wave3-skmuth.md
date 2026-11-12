# Wave 3 SKMUTH: mutation skeptic over RAQ/RAS/RAU/RAX/RAY

Standing: PARTIAL

Scratch: /tmp/skmh (tar copy, deps/node_modules symlinked, build root inside scratch; hook did
not refuse). Harness /tmp/skmh/mut.py, in-place mutation of the scratch lib, sha256 baseline
== restore True for every applied mutation. Canonical repo untouched.

Baseline: `mix test` of 10 files (RAQ/RAS/RAU/RAX/RAY targets) rc=0, 143 tests, 0 failures.
This includes RAS files entry_points, custom_zod_overrides, fold_argument_constraints (both
copies): green against current lib. RAS residue check: mutation anchors (min_length_bound,
fold_defaults, zod table lines) matched exactly once as original text.

## Results (rc=2 killed, rc=0 SURVIVES)

| id | mutation | result |
|---|---|---|
| E-a,b,c,e,h,i | errors.ex NotFound short, InvalidPrimaryKey short, InvalidKeyset short, scrub last->first, drop :resource from vars, InvalidPage short | killed |
| E-d | AuthenticationFailed short "Authentication failed" -> "Auth failed" | SURVIVES |
| E-g | drop `:key` from vars Map.take | SURVIVES |
| C-a,c,h | config zod_import_path, zod_import_into_generated, zod_infer_types defaults | killed |
| C-b | always_regenerate default false->true | SURVIVES |
| C-d | parity typed_controller_mode default :full->:paths_only | SURVIVES |
| C-e | parity phoenix_import_path default | SURVIVES |
| C-f | not_found_error? default true->false | SURVIVES |
| C-g | parity run_endpoint default | SURVIVES |
| K-a,c | field_selector required-args check weakened; non-empty-args def | killed |
| K-b | `has_non_empty_args && !calc_accepts_args` -> false | SURVIVES (maybe shadowed) |
| K-d | has_required_arguments? any? -> all? | SURVIVES |
| K-e | `args != nil && load_fields != []` -> `load_fields != []` | SURVIVES |
| K-f | drop `!is_complex_return_type` guard | SURVIVES |
| K-g | `calc_accepts_args && args == nil` -> false | SURVIVES |
| Z-a,b,c,d | zod min_length max(), default min, trim? default, ci_string default kinds | killed |
| Z-e | "any" => z.unknown() | SURVIVES |
| Z-f | js_flags drops "s" | SURVIVES |
| Z-g | ci_string base table z.string() -> z.any() | SURVIVES |
| Z-h | fold check_value("match_flags") disabled | SURVIVES |
| S-a,b,c,e | type_facts field_names nil, resource? false, embedded module | killed |

E-f and S-d did not apply (anchor count != 1): UNVERIFIED. Equivalence of K-b, K-g not proven.

## Repair requests

1. error_redaction/error_protocol: pin AuthenticationFailed short message (errors.ex @table);
   `:key` var of a struct carrying :key (E-g).
2. manifest_generator_config_test: always_regenerate, not_found_error? defaults; parity table
   defaults typed_controller_mode, phoenix_import_path, run_endpoint (config.ex).
3. rau/ray calc tests (field_selector.ex): has_required_arguments? with one optional + one
   required arg (K-d); args with load fields (K-e); non-accepting non-complex calc with args
   (K-f); K-b and K-g need an input that reaches them or proof of shadowing.
4. ts/root + fold tests: "any" kind -> z.any(); js_flags "s"; ci_string base table
   expression; fold refusal of non-binary match_flags (fold.ex check_value).
