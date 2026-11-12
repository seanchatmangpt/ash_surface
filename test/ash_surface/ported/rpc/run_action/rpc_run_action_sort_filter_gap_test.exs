defmodule AshSurface.Ported.Rpc.RunAction.SortFilterGapTest do
  use ExUnit.Case, async: true

  @tag skip:
         "GU7 gap: asserts order/membership/pagination computed by the data layer (sort, filter, aggregate sort/filter over persisted records); AshSurface never actuates (README: it never actuates), so no read executes. Request parsing of sort/filter/page and the enable_sort?/enable_filter? refusals are covered in rpc_run_action_sort_filter_surface_test.exs"
  test "ascending sort by title" do
    :ok
  end

  @tag skip:
         "GU7 gap: asserts order/membership/pagination computed by the data layer (sort, filter, aggregate sort/filter over persisted records); AshSurface never actuates (README: it never actuates), so no read executes. Request parsing of sort/filter/page and the enable_sort?/enable_filter? refusals are covered in rpc_run_action_sort_filter_surface_test.exs"
  test "descending sort by title" do
    :ok
  end

  @tag skip:
         "GU7 gap: asserts order/membership/pagination computed by the data layer (sort, filter, aggregate sort/filter over persisted records); AshSurface never actuates (README: it never actuates), so no read executes. Request parsing of sort/filter/page and the enable_sort?/enable_filter? refusals are covered in rpc_run_action_sort_filter_surface_test.exs"
  test "ascending with explicit + prefix" do
    :ok
  end

  @tag skip:
         "GU7 gap: asserts order/membership/pagination computed by the data layer (sort, filter, aggregate sort/filter over persisted records); AshSurface never actuates (README: it never actuates), so no read executes. Request parsing of sort/filter/page and the enable_sort?/enable_filter? refusals are covered in rpc_run_action_sort_filter_surface_test.exs"
  test "comma-separated multi-field sort string" do
    :ok
  end

  @tag skip:
         "GU7 gap: asserts order/membership/pagination computed by the data layer (sort, filter, aggregate sort/filter over persisted records); AshSurface never actuates (README: it never actuates), so no read executes. Request parsing of sort/filter/page and the enable_sort?/enable_filter? refusals are covered in rpc_run_action_sort_filter_surface_test.exs"
  test "single-element list ascending" do
    :ok
  end

  @tag skip:
         "GU7 gap: asserts order/membership/pagination computed by the data layer (sort, filter, aggregate sort/filter over persisted records); AshSurface never actuates (README: it never actuates), so no read executes. Request parsing of sort/filter/page and the enable_sort?/enable_filter? refusals are covered in rpc_run_action_sort_filter_surface_test.exs"
  test "single-element list descending" do
    :ok
  end

  @tag skip:
         "GU7 gap: asserts order/membership/pagination computed by the data layer (sort, filter, aggregate sort/filter over persisted records); AshSurface never actuates (README: it never actuates), so no read executes. Request parsing of sort/filter/page and the enable_sort?/enable_filter? refusals are covered in rpc_run_action_sort_filter_surface_test.exs"
  test "multi-element list sort" do
    :ok
  end

  @tag skip:
         "GU7 gap: asserts order/membership/pagination computed by the data layer (sort, filter, aggregate sort/filter over persisted records); AshSurface never actuates (README: it never actuates), so no read executes. Request parsing of sort/filter/page and the enable_sort?/enable_filter? refusals are covered in rpc_run_action_sort_filter_surface_test.exs"
  test "list sort with ++ prefix (asc_nils_first)" do
    :ok
  end

  @tag skip:
         "GU7 gap: asserts order/membership/pagination computed by the data layer (sort, filter, aggregate sort/filter over persisted records); AshSurface never actuates (README: it never actuates), so no read executes. Request parsing of sort/filter/page and the enable_sort?/enable_filter? refusals are covered in rpc_run_action_sort_filter_surface_test.exs"
  test "list sort with -- prefix (desc_nils_last)" do
    :ok
  end

  @tag skip:
         "GU7 gap: asserts order/membership/pagination computed by the data layer (sort, filter, aggregate sort/filter over persisted records); AshSurface never actuates (README: it never actuates), so no read executes. Request parsing of sort/filter/page and the enable_sort?/enable_filter? refusals are covered in rpc_run_action_sort_filter_surface_test.exs"
  test "list sort with camelCase field names" do
    :ok
  end

  @tag skip:
         "GU7 gap: asserts order/membership/pagination computed by the data layer (sort, filter, aggregate sort/filter over persisted records); AshSurface never actuates (README: it never actuates), so no read executes. Request parsing of sort/filter/page and the enable_sort?/enable_filter? refusals are covered in rpc_run_action_sort_filter_surface_test.exs"
  test "isNil: true returns records with nil field" do
    :ok
  end

  @tag skip:
         "GU7 gap: asserts order/membership/pagination computed by the data layer (sort, filter, aggregate sort/filter over persisted records); AshSurface never actuates (README: it never actuates), so no read executes. Request parsing of sort/filter/page and the enable_sort?/enable_filter? refusals are covered in rpc_run_action_sort_filter_surface_test.exs"
  test "isNil: false returns records with non-nil field" do
    :ok
  end

  @tag skip:
         "GU7 gap: asserts order/membership/pagination computed by the data layer (sort, filter, aggregate sort/filter over persisted records); AshSurface never actuates (README: it never actuates), so no read executes. Request parsing of sort/filter/page and the enable_sort?/enable_filter? refusals are covered in rpc_run_action_sort_filter_surface_test.exs"
  test "isNil combined with eq in AND" do
    :ok
  end

  @tag skip:
         "GU7 gap: asserts order/membership/pagination computed by the data layer (sort, filter, aggregate sort/filter over persisted records); AshSurface never actuates (README: it never actuates), so no read executes. Request parsing of sort/filter/page and the enable_sort?/enable_filter? refusals are covered in rpc_run_action_sort_filter_surface_test.exs"
  test "isNil combined with eq in OR" do
    :ok
  end

  @tag skip:
         "GU7 gap: asserts order/membership/pagination computed by the data layer (sort, filter, aggregate sort/filter over persisted records); AshSurface never actuates (README: it never actuates), so no read executes. Request parsing of sort/filter/page and the enable_sort?/enable_filter? refusals are covered in rpc_run_action_sort_filter_surface_test.exs"
  test "isNil on boolean field" do
    :ok
  end

  @tag skip:
         "GU7 gap: asserts order/membership/pagination computed by the data layer (sort, filter, aggregate sort/filter over persisted records); AshSurface never actuates (README: it never actuates), so no read executes. Request parsing of sort/filter/page and the enable_sort?/enable_filter? refusals are covered in rpc_run_action_sort_filter_surface_test.exs"
  test "filter + string sort" do
    :ok
  end

  @tag skip:
         "GU7 gap: asserts order/membership/pagination computed by the data layer (sort, filter, aggregate sort/filter over persisted records); AshSurface never actuates (README: it never actuates), so no read executes. Request parsing of sort/filter/page and the enable_sort?/enable_filter? refusals are covered in rpc_run_action_sort_filter_surface_test.exs"
  test "filter + list sort" do
    :ok
  end

  @tag skip:
         "GU7 gap: asserts order/membership/pagination computed by the data layer (sort, filter, aggregate sort/filter over persisted records); AshSurface never actuates (README: it never actuates), so no read executes. Request parsing of sort/filter/page and the enable_sort?/enable_filter? refusals are covered in rpc_run_action_sort_filter_surface_test.exs"
  test "isNil filter + list sort + offset pagination" do
    :ok
  end

  @tag skip:
         "GU7 gap: asserts order/membership/pagination computed by the data layer (sort, filter, aggregate sort/filter over persisted records); AshSurface never actuates (README: it never actuates), so no read executes. Request parsing of sort/filter/page and the enable_sort?/enable_filter? refusals are covered in rpc_run_action_sort_filter_surface_test.exs"
  test "isNil filter + list sort + offset pagination page 2" do
    :ok
  end

  @tag skip:
         "GU7 gap: asserts order/membership/pagination computed by the data layer (sort, filter, aggregate sort/filter over persisted records); AshSurface never actuates (README: it never actuates), so no read executes. Request parsing of sort/filter/page and the enable_sort?/enable_filter? refusals are covered in rpc_run_action_sort_filter_surface_test.exs"
  test "sort by commentCount ascending" do
    :ok
  end

  @tag skip:
         "GU7 gap: asserts order/membership/pagination computed by the data layer (sort, filter, aggregate sort/filter over persisted records); AshSurface never actuates (README: it never actuates), so no read executes. Request parsing of sort/filter/page and the enable_sort?/enable_filter? refusals are covered in rpc_run_action_sort_filter_surface_test.exs"
  test "sort by commentCount descending" do
    :ok
  end

  @tag skip:
         "GU7 gap: asserts order/membership/pagination computed by the data layer (sort, filter, aggregate sort/filter over persisted records); AshSurface never actuates (README: it never actuates), so no read executes. Request parsing of sort/filter/page and the enable_sort?/enable_filter? refusals are covered in rpc_run_action_sort_filter_surface_test.exs"
  test "sort by aggregate in list format with secondary sort" do
    :ok
  end

  @tag skip:
         "GU7 gap: asserts order/membership/pagination computed by the data layer (sort, filter, aggregate sort/filter over persisted records); AshSurface never actuates (README: it never actuates), so no read executes. Request parsing of sort/filter/page and the enable_sort?/enable_filter? refusals are covered in rpc_run_action_sort_filter_surface_test.exs"
  test "filter by :count aggregate (commentCount > 1)" do
    :ok
  end

  @tag skip:
         "GU7 gap: asserts order/membership/pagination computed by the data layer (sort, filter, aggregate sort/filter over persisted records); AshSurface never actuates (README: it never actuates), so no read executes. Request parsing of sort/filter/page and the enable_sort?/enable_filter? refusals are covered in rpc_run_action_sort_filter_surface_test.exs"
  test "filter by :exists aggregate (hasComments)" do
    :ok
  end

  @tag skip:
         "GU7 gap: asserts order/membership/pagination computed by the data layer (sort, filter, aggregate sort/filter over persisted records); AshSurface never actuates (README: it never actuates), so no read executes. Request parsing of sort/filter/page and the enable_sort?/enable_filter? refusals are covered in rpc_run_action_sort_filter_surface_test.exs"
  test "filter by :exists aggregate (hasComments = false)" do
    :ok
  end

  @tag skip:
         "GU7 gap: asserts order/membership/pagination computed by the data layer (sort, filter, aggregate sort/filter over persisted records); AshSurface never actuates (README: it never actuates), so no read executes. Request parsing of sort/filter/page and the enable_sort?/enable_filter? refusals are covered in rpc_run_action_sort_filter_surface_test.exs"
  test "filter by :max aggregate (highestRating >= 5)" do
    :ok
  end

  @tag skip:
         "GU7 gap: asserts order/membership/pagination computed by the data layer (sort, filter, aggregate sort/filter over persisted records); AshSurface never actuates (README: it never actuates), so no read executes. Request parsing of sort/filter/page and the enable_sort?/enable_filter? refusals are covered in rpc_run_action_sort_filter_surface_test.exs"
  test "filter by :avg aggregate (averageRating > 3)" do
    :ok
  end

  @tag skip:
         "GU7 gap: asserts order/membership/pagination computed by the data layer (sort, filter, aggregate sort/filter over persisted records); AshSurface never actuates (README: it never actuates), so no read executes. Request parsing of sort/filter/page and the enable_sort?/enable_filter? refusals are covered in rpc_run_action_sort_filter_surface_test.exs"
  test "filter by :first aggregate (latestCommentContent)" do
    :ok
  end

  @tag skip:
         "GU7 gap: asserts order/membership/pagination computed by the data layer (sort, filter, aggregate sort/filter over persisted records); AshSurface never actuates (README: it never actuates), so no read executes. Request parsing of sort/filter/page and the enable_sort?/enable_filter? refusals are covered in rpc_run_action_sort_filter_surface_test.exs"
  test "filter by :first aggregate with isNil (no comments)" do
    :ok
  end

  @tag skip:
         "GU7 gap: asserts order/membership/pagination computed by the data layer (sort, filter, aggregate sort/filter over persisted records); AshSurface never actuates (README: it never actuates), so no read executes. Request parsing of sort/filter/page and the enable_sort?/enable_filter? refusals are covered in rpc_run_action_sort_filter_surface_test.exs"
  test "combined aggregate filter + sort" do
    :ok
  end

  @tag skip:
         "GU7 gap: asserts order/membership/pagination computed by the data layer (sort, filter, aggregate sort/filter over persisted records); AshSurface never actuates (README: it never actuates), so no read executes. Request parsing of sort/filter/page and the enable_sort?/enable_filter? refusals are covered in rpc_run_action_sort_filter_surface_test.exs"
  test "combined aggregate filter + isNil + pagination" do
    :ok
  end
end
