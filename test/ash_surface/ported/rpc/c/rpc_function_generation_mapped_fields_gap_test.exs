defmodule AshSurface.Ported.Rpc.C.RpcFunctionGenerationMappedFieldsGapTest do
  use ExUnit.Case, async: true

  @tag skip:
         "T10 gap: rpc_function_generation_mapped_fields (TS-SYNTAX-ONLY: asserts the generated TypeScript channel function signature text; ash_surface generates no .ts and no channel client function; mapped input names are covered by rpc_function_generation_mapped_fields_surface_test.exs; README.md:29; capability codegen.module.Rpc.Codegen.FunctionGenerators.FunctionCore)"
  test "013 channel function has correct type signature with mapped input" do
    :ok
  end

  @tag skip:
         "T10 gap: rpc_function_generation_mapped_fields (TS-SYNTAX-ONLY: asserts the generated TypeScript channel function signature text; ash_surface generates no .ts and no channel client function; mapped input names are covered by rpc_function_generation_mapped_fields_surface_test.exs; README.md:29; capability codegen.module.Rpc.Codegen.FunctionGenerators.FunctionCore)"
  test "019 channel functions use the same input types as regular RPC functions" do
    :ok
  end
end
