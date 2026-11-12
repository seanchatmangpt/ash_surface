defmodule AshSurface.Ported.Rpc.B.MapFieldNameSelectionTest do
  @moduledoc """
  Selection-level counterpart of ash_typescript `rpc/map_field_name_rpc_test` (field-name
  acceptance half: camelCase and snake_case selections resolve to the same internal fields).
  The execution half (`data[...]` output keys) is in `map_field_name_rpc_gap_test.exs`.
  Additional to the reference test names; mapped in the ledger row's `changes`.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Ported.NestedMapResource
  alias AshSurface.Ported.RFP

  describe "map return types accept camelCase and snake_case selections" do
    test "get_metrics accepts camelCase field names" do
      assert {:ok, {_select, _load, template}} =
               RFP.process(NestedMapResource, :get_metrics, [
                 "total",
                 "lastWeek",
                 "lastMonth",
                 "lastYear"
               ])

      assert template == [:total, :last_week, :last_month, :last_year]
    end

    test "get_metrics accepts snake_case field names" do
      assert {:ok, {_select, _load, template}} =
               RFP.process(NestedMapResource, :get_metrics, [
                 "total",
                 "last_week",
                 "last_month",
                 "last_year"
               ])

      assert template == [:total, :last_week, :last_month, :last_year]
    end

    test "get_nested_stats accepts camelCase nested selection" do
      assert {:ok, {_select, _load, template}} =
               RFP.process(NestedMapResource, :get_nested_stats, [
                 %{"userStats" => ["activeUsers", "newSignups", "churnRate"]},
                 %{"contentStats" => ["totalPosts", "postsThisWeek", "avgEngagementRate"]}
               ])

      assert template[:user_stats] == [:active_users, :new_signups, :churn_rate]
      assert template[:content_stats] == [:total_posts, :posts_this_week, :avg_engagement_rate]
    end

    test "list_users_map accepts camelCase nested array selection" do
      assert {:ok, {_select, _load, template}} =
               RFP.process(NestedMapResource, :list_users_map, [
                 "totalCount",
                 %{"results" => ["id", "email", "firstName", "lastName", "isAdmin"]}
               ])

      assert template[:results] == [:id, :email, :first_name, :last_name, :is_admin]
    end

    test "get_metadata_report selects nested embedded fields per row" do
      assert {:ok, {_select, _load, template}} =
               RFP.process(NestedMapResource, :get_metadata_report, [
                 "total",
                 %{"rows" => ["category", "priorityScore"]}
               ])

      assert template[:rows] == [:category, :priority_score]
    end
  end
end
