defmodule AshSurface.Ported.Rpc.C.OptionalTenantForAllActionsGapTest do
  use ExUnit.Case, async: true

  @tag skip:
         "T10 gap: optional_tenant_for_all_actions (TS-SYNTAX-ONLY: asserts the generated TypeScript channel function text; ash_surface generates no .ts and no channel client function; the conditional tenant behavior is covered by optional_tenant_ir_surface_test.exs 005-006; README.md:29; capability config.key.require_tenant_parameters)"
  test "007 channel function for read action includes conditional tenant in payload" do
    :ok
  end
end
