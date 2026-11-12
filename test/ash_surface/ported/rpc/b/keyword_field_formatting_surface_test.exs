defmodule AshSurface.Ported.Rpc.B.KeywordFieldFormattingSurfaceTest do
  @moduledoc """
  Non-actuating counterpart of ash_typescript `rpc/keyword_field_formatting_test`: the
  created/fetched todo is a caller-built result carrying keyword `options`; the pipeline
  must emit string keys in client format.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.{Rpc, RpcFixtures}

  defp assert_string_keyed(options, priority, category, notify) do
    for k <- ["priority", "category", "notify"], do: assert(Map.has_key?(options, k))
    for k <- [:priority, :category, :notify], do: refute(Map.has_key?(options, k))
    assert options["priority"] == priority
    assert options["category"] == category
    assert options["notify"] == notify
  end

  describe "keyword field formatting" do
    test "keyword field keys are formatted to client format in output" do
      todo =
        RpcFixtures.todo(
          title: "Keyword Test Todo",
          options: [priority: 8, category: "urgent", notify: true]
        )

      result =
        Rpc.run(
          %{
            "action" => "create_todo",
            "input" => %{"title" => "Keyword Test Todo", "userId" => RpcFixtures.user_id()},
            "fields" => ["id", "title", %{"options" => ["priority", "category", "notify"]}]
          },
          todo
        )

      assert result["success"] == true, inspect(result)
      assert_string_keyed(result["data"]["options"], 8, "urgent", true)
    end

    test "keyword field formatting works when fetching existing records" do
      todo =
        RpcFixtures.todo(
          title: "Fetch Test Todo",
          options: [priority: 3, category: "personal", notify: false]
        )

      result =
        Rpc.run(
          %{
            "action" => "get_todo",
            "input" => %{"id" => todo.id},
            "fields" => ["id", "title", %{"options" => ["priority", "category", "notify"]}]
          },
          todo
        )

      assert result["success"] == true, inspect(result)
      assert_string_keyed(result["data"]["options"], 3, "personal", false)
    end
  end
end
