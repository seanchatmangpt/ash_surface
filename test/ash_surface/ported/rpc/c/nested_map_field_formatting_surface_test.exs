defmodule AshSurface.Ported.Rpc.C.NestedMapFieldFormattingSurfaceTest do
  @moduledoc """
  Adaptation of the reference nested_map_field_formatting tests (4). The reference asserts that
  the generated TypeScript text spells nested typed-map keys in camelCase and never in
  snake_case. ash_surface emits no `.ts`; the behavior those assertions prove is the client
  contract of nested typed-map keys, which the non-actuating RPC pipeline owns: selection
  accepts only camelCase names and the shaped wire result carries only camelCase keys.

  Each case feeds a caller-built (already materialized) action result through the real
  pipeline (`Rpc.run/2`: parse -> field selection -> output formatter).
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.Rpc, as: R

  @users %{
    results: [
      %{
        id: "user-1",
        email: "test@example.com",
        first_name: "Test",
        last_name: "User",
        phone: nil,
        is_admin: false,
        confirmed_at: ~U[2025-01-02 03:04:05.000000Z],
        inserted_at: ~U[2025-01-01 00:00:00Z]
      }
    ],
    total_count: 1
  }

  @stats %{
    user_stats: %{active_users: 1000, new_signups: 50, churn_rate: 0.05},
    content_stats: %{total_posts: 5000, posts_this_week: 100, avg_engagement_rate: 0.15}
  }

  defp run(action, fields, result) do
    R.run(%{"action" => action, "fields" => fields}, result)
  end

  defp keys_deep(%{} = m), do: Enum.flat_map(m, fn {k, v} -> [k | keys_deep(v)] end)
  defp keys_deep(l) when is_list(l), do: Enum.flat_map(l, &keys_deep/1)
  defp keys_deep(_), do: []

  test "001 list_users_map action generates camelCase field names for nested array fields" do
    camel = ~w(firstName lastName isAdmin confirmedAt insertedAt)

    result = run("list_users_map", ["totalCount", %{"results" => ["id" | camel]}], @users)

    assert result["success"] == true, inspect(result)
    assert result["data"]["totalCount"] == 1
    [row] = result["data"]["results"]
    assert row |> Map.keys() |> Enum.sort() == Enum.sort(["id" | camel])
    assert row["firstName"] == "Test"
    assert row["isAdmin"] == false
  end

  test "002 an array of typed maps inside a typed map uses the selectable array encoding" do
    # BEHAVIORAL-COUNTERPART-FOUND: the `{ __array: true; ...TypedMap }` encoding means the
    # nested selection applies to every item of the array, not to the array as a whole.
    users = %{@users | results: @users.results ++ @users.results}

    result = run("list_users_map", [%{"results" => ["id", "email"]}], users)

    assert result["success"] == true, inspect(result)

    assert result["data"] == %{
             "results" => [
               %{"id" => "user-1", "email" => "test@example.com"},
               %{"id" => "user-1", "email" => "test@example.com"}
             ]
           }
  end

  test "003 nested map fields should NOT contain snake_case versions" do
    snake = ~w(first_name last_name is_admin confirmed_at inserted_at total_count)

    # a snake_case selection (accepted leniently at parse) is still emitted camelCase
    lenient = run("list_users_map", [%{"results" => ["first_name"]}], @users)
    assert lenient["data"] == %{"results" => [%{"firstName" => "Test"}]}

    # no snake_case key survives in a fully selected wire result
    result =
      run(
        "list_users_map",
        [
          "totalCount",
          %{
            "results" => ~w(id email firstName lastName phone isAdmin confirmedAt insertedAt)
          }
        ],
        @users
      )

    assert result["success"] == true, inspect(result)
    wire_keys = keys_deep(result["data"])
    assert Enum.all?(snake, &(&1 not in wire_keys))
    assert "totalCount" in wire_keys
  end

  test "004 get_nested_stats action generates camelCase for deeply nested map fields" do
    result =
      run(
        "get_nested_stats",
        [
          %{"userStats" => ["activeUsers", "newSignups", "churnRate"]},
          %{"contentStats" => ["totalPosts", "postsThisWeek", "avgEngagementRate"]}
        ],
        @stats
      )

    assert result["success"] == true, inspect(result)

    assert result["data"] == %{
             "userStats" => %{"activeUsers" => 1000, "newSignups" => 50, "churnRate" => 0.05},
             "contentStats" => %{
               "totalPosts" => 5000,
               "postsThisWeek" => 100,
               "avgEngagementRate" => 0.15
             }
           }

    snake = ~w(user_stats content_stats active_users new_signups churn_rate total_posts
               posts_this_week avg_engagement_rate)
    assert Enum.all?(snake, &(&1 not in keys_deep(result["data"])))
  end
end
