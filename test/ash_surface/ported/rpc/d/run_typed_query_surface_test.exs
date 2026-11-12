defmodule AshSurface.Ported.Rpc.D.RunTypedQuerySurfaceTest do
  @moduledoc """
  Surface port of the one `run_typed_query_test.exs` case that is assertable without a typed-query
  runner or a data layer: a lookup miss yields the client-formatted `typed_query_not_found`
  envelope. The miss is established against the real DSL (`AshSurface.Resource.Projections.typed_query/2`
  over every fixture resource) and formatted by `Pipeline.error_response/1` / `ErrorBuilder`.
  The remaining cases are loud skips in `run_typed_query_gap_test.exs`.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.{Rpc, Todo, TodoComment, User}
  alias AshSurface.RuntimeParity.Rpc.Pipeline

  test "returns client-formatted error for non-existent typed query" do
    Rpc.install()

    assert Enum.all?(
             [Todo, User, TodoComment],
             &is_nil(AshSurface.Resource.Projections.typed_query(&1, :non_existent))
           )

    assert %{"success" => false, "errors" => [error]} =
             Pipeline.error_response({:typed_query_not_found, :non_existent})

    assert error["type"] == "typed_query_not_found"
    assert error["vars"]["typedQueryName"] == "non_existent"
  end

  test "lookup miss carries the requested name, not a placeholder" do
    Rpc.install()

    assert {:error, {:typed_query_not_found, :definitely_missing}} =
             AshSurface.RuntimeParity.Rpc.TypedQuery.lookup(:definitely_missing)

    assert {:error, {:typed_query_not_found, :other_name}} =
             AshSurface.RuntimeParity.Rpc.TypedQuery.lookup("other_name")
  end

  describe "typed query resolution through the real runner" do
    alias AshSurface.Ported.TypedQueryRpc, as: T
    alias AshSurface.RuntimeParity.Rpc.TypedQuery

    test "lookup miss carries the requested name, not a placeholder" do
      T.install()

      assert {:error, {:typed_query_not_found, :no_such_query}} =
               TypedQuery.lookup(:no_such_query)

      assert {:error, {:typed_query_not_found, :other_name}} = TypedQuery.lookup("other_name")
    end

    test "run of an unknown name yields the envelope naming exactly that query" do
      T.install()

      assert %{"success" => false, "errors" => [error]} = T.run(:no_such_query, %{}, [])
      assert error["type"] == "typed_query_not_found"
      assert error["vars"]["typedQueryName"] == "no_such_query"
      assert error["message"] == "Typed query %{typedQueryName} not found"
      assert error["shortMessage"] == "Typed query not found"
    end

    test "lookup hit resolves resource and query for a registered name" do
      T.install()
      assert {:ok, {resource, query}} = TypedQuery.lookup(:list_todos_user_page)
      assert query.name == :list_todos_user_page
      assert query == AshSurface.Resource.Projections.typed_query(resource, :list_todos_user_page)
      assert {:ok, request} = T.parse(:list_todos_user_page, %{})
      assert request.resource == resource
    end
  end
end
