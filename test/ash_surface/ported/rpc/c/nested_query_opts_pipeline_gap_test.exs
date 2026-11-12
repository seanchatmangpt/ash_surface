defmodule AshSurface.Ported.Rpc.C.NestedQueryOptsPipelineGapTest do
  use ExUnit.Case, async: true

  # describe "end-to-end nested query options"

  @tag skip:
         "T10 gap: nested_query_opts_pipeline (multitenant nested paging needs a data layer: tenant isolation of rows is decided by the data layer and ash_surface never actuates; capability runtime.module.Rpc.Pipeline execution stage)"
  test "014 multitenant nested envelope pages within the tenant" do
    :ok
  end
end
