defmodule AshSurface.Ported.Rpc.E.TypedQueryFieldMappingCrossDomainGapTest do
  @moduledoc """
  Loud-skip counterpart of ash_typescript `rpc/typed_query_field_mapping_cross_domain_test.exs` (5 tests). Every reference
  test has a tagged skip carrying the row skip_tag; no silent skips.
  """
  use ExUnit.Case, async: true

  @tag skip:
         "T12 gap: typed_query_field_mapping_cross_domain (TypeScript typed-query const text across domains plus Rpc.run_action list_users; README: no generated .ts; capabilities dsl.rpc.entity.typed_query, runtime.module.Rpc.Pipeline)"
  test "004 resource schema is generated only once even with multiple domains" do
    :ok
  end
end
