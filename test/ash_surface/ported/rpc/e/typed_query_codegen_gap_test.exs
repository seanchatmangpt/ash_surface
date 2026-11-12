defmodule AshSurface.Ported.Rpc.E.TypedQueryCodegenGapTest do
  @moduledoc """
  Loud-skip counterpart of ash_typescript `rpc/typed_query_codegen_test.exs` (6 tests). Every reference
  test has a tagged skip carrying the row skip_tag; no silent skips.
  """
  use ExUnit.Case, async: true

  @tag skip:
         "T12 gap: typed_query_codegen (TypeScript typed-query const/satisfies/InferResult text; README: no generated .ts; capabilities dsl.rpc.entity.typed_query.option.ts_fields_const_name, dsl.rpc.entity.typed_query.option.ts_result_type_name)"
  test "005 typed queries section header is present" do
    :ok
  end

  @tag skip:
         "T12 gap: typed_query_codegen (TypeScript typed-query const/satisfies/InferResult text; README: no generated .ts; capabilities dsl.rpc.entity.typed_query.option.ts_fields_const_name, dsl.rpc.entity.typed_query.option.ts_result_type_name)"
  test "006 all typed query constants use satisfies for type safety" do
    :ok
  end
end
