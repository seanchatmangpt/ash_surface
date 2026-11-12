# Wave 3 RAM: untyped-map key parity

Standing: PASS

Subject: does ash_surface camelize keys of an untyped map (Ash.Type.Map without fields)?

## Reference finding (~/ash_typescript, read from source)

- `lib/ash_typescript/rpc/value_formatter.ex` `kind when kind in [:struct, :map]` cond: the final
  `true -> value` branch (lines ~181-182) returns an untyped map verbatim. Direction-independent
  (input and output), formatter-independent (camel/snake/pascal), recursive nesting untouched,
  atom and string keys both kept.
- `lib/ash_typescript/rpc/result_processor.ex` `extract_typed_map_value/4`:
  `template == [] and fields == []` -> `normalize_primitive(value)`, keys kept.
- Input: `input_formatter.ex` formats only the action argument names; the value goes through
  the same ValueFormatter, so client keys inside an untyped map are preserved verbatim.
  Only custom types with map storage use `format_map_keys_only` (value_formatter.ex ~190).
- Reference suite could not be executed (deps absent in ~/ash_typescript: "dependency is
  not available"); finding is source-read. UNVERIFIED by run on the reference side.
- `diff` of value_formatter / result_processor / field_extractor between reference and
  ash_surface runtime_parity (alias-normalized): only alias lines differ.

## Verdict

ash_surface already matches the reference. No lib change. RAJ pin stands, now with citations.

## Edit

`test/ash_surface/ported/rpc/run_action/rpc_run_action_untyped_maps_surface_test.exs`: added
"untyped map keys are verbatim under camel/snake/pascal, both directions (reference parity)"
(real ValueFormatter input+output and real `Rpc.run` under `FieldName.with_formatter`; only the
wrapper field and envelope keys follow the formatter), with the citation comment.

## Commands

- surface test file alone: rc=0, 9 tests, 0 failures.
- Non-vacuity: scratch /tmp/ram (explicit-path tar incl README.md, node_modules/deps symlinked),
  mutation: untyped `true ->` branch camelizes map keys. Result: rc=2, 5 of 9 failed (RED).
  Restore sha256 == baseline 5fa2b68b75442fd617348cecb1be3fa1af5498419b39756b429e83444a142563.
- `mix test test/ash_surface/ported/rpc test/ash_surface/no_local_do_test.exs`: rc=2,
  2003 tests, 1 failure, 213 skipped. The failure is
  `ported/rpc/d/runtime_source_of_truth_ast_guard_test.exs:327` on
  `runtime_parity/requested_fields/field_selector.ex` (retired keys `:enable_filter?`,
  `:enable_sort?`), a file not owned by RAM (other lane in flight). BLOCKED on that lane.
  An earlier baseline run showed 2 failures in `ran/mapped_name_vs_computed_test.exs`, gone later.
- `mix ash_surface.parity.tests`: rc=0, unaccounted=0, broken=0.

Build root _build-ram deleted at finish.
