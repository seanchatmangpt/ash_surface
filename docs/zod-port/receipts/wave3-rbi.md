# Wave 3 RBI: Custom Formatter Non-Binary Result (KD-12)

Standing: PASS

Finding: RBG pinned `to_string/1` coercion; reference passes raw. Witness (in-memory bypass of
coercion, /tmp/rbi/probe.exs, rc 0): raw nil -> key `{"nil":1}`; 42 -> `{"42":1}`; atom
`:same` for x and string `"same"` for y -> `Mapping.verify` returned `:ok` and the reverse
map held `:same` and `"same"` separately (silent collision/split). Coercion is also unsafe
(`to_string(nil)` = empty key). Typed refusal beats both.

## Change (disclosed)

- lib/ash_surface/field_name.ex `call_custom/2`: non-binary or empty result raises
  `ArgumentError` `invalid_custom_formatter_result` naming formatter, field, value.
- test/ash_surface/ported/rpc/rbg/error_formatter_custom_test.exs: coercion test replaced
  by refusal test (Fmt gained nil/empty fns); moduledoc updated.
- test/ash_surface/divergence_close/custom_formatter_result_test.exs: KD-12 court, 3 tests.
- docs/KNOWN_DIVERGENCES.md: KD-12 row. parity/court_map.json untouched (no
  `config.key.output_field_formatter` entry exists to repoint).

## Verification

- rbg + court: 13 tests, 0 failures.
- Shim-court (scratch-compiled coercion restored, field_name.ex sha256 identical after):
  9 tests, 4 failures (RED); real tree green.
- Full `mix test`: only pre-existing ash_r2rml/ash_a2a spark-court reds (TESTING.md).
- `mix ash_surface.parity.tests --summary` rc=0 unaccounted=0 broken=0;
  `--check-inventory` rc=0 (264 files identical). Inventory derives from the reference repo,
  not ash_surface tests: rpc/rba..rbh dirs need no rows.
