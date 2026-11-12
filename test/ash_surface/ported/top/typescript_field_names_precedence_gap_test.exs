defmodule AshSurface.Ported.Top.TypescriptFieldNamesPrecedenceGapTest do
  @moduledoc """
  Loud skips for ash_typescript `typescript_field_names_precedence_test.exs` behaviors ash_surface
  does not have. Not listed on a ledger row (the row's runnable half is the sibling test file).
  """
  use ExUnit.Case, async: true

  @tag skip:
         "GAP field_names_precedence valibot: ash_surface emits Zod only (no valibot schema generation)"
  test "valibot validation schemas use mappings as-is" do
    flunk("capability missing: valibot projection")
  end

  @tag skip:
         "GAP field_names_precedence typed controller: no typed controller result type projection for mapped typed-map results (UpdateProviderResult)"
  test "typed controller result types use mappings as-is" do
    flunk("capability missing: typed controller result projection")
  end

  @tag skip:
         "GAP field_names_precedence rpc run: no Rpc.run_action surface; create_input_parsing / get_task_stats end-to-end formatter-keyed envelopes (data key, nested input keys) are exercised only at FieldName/FieldSelection level"
  test "RPC end to end parses and returns formatter-keyed envelopes" do
    flunk("capability missing: Rpc.run_action field-formatted envelope")
  end
end
