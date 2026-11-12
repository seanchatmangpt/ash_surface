# Wave 3 RBQ: E6 dead branch deleted

Standing: PASS

- Proof: `mapped_argument_name/3` returns `name` (guarded `is_binary`) or `input_name` (the
  `else _` arm); only caller is `format_input_name/5`. `true ->` needs non-binary and
  != input_name: impossible.
- Probe (in memory): 0 violations over 7 names x 2 resources x 2 actions x 4 formatters
  (incl. `{String, :upcase}`); format_input_name ran on all names.
- Lib edit (disclosed): `support.ex` `cond` -> `if is_binary(mapped)`, else formats `input_name`.
- Gates: `mix test test/ash_surface/ported/rpc test/ash_surface/adversarial` rc=0 (2249 tests,
  0 failures, 213 skipped); `mix ash_surface.parity.tests` rc=0 (unaccounted=0, broken=0).
- Residual reference grep (`mapped == input_name`, `format_field_name(mapped`): none.
