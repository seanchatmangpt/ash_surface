# wave3-ras

Standing: PASS

Lane RAS repairs skeptic survivors Z1-Z5, Z7 and F1, F3 (receipt wave3-skmutf.md).

## Tests added
- entry_points_test.exs: allow_empty? false with min_length 0 (node+zod rejects ""; Z1);
  match_flags "i" emitted and honoured under zod (Z2).
- custom_zod_overrides_test.exs: builtin-kind override beats base table (Z3); term/file/function
  map to z.any() (Z4, Z5, Z7).
- fold_argument_constraints_test.exs: ci_string default fold (F1); top-level item_type
  forbidden-kind refusal (F3).

## Shim-court (live lib mutated in place under try/finally, build root _build-ras)
Harness /tmp/ras_mut.py. Baseline `mix test` of the 3 files: rc=0, 47 tests, 0 failures.
Each of Z1, Z2, Z3, Z4, Z5, Z7, F1, F3: rc=2, 1 failure (killed); sha256 restore equal for all;
restored run rc=0, 47 tests, 0 failures.

## Gate
`mix ash_surface.parity.tests`: rc=0.
