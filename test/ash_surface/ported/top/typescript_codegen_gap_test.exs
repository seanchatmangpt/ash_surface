defmodule AshSurface.Ported.Top.TypescriptCodegenGapTest do
  @moduledoc """
  Loud skips for ash_typescript `typescript_codegen_test.exs` behaviors ash_surface does not have.
  Not listed on a ledger row (the row's runnable half is `typescript_codegen_test.exs`).
  """
  use ExUnit.Case, async: true

  @tag skip:
         "GAP typescript_codegen untyped_map_type: the key is validated config only; no compiler path consumes it (Zod untyped maps follow zod_mapping_overrides kinds)"
  test "untyped_map_type reconfigures every untyped map type" do
    flunk("capability missing: untyped_map_type consumed by the compiler")
  end
end
