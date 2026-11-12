defmodule AshSurface.Ported.Rpc.C.OutputFieldFormattingSurfaceTest do
  @moduledoc """
  Port of the reference output_field_formatting tests: the output formatter preserves the keys
  of untyped maps and camelCases typed fields. The reference round-trips through a data layer;
  here the caller builds the record (real `Todo` struct) and the pipeline shapes it.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.Rpc, as: R
  alias AshSurface.Ported, as: P

  test "output field formatting preserves string keys from untyped maps" do
    todo =
      struct(P.Todo, %{
        id: "t1",
        title: "Output Test",
        custom_data: %{"preserveThisKey" => "output_value", "and_this_one" => "also_preserved"}
      })

    result =
      R.run(
        %{
          "action" => "get_todo",
          "input" => %{"id" => "t1"},
          "fields" => ["id", "title", "customData"]
        },
        todo
      )

    assert result["success"] == true
    custom_data = result["data"]["customData"]
    assert custom_data["preserveThisKey"] == "output_value"
    assert custom_data["and_this_one"] == "also_preserved"
    refute Map.has_key?(custom_data, "preserve_this_key")
  end

  test "regular typed field formatting still works" do
    todo = struct(P.Todo, %{id: "t1", title: "Test Todo", user_id: "u1"})

    result =
      R.run(
        %{
          "action" => "get_todo",
          "input" => %{"id" => "t1"},
          "fields" => ["id", "title", "userId"]
        },
        todo
      )

    todo_data = result["data"]
    assert Map.has_key?(todo_data, "title")
    assert Map.has_key?(todo_data, "userId")
    assert todo_data["title"] == "Test Todo"
    refute Map.has_key?(todo_data, "user_id")
  end

  defmodule Shout do
    def fmt(name), do: "X_" <> String.upcase(to_string(name))
  end

  # {formatter, exact client spelling of :user_id, of :custom_data}
  @matrix [
    {:camel_case, "userId", "customData"},
    {:snake_case, "user_id", "custom_data"},
    {:pascal_case, "UserId", "CustomData"}
  ]

  for {formatter, user_id, custom_data} <- @matrix do
    @formatter formatter
    @user_id user_id
    @custom_data custom_data

    test "typed keys take the exact #{inspect(formatter)} spelling; untyped map keys are untouched" do
      todo =
        struct(P.Todo, %{
          id: "t1",
          title: "Output Test",
          user_id: "u1",
          custom_data: %{"preserveThisKey" => "v1", "and_this_one" => "v2", "Pascal" => 3}
        })

      c = &AshSurface.FieldName.compute(&1, @formatter)
      {id, title} = {c.(:id), c.(:title)}

      result =
        AshSurface.FieldName.with_formatter(@formatter, fn ->
          R.run(
            %{
              c.(:action) => "get_todo",
              c.(:input) => %{id => "t1"},
              c.(:fields) => [id, title, @user_id, @custom_data]
            },
            todo
          )
        end)

      # the envelope itself is spelled by the formatter too
      assert result[c.(:success)] == true, inspect(result)

      assert result[c.(:data)] == %{
               id => "t1",
               title => "Output Test",
               @user_id => "u1",
               @custom_data => %{"preserveThisKey" => "v1", "and_this_one" => "v2", "Pascal" => 3}
             }
    end
  end

  test "list output formats every record's keys, not just the first" do
    todos = [
      struct(P.Todo, %{id: "a", title: "A", user_id: "u1"}),
      struct(P.Todo, %{id: "b", title: "B", user_id: "u2"})
    ]

    assert %{"success" => true, "data" => data} =
             R.run(%{"action" => "list_todos", "fields" => ["id", "userId"]}, todos)

    assert data == [%{"id" => "a", "userId" => "u1"}, %{"id" => "b", "userId" => "u2"}]
  end

  # A custom `{module, fun}` formatter has no input inverse (`FieldName.parse_input/2` is `:error`
  # by design), so it is exercised on the output side only.
  test "custom {module, fun} formatter spells output keys exactly, at every depth" do
    data = %{user_id: "u1", nested_map: [%{inner_key: 1}], title: "T"}

    assert AshSurface.RuntimeParity.Rpc.FieldFormatter.format_output_field_names(
             data,
             {__MODULE__.Shout, :fmt}
           ) == %{
             "X_USER_ID" => "u1",
             "X_NESTED_MAP" => [%{"X_INNER_KEY" => 1}],
             "X_TITLE" => "T"
           }
  end

  test "ErrorFormatter accepts every formatter shape FieldName accepts" do
    for {f, expected} <- [
          {:camel_case, "userId"},
          {:snake_case, "user_id"},
          {:pascal_case, "UserId"},
          {{__MODULE__.Shout, :fmt}, "X_USER_ID"},
          {&String.reverse/1, "di_resu"}
        ] do
      assert AshSurface.ErrorFormatter.format_name(:user_id, f) == expected
    end
  end
end
