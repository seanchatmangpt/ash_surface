defmodule AshSurface.Ported.Rpc.C.RpcCompositePrimaryKeyGapTest do
  use ExUnit.Case, async: true

  @tag skip:
         "T10 gap: rpc_composite_primary_key (TS-SYNTAX-ONLY: asserts the generated TypeScript channel function config type text; ash_surface generates no .ts and no channel client function; README.md:29; capability codegen.module.Rpc.Codegen)"
  test "005 generates object type for composite primary key in channel function" do
    :ok
  end
end
