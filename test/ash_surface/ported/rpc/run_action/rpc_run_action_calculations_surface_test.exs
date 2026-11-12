defmodule AshSurface.Ported.RpcRunActionCalculationsSurfaceTest do
  @moduledoc """
  Non-actuating counterpart of `rpc_run_action_calculations_test.exs`. Refusals come from
  `Rpc.Pipeline.parse_request/2`; success shapes from the result processor over hand-built
  `Todo` structs whose calculations are already loaded. Calculation-with-arguments requests
  additionally assert the parsed `load` statement (the calculation call Ash would receive).
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.{Rpc, RpcFixtures}
  import RpcFixtures, only: [todo: 1, user: 1, comment: 1]

  @summary %{
    view_count: 42,
    edit_count: 7,
    completion_time_seconds: 1800,
    difficulty_rating: 3.5,
    all_completed?: false,
    performance_metrics: %{
      focus_time_seconds: 900,
      interruption_count: 3,
      efficiency_score: 0.85,
      task_complexity: "medium"
    }
  }

  defp list(fields, todos), do: Rpc.run(%{"action" => "list_todos", "fields" => fields}, todos)
  defp refuse(fields), do: Rpc.error(%{"action" => "list_todos", "fields" => fields})

  defp first_error(result) do
    assert result["success"] == false
    assert is_list(result["errors"])
    hd(result["errors"])
  end

  defp self_todo(title, attrs \\ []),
    do:
      todo(
        [title: title, description: "A todo for testing self calculations", completed: false] ++
          attrs
      )

  defp with_self(title, inner_attrs \\ []),
    do: [todo(title: title, self: self_todo(title, inner_attrs))]

  describe "simple calculations without arguments" do
    defp calc_todos,
      do: [
        todo(title: "Overdue Todo", is_overdue: true, days_until_due: -1),
        todo(
          id: "99999999-0000-0000-0000-000000000001",
          title: "Future Todo",
          is_overdue: false,
          days_until_due: 1
        )
      ]

    test "processes boolean calculations" do
      result = list(["id", "title", "isOverdue"], calc_todos())
      assert result["success"] == true
      assert is_list(result["data"])

      Enum.each(result["data"], fn t ->
        assert Map.has_key?(t, "id")
        assert Map.has_key?(t, "title")
        assert is_boolean(t["isOverdue"])
        refute Map.has_key?(t, "description")
        refute Map.has_key?(t, "completed")
      end)

      assert Enum.find(result["data"], &(&1["title"] == "Overdue Todo"))["isOverdue"] == true
      assert Enum.find(result["data"], &(&1["title"] == "Future Todo"))["isOverdue"] == false
    end

    test "processes integer calculations" do
      result = list(["id", "daysUntilDue"], calc_todos())
      assert result["success"] == true

      Enum.each(result["data"], fn t ->
        assert Map.has_key?(t, "id")
        assert Map.has_key?(t, "daysUntilDue")
        if t["daysUntilDue"] != nil, do: assert(is_integer(t["daysUntilDue"]))
        refute Map.has_key?(t, "title")
        refute Map.has_key?(t, "description")
      end)
    end

    test "processes multiple simple calculations" do
      result = list(["id", "isOverdue", "daysUntilDue"], calc_todos())
      assert result["success"] == true

      Enum.each(result["data"], fn t ->
        assert Map.has_key?(t, "id")
        assert is_boolean(t["isOverdue"])
        assert Map.has_key?(t, "daysUntilDue")
        if t["daysUntilDue"] != nil, do: assert(is_integer(t["daysUntilDue"]))
        refute Map.has_key?(t, "title")
        refute Map.has_key?(t, "description")
      end)
    end
  end

  describe "calculations with arguments and field selection" do
    test "processes struct calculation with arguments and basic field selection" do
      fields = [
        "id",
        "title",
        %{
          "self" => %{
            "args" => %{"prefix" => "my_prefix"},
            "fields" => ["description", "completed"]
          }
        }
      ]

      assert {:ok, request} = Rpc.parse(%{"action" => "list_todos", "fields" => fields})
      assert Enum.any?(request.load, &match?({:self, {%{prefix: "my_prefix"}, _}}, &1))

      result = list(fields, with_self("Self Calculation Todo"))
      assert result["success"] == true
      test_todo = Enum.find(result["data"], &(&1["title"] == "Self Calculation Todo"))
      assert Map.has_key?(test_todo, "id")
      assert Map.has_key?(test_todo, "title")
      self_result = test_todo["self"]
      assert Map.has_key?(self_result, "description")
      assert Map.has_key?(self_result, "completed")
      refute Map.has_key?(self_result, "title")
      refute Map.has_key?(self_result, "id")
      assert is_binary(self_result["description"])
      assert is_boolean(self_result["completed"])
    end

    test "processes calculation with nested relationship field selection" do
      inner = [user: user(name: "Self Calc User", email: "selfcalc@example.com")]

      result =
        list(
          [
            "id",
            %{
              "self" => %{
                "args" => %{"prefix" => "test"},
                "fields" => ["title", "description", %{"user" => ["id", "name"]}]
              }
            }
          ],
          with_self("Self Calculation Todo", inner)
        )

      assert result["success"] == true

      test_todo =
        Enum.find(result["data"], fn t ->
          t["self"] && t["self"]["title"] == "Self Calculation Todo"
        end)

      assert Map.has_key?(test_todo, "id")
      self_result = test_todo["self"]
      assert Map.has_key?(self_result, "title")
      assert Map.has_key?(self_result, "description")
      user_result = self_result["user"]
      assert Map.has_key?(user_result, "id")
      assert Map.has_key?(user_result, "name")
      refute Map.has_key?(user_result, "email")
    end

    test "processes calculation with complex nested relationships" do
      inner = [user: user(name: "Complex User", comments: [comment(content: "c1")])]

      result =
        list(
          [
            %{
              "self" => %{
                "args" => %{"prefix" => "complex"},
                "fields" => [
                  "id",
                  "title",
                  %{"user" => ["id", "name", %{"comments" => ["id", "content"]}]}
                ]
              }
            }
          ],
          with_self("Complex Nested Todo", inner)
        )

      assert result["success"] == true

      complex_todo =
        Enum.find(result["data"], fn t ->
          t["self"] && t["self"]["title"] == "Complex Nested Todo"
        end)

      self_result = complex_todo["self"]
      assert Map.has_key?(self_result, "id")
      assert Map.has_key?(self_result, "title")
      user_result = self_result["user"]
      assert Map.has_key?(user_result, "id")
      assert Map.has_key?(user_result, "name")
      assert is_list(user_result["comments"])

      Enum.each(user_result["comments"], fn c ->
        assert Map.has_key?(c, "id")
        assert Map.has_key?(c, "content")
      end)
    end
  end

  describe "calculation arguments handling" do
    test "processes calculation with empty arguments" do
      result =
        list(
          [
            "id",
            %{"self" => %{"args" => %{}, "fields" => ["title", "completed"]}}
          ],
          with_self("Args Todo")
        )

      assert result["success"] == true

      test_todo =
        Enum.find(result["data"], fn t -> t["self"] && t["self"]["title"] == "Args Todo" end)

      assert Map.has_key?(test_todo["self"], "title")
      assert Map.has_key?(test_todo["self"], "completed")
    end

    test "processes calculation with nil argument values" do
      fields = ["id", %{"self" => %{"args" => %{"prefix" => nil}, "fields" => ["title"]}}]
      assert {:ok, request} = Rpc.parse(%{"action" => "list_todos", "fields" => fields})
      assert Enum.any?(request.load, &match?({:self, {%{prefix: nil}, _}}, &1))

      result = list(fields, with_self("Args Todo"))
      assert result["success"] == true

      test_todo =
        Enum.find(result["data"], fn t -> t["self"] && t["self"]["title"] == "Args Todo" end)

      assert Map.has_key?(test_todo["self"], "title")
    end

    test "processes calculation with multiple argument types" do
      fields = [
        %{
          "self" => %{
            "args" => %{
              "prefix" => "test",
              "count" => 42,
              "enabled" => true,
              "data" => %{"nested" => "value"}
            },
            "fields" => ["id", "title"]
          }
        }
      ]

      assert {:ok, request} = Rpc.parse(%{"action" => "list_todos", "fields" => fields})

      assert Enum.any?(request.load, fn
               {:self, {%{prefix: "test", count: 42, enabled: true, data: %{nested: "value"}}, _}} ->
                 true

               _ ->
                 false
             end)

      result = list(fields, with_self("Args Todo"))
      assert result["success"] == true
      test_todo = Enum.find(result["data"], fn t -> t["self"] && t["self"]["title"] end)
      assert Map.has_key?(test_todo["self"], "id")
      assert Map.has_key?(test_todo["self"], "title")
    end
  end

  describe "mixed calculations and other field types" do
    test "processes simple calculations with regular fields" do
      result =
        list(
          ["id", "title", "isOverdue", "commentCount"],
          [todo(is_overdue: false, comment_count: 0)]
        )

      assert result["success"] == true

      Enum.each(result["data"], fn t ->
        assert Map.has_key?(t, "id")
        assert Map.has_key?(t, "title")
        assert is_boolean(t["isOverdue"])
        assert is_integer(t["commentCount"])
        refute Map.has_key?(t, "description")
        refute Map.has_key?(t, "completed")
      end)
    end

    test "processes calculations with arguments alongside other field types" do
      todos = [
        todo(
          is_overdue: false,
          user: user(name: "Mixed User"),
          self: self_todo("Mixed Fields Todo")
        )
      ]

      result =
        list(
          [
            "id",
            "isOverdue",
            %{"user" => ["id", "name"]},
            %{
              "self" => %{
                "args" => %{"prefix" => "test"},
                "fields" => ["description", "completed"]
              }
            }
          ],
          todos
        )

      assert result["success"] == true
      test_todo = hd(result["data"])
      assert Map.has_key?(test_todo, "id")
      assert is_boolean(test_todo["isOverdue"])
      user_data = test_todo["user"]
      assert Map.has_key?(user_data, "id")
      assert Map.has_key?(user_data, "name")
      refute Map.has_key?(user_data, "email")
      self_result = test_todo["self"]
      assert Map.has_key?(self_result, "description")
      assert Map.has_key?(self_result, "completed")
      refute Map.has_key?(self_result, "title")
    end
  end

  describe "calculation validation and error handling" do
    test "returns error for calculation that requires arguments when requested as simple atom" do
      error = first_error(refuse(["id", "self"]))
      assert error["type"] == "unknown_field" || error["type"] == "invalid_field_format"
      assert List.first(error["fields"]) =~ "self"
    end

    test "returns error for calculation that doesn't take arguments when requested with nested structure" do
      error = first_error(refuse([%{"isOverdue" => %{"args" => %{}}}]))
      assert error["type"] == "invalid_calculation_args"
      assert List.first(error["fields"]) == "isOverdue"
    end

    test "returns error for aggregate when requested with nested structure" do
      error = first_error(refuse([%{"commentCount" => ["id"]}]))
      assert error["type"] == "invalid_field_selection"
      assert List.first(error["fields"]) == "commentCount"
    end

    test "returns error for attribute when requested with nested structure" do
      error = first_error(refuse([%{"title" => ["invalid"]}]))
      assert error["type"] == "field_does_not_support_nesting"
      assert List.first(error["fields"]) == "title"
    end

    test "returns error for invalid fields in calculation field selection" do
      error =
        first_error(
          refuse([%{"self" => %{"args" => %{"prefix" => "test"}, "fields" => ["invalidField"]}}])
        )

      assert error["type"] == "unknown_field"
      assert List.first(error["fields"]) == "self.invalidField"
    end

    test "returns error for invalid nested relationship fields in calculations" do
      error =
        first_error(
          refuse([
            %{
              "self" => %{
                "args" => %{"prefix" => "test"},
                "fields" => [%{"user" => ["invalidField"]}]
              }
            }
          ])
        )

      assert error["type"] == "unknown_field"
      assert List.first(error["fields"]) == "self.user.invalidField"
    end

    test "returns error for calculations with missing fields key" do
      error = first_error(refuse([%{"self" => %{"args" => %{"prefix" => "test"}}}]))
      assert error["type"] == "requires_field_selection"
    end

    test "returns error for calculations with missing args key" do
      error = first_error(refuse([%{"self" => %{"fields" => ["title"]}}]))
      assert error["type"] == "invalid_calculation_args"
    end

    test "returns error for non-existent calculations" do
      error = first_error(refuse([%{"nonExistentCalc" => %{"args" => %{}, "fields" => ["id"]}}]))
      assert error["type"] == "unknown_field"
      assert List.first(error["fields"]) == "nonExistentCalc"
    end

    test "handles malformed calculation request structure" do
      error = first_error(refuse([%{"self" => "invalid_structure"}]))
      assert error["type"] == "invalid_calculation_args"
    end
  end

  describe "calculation field selection validation" do
    test "returns error for primitive calculation with fields parameter" do
      fields = [
        %{
          "metadata" => [
            %{"formattedSummary" => %{"args" => %{"format" => "short"}, "fields" => []}}
          ]
        }
      ]

      result = refuse(fields)
      assert result["success"] == false
      assert hd(result["errors"])["type"] == "invalid_field_selection"
    end

    test "returns error for complex calculation without fields parameter" do
      error = first_error(refuse([%{"self" => %{"args" => %{"prefix" => "test"}}}]))
      assert error["type"] == "requires_field_selection"
    end

    test "returns error for complex calculation with empty fields" do
      error =
        first_error(refuse([%{"self" => %{"args" => %{"prefix" => "test"}, "fields" => []}}]))

      assert error["type"] == "requires_field_selection"
    end

    test "processes calculation with basic field selection" do
      result =
        list(
          [%{"self" => %{"args" => %{"prefix" => "test"}, "fields" => ["id", "title"]}}],
          with_self("Calculation Validation Todo")
        )

      assert result["success"] == true
      self_result = hd(result["data"])["self"]
      assert Map.has_key?(self_result, "id")
      assert Map.has_key?(self_result, "title")
      refute Map.has_key?(self_result, "description")
    end

    test "processes calculation selecting only relationships" do
      result =
        list(
          [
            %{
              "self" => %{
                "args" => %{"prefix" => "test"},
                "fields" => [%{"user" => ["id", "name"]}]
              }
            }
          ],
          with_self("T", user: user(name: "Embedded User"))
        )

      assert result["success"] == true
      user_result = hd(result["data"])["self"]["user"]
      assert Map.has_key?(user_result, "id")
      assert Map.has_key?(user_result, "name")
      refute Map.has_key?(user_result, "email")
    end

    test "processes calculation selecting only other calculations" do
      result =
        list(
          [
            %{
              "self" => %{
                "args" => %{"prefix" => "test"},
                "fields" => ["isOverdue", "daysUntilDue"]
              }
            }
          ],
          with_self("T", is_overdue: false, days_until_due: 3)
        )

      assert result["success"] == true
      self_result = hd(result["data"])["self"]
      assert is_boolean(self_result["isOverdue"])
      assert Map.has_key?(self_result, "daysUntilDue")
      assert is_integer(self_result["daysUntilDue"])
      refute Map.has_key?(self_result, "title")
      refute Map.has_key?(self_result, "description")
    end
  end

  describe "calculations without arguments returning complex types" do
    defp summary_todos(title \\ "Summary Calculation Todo"),
      do: [todo(title: title, summary: @summary)]

    test "processes no-argument calculation with basic field selection" do
      result =
        list(["id", "title", %{"summary" => ["viewCount", "editCount"]}], summary_todos())

      assert result["success"] == true
      test_todo = Enum.find(result["data"], &(&1["title"] == "Summary Calculation Todo"))
      assert Map.has_key?(test_todo, "id")
      summary_result = test_todo["summary"]
      assert summary_result["viewCount"] == 42
      assert summary_result["editCount"] == 7
      refute Map.has_key?(summary_result, "completionTimeSeconds")
      refute Map.has_key?(summary_result, "difficultyRating")
      refute Map.has_key?(summary_result, "performanceMetrics")
    end

    test "processes no-argument calculation with nested map field selection" do
      result =
        list(
          [
            "id",
            %{
              "summary" => [
                "viewCount",
                %{"performanceMetrics" => ["focusTimeSeconds", "efficiencyScore"]}
              ]
            }
          ],
          summary_todos()
        )

      assert result["success"] == true
      summary_result = hd(result["data"])["summary"]
      assert summary_result["viewCount"] == 42
      perf = summary_result["performanceMetrics"]
      assert perf["focusTimeSeconds"] == 900
      assert perf["efficiencyScore"] == 0.85
      refute Map.has_key?(perf, "interruptionCount")
      refute Map.has_key?(perf, "taskComplexity")
    end

    test "processes no-argument calculation selecting all available fields" do
      result =
        list(
          [
            "id",
            %{
              "summary" => [
                "viewCount",
                "editCount",
                "completionTimeSeconds",
                "difficultyRating",
                "allCompleted",
                %{
                  "performanceMetrics" => [
                    "focusTimeSeconds",
                    "interruptionCount",
                    "efficiencyScore",
                    "taskComplexity"
                  ]
                }
              ]
            }
          ],
          summary_todos()
        )

      assert result["success"] == true
      summary_result = hd(result["data"])["summary"]
      assert summary_result["viewCount"] == 42
      assert summary_result["editCount"] == 7
      assert summary_result["completionTimeSeconds"] == 1800
      assert summary_result["difficultyRating"] == 3.5
      assert summary_result["allCompleted"] == false
      perf = summary_result["performanceMetrics"]
      assert perf["focusTimeSeconds"] == 900
      assert perf["interruptionCount"] == 3
      assert perf["efficiencyScore"] == 0.85
      assert perf["taskComplexity"] == "medium"
    end

    test "returns error when requesting no-argument complex calculation as simple atom" do
      error = first_error(refuse(["id", "summary"]))
      assert error["type"] == "requires_field_selection"
      assert List.first(error["fields"]) == "summary"
    end

    test "returns error for invalid field in no-argument calculation field selection" do
      error = first_error(refuse([%{"summary" => ["viewCount", "nonExistentField"]}]))
      assert error["type"] == "unknown_field"
      assert List.first(error["fields"]) == "summary.nonExistentField"
    end

    test "returns error for invalid nested field in no-argument calculation" do
      error =
        first_error(
          refuse([
            %{"summary" => [%{"performanceMetrics" => ["focusTimeSeconds", "invalidField"]}]}
          ])
        )

      assert error["type"] == "unknown_map_field"
      assert List.first(error["fields"]) == "summary.performanceMetrics.invalidField"
    end

    test "processes no-argument calculation alongside with-argument calculation" do
      todos = [todo(summary: @summary, self: self_todo("S"))]

      result =
        list(
          [
            "id",
            %{"summary" => ["viewCount", "editCount"]},
            %{"self" => %{"args" => %{"prefix" => "test"}, "fields" => ["title", "completed"]}}
          ],
          todos
        )

      assert result["success"] == true
      test_todo = hd(result["data"])
      assert test_todo["summary"]["viewCount"] == 42
      assert test_todo["summary"]["editCount"] == 7
      assert Map.has_key?(test_todo["self"], "title")
      assert Map.has_key?(test_todo["self"], "completed")
    end
  end

  describe "resource-returning calculation without arguments (load-through)" do
    defp creator_todos do
      creator =
        user(
          name: "Creator User",
          email: "creator-loadthrough@example.com",
          todos: [todo(title: "Load Through Todo")]
        )

      [todo(title: "Load Through Todo", creator: creator)]
    end

    test "loads basic fields from resource-returning calculation" do
      result = list(["title", %{"creator" => ["name", "email"]}], creator_todos())
      assert result["success"] == true
      test_todo = Enum.find(result["data"], &(&1["title"] == "Load Through Todo"))
      creator = test_todo["creator"]
      assert creator["name"] == "Creator User"
      assert creator["email"] == "creator-loadthrough@example.com"
      refute Map.has_key?(creator, "id")
    end

    test "loads nested relationships through resource-returning calculation" do
      result =
        list(["id", %{"creator" => ["name", %{"todos" => ["id", "title"]}]}], creator_todos())

      assert result["success"] == true
      creator = hd(result["data"])["creator"]
      assert creator["name"] == "Creator User"
      assert is_list(creator["todos"])
      assert Enum.any?(creator["todos"], fn t -> t["title"] == "Load Through Todo" end)
    end

    test "rejects simple atom selection for resource-returning calculation" do
      error = first_error(refuse(["id", "creator"]))
      assert error["type"] == "requires_field_selection"
    end
  end
end
