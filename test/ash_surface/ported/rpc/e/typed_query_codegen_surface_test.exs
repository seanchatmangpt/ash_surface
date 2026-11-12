defmodule AshSurface.Ported.Rpc.E.TypedQueryCodegenSurfaceTest do
  @moduledoc """
  Behavioral counterparts of ash_typescript `rpc/typed_query_codegen_test.exs` tests 001-004.
  The reference asserts the text of the generated TypeScript constant
  (`export const listTodosUserPage = [...] satisfies ListTodosFields`). ash_surface generates no
  .ts; what the constant *is* (a plain array of client field names, nested selections as maps,
  no type assertion wrappers) is the typed query's client field request, and the result type
  (`Array<InferResult<...>>`) is the list the runner returns. Both are asserted on the real
  `list_todos_user_page` typed query of the `TqTodo` fixture through the non-actuating runner.
  Tests 005/006 (comment header text, `satisfies` on every constant line) have no behavioral
  counterpart and stay loud skips in `typed_query_codegen_gap_test.exs`.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.TypedQueryRpc, as: T
  alias AshSurface.RuntimeParity.Rpc.TypedQuery

  @name :list_todos_user_page

  defp client_fields do
    T.install()
    assert {:ok, {_resource, query}} = TypedQuery.lookup(@name)
    {query, TypedQuery.client_fields(query.fields)}
  end

  test "001 typed query field constant is a plain field list with no type-assertion wrapper" do
    {query, fields} = client_fields()

    assert query.fields_const_name == "listTodosUserPage"
    assert is_list(fields)
    # plain data: only strings (leaf fields) and string-keyed maps (nested selections)
    assert Enum.all?(fields, &(is_binary(&1) or is_map(&1)))
    assert Enum.all?(fields, fn f -> is_binary(f) or Enum.all?(Map.keys(f), &is_binary/1) end)
  end

  test "002 typed query field constant lists simple fields as plain strings" do
    {_query, fields} = client_fields()

    assert "id" in fields
    assert "title" in fields
    assert "commentCount" in fields
    # every declared leaf round-trips through the pipeline's field validation
    assert {:ok, _request} = T.parse(@name, %{})
  end

  test "003 typed query with nested fields generates the nested structure" do
    {_query, fields} = client_fields()

    assert %{"comments" => ["id", "content"]} in fields
  end

  test "004 typed query result is a list of rows shaped with the declared fields" do
    {query, _fields} = client_fields()
    assert query.result_type_name == "ListTodosUserPageResult"

    result =
      T.run(@name, %{}, [
        T.todo(comment_count: 1, comments: [T.comment(content: "hi")])
      ])

    assert %{"success" => true, "data" => [row]} = result

    assert Enum.sort(Map.keys(row)) ==
             ~w(comments commentCount description id priority title) |> Enum.sort()

    assert row["comments"] == [
             %{"id" => "bbbbbbbb-0000-0000-0000-000000000001", "content" => "hi"}
           ]
  end
end
