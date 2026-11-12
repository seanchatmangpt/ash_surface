# Wave 3 RBG: Error-Formatter Custom and Namespace Repairs

Standing: PASS

Lane RBG. Tests only; no lib edit. Non-binary result: pinned `to_string/1` coercion
(FieldName.call_custom; reference field_formatter.ex:321-325 returns raw, wire names are
strings: disclosed divergence). Arg order name-first (reference `[field_name | extra_args]`).

## Tests (new, test/ash_surface/ported/rpc/rbg/)

- error_formatter_custom_test.exs: real `Fmt` module; 6 tests.
- namespace_manifest_test.exs: real resource, Dsl + ActionManifest routes; 4 tests.
- `mix test .../rbg` rc=0, 10 tests, 0 failures.

## Shim-court (in-memory recompile, /tmp/rbg; sha256 before == after on all 4 lib files)

| id | mutation | result |
|---|---|---|
| I1 | {m,f,[a]} drops arg | RED 1 |
| I2 | upcase {m,f} result | RED 4 |
| I3 | swapped arg order | RED 1 |
| I4 | no to_string | RED 1 |
| E1 | error_formatter {m,f,args} clause returns plain name | RED 3 |
| E2 | error_formatter {m,f} result upcased | RED 4 |
| D8 | dsl.ex drop namespace put | RED 2 |
| D9 | action_manifest.ex:96 `b["namespace"]` -> nil | RED 1 |

No equivalents.

## Verification

`mix ash_surface.parity.tests --summary` rc=0: files=264 unaccounted=0 broken=0 (count
unchanged: new files not inventoried; UNVERIFIED whether inventory regen is required).
