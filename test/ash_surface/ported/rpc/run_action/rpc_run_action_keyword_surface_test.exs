defmodule AshSurface.Ported.RpcRunActionKeywordSurfaceTest do
  @moduledoc """
  Non-actuating counterpart of `rpc_run_action_keyword_test.exs`: keyword-typed `options`
  attributes are carried by hand-built `Todo` structs and shaped by the result processor.
  The two `Ash.create!` direct tests stay in the gap file (they exercise actuation).
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.{Rpc, RpcFixtures}
  import RpcFixtures, only: [todo: 1, user: 1]

  @work "aaaaaaaa-0000-0000-0000-000000000001"
  @personal "aaaaaaaa-0000-0000-0000-000000000002"
  @urgent "aaaaaaaa-0000-0000-0000-000000000003"
  @low "aaaaaaaa-0000-0000-0000-000000000004"
  @basic "aaaaaaaa-0000-0000-0000-000000000005"

  defp todos do
    u = user(name: "Keyword User", email: "keyword@example.com")

    [
      todo(
        id: @work,
        title: "Work Todo with Options",
        user: u,
        options: [priority: 8, category: "work", notify: true]
      ),
      todo(
        id: @personal,
        title: "Personal Todo with Options",
        user: u,
        options: [priority: 5, category: "personal", notify: false]
      ),
      todo(
        id: @urgent,
        title: "Urgent Todo with Options",
        user: u,
        options: [priority: 10, category: "urgent", notify: true]
      ),
      todo(
        id: @low,
        title: "Low Priority Todo with Options",
        user: u,
        options: [priority: 2, category: "later", notify: false]
      ),
      todo(id: @basic, title: "Basic Todo", user: u, options: nil)
    ]
  end

  defp list(fields), do: Rpc.run(%{"action" => "list_todos", "fields" => fields}, todos())
  defp by_id(result, id), do: Enum.find(result["data"], &(&1["id"] == id))

  defp get(id, fields) do
    t = Enum.find(todos(), &(&1.id == id))

    Rpc.run(
      %{"action" => "get_todo_by_id", "input" => %{"id" => id}, "fields" => fields},
      t
    )
  end

  describe "keyword field selection" do
    test "processes keyword field selection correctly" do
      result = list(["id", "title", %{"options" => ["priority", "category", "notify"]}])
      assert result["success"] == true
      assert is_list(result["data"])

      Enum.each(result["data"], fn t ->
        assert Map.has_key?(t, "id")
        assert Map.has_key?(t, "title")
      end)

      work = by_id(result, @work)
      assert work["options"] == %{"priority" => 8, "category" => "work", "notify" => true}

      personal = by_id(result, @personal)

      assert personal["options"] == %{
               "priority" => 5,
               "category" => "personal",
               "notify" => false
             }
    end

    test "verifies todos created with keyword options" do
      urgent = get(@urgent, ["id", "title", %{"options" => ["priority", "category", "notify"]}])
      assert urgent["success"] == true
      t = urgent["data"]
      assert t["title"] == "Urgent Todo with Options"
      assert Map.has_key?(t, "options")
      assert t["options"]["priority"] == 10
      assert t["options"]["category"] == "urgent"
      assert Map.has_key?(t["options"], "notify")

      low = get(@low, ["id", "title", %{"options" => ["priority", "notify"]}])
      assert low["success"] == true
      t = low["data"]
      assert t["title"] == "Low Priority Todo with Options"
      assert t["options"]["priority"] == 2
      assert t["options"]["notify"] == false
      refute Map.has_key?(t["options"], "category")
    end

    test "processes partial keyword field selection" do
      result = list(["id", "title", %{"options" => ["priority", "category"]}])
      assert result["success"] == true

      assert by_id(result, @work)["options"] == %{"priority" => 8, "category" => "work"}
      assert by_id(result, @personal)["options"] == %{"priority" => 5, "category" => "personal"}
    end

    test "processes single keyword field selection" do
      result = list(["id", "title", %{"options" => ["priority"]}])
      assert result["success"] == true

      assert by_id(result, @urgent)["options"] == %{"priority" => 10}
      assert by_id(result, @low)["options"] == %{"priority" => 2}
    end

    test "compares different keyword field selections" do
      all = get(@work, ["id", "title", %{"options" => ["priority", "category", "notify"]}])
      subset = get(@work, ["id", "title", %{"options" => ["priority", "notify"]}])
      single = get(@work, ["id", "title", %{"options" => ["category"]}])

      for r <- [all, subset, single] do
        assert r["success"] == true
        assert Map.has_key?(r["data"], "id")
        assert r["data"]["title"] == "Work Todo with Options"
      end

      assert all["data"]["options"] == %{"priority" => 8, "category" => "work", "notify" => true}
      assert subset["data"]["options"] == %{"priority" => 8, "notify" => true}
      assert single["data"]["options"] == %{"category" => "work"}
    end

    test "processes keyword fields with relationships" do
      result =
        list([
          "id",
          "title",
          %{"options" => ["priority", "category", "notify"]},
          %{"user" => ["id", "name", "email"]}
        ])

      assert result["success"] == true

      Enum.each(result["data"], fn t ->
        assert Map.has_key?(t, "id")
        assert Map.has_key?(t, "title")
        assert Map.has_key?(t["user"], "id")
        assert Map.has_key?(t["user"], "name")
        assert Map.has_key?(t["user"], "email")
      end)

      work = by_id(result, @work)
      assert work["options"]["priority"] == 8
      assert work["options"]["category"] == "work"
      assert work["options"]["notify"] == true
      assert work["user"]["name"] == "Keyword User"
      assert work["user"]["email"] == "keyword@example.com"

      personal = by_id(result, @personal)
      assert personal["options"]["priority"] == 5
      assert personal["options"]["category"] == "personal"
      assert personal["options"]["notify"] == false
    end
  end

  describe "generic action returning keyword type" do
    @keyword_result [priority: 8, category: "work", notify: true, theme: "dark"]

    test "runs get_keyword_options_todo action and processes field selection" do
      result =
        Rpc.run(
          %{
            "action" => "get_keyword_options_todo",
            "fields" => ["priority", "category", "notify", "theme"]
          },
          @keyword_result
        )

      assert result["success"] == true
      options = result["data"]
      assert is_map(options)
      assert options["priority"] == 8
      assert options["category"] == "work"
      assert options["notify"] == true
      assert options["theme"] == "dark"
    end

    test "runs get_keyword_options_todo action with partial field selection" do
      result =
        Rpc.run(
          %{"action" => "get_keyword_options_todo", "fields" => ["priority", "notify"]},
          @keyword_result
        )

      assert result["success"] == true
      options = result["data"]
      assert options["priority"] == 8
      assert options["notify"] == true
      refute Map.has_key?(options, "category")
      refute Map.has_key?(options, "theme")
    end

    test "runs get_keyword_options_todo action with single field selection" do
      result =
        Rpc.run(%{"action" => "get_keyword_options_todo", "fields" => ["theme"]}, @keyword_result)

      assert result["success"] == true
      options = result["data"]
      assert options["theme"] == "dark"
      refute Map.has_key?(options, "priority")
      refute Map.has_key?(options, "category")
      refute Map.has_key?(options, "notify")
    end
  end

  describe "keyword field edge cases" do
    test "handles todos without keyword fields set" do
      result = list(["id", "title", %{"options" => ["priority", "category", "notify"]}])
      assert result["success"] == true

      Enum.each(result["data"], fn t ->
        assert Map.has_key?(t, "id")
        assert Map.has_key?(t, "title")
      end)

      assert by_id(result, @basic)["options"] == nil
    end

    test "handles partial keyword fields correctly" do
      result = list(["id", "title", %{"options" => ["priority", "category", "notify"]}])
      assert result["success"] == true

      Enum.each(result["data"], fn t ->
        assert Map.has_key?(t, "id")
        assert Map.has_key?(t, "title")
      end)
    end

    test "handles only valid keyword fields" do
      result = list(["id", "title", %{"options" => ["priority", "category"]}])
      assert result["success"] == true

      Enum.each(result["data"], fn t ->
        assert Map.has_key?(t, "id")
        assert Map.has_key?(t, "title")
      end)
    end

    test "processes keyword fields with mixed data types" do
      result = list(["id", "title", %{"options" => ["priority", "category", "notify"]}])
      assert result["success"] == true

      Enum.each(result["data"], fn t ->
        if t["options"] != nil do
          options = t["options"]
          if options["priority"] != nil, do: assert(is_integer(options["priority"]))
          if options["category"] != nil, do: assert(is_binary(options["category"]))
          if options["notify"] != nil, do: assert(is_boolean(options["notify"]))
        end
      end)
    end
  end
end
