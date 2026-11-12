defmodule AshSurface.Compiler.QuerySchemaTest do
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.QuerySchema
  alias AshSurface.Projectors.JS.ZodGuard

  defp admitted!(zod), do: assert({:ok, :expression, ^zod} = ZodGuard.admit(zod))

  test "offset only, required, no count" do
    {:ok, z} = QuerySchema.render_pagination_schema(%{offset?: true, required?: true})
    admitted!(z)
    assert z =~ "offset:"
    refute z =~ "count"
    refute z =~ "after"
    refute String.ends_with?(z, ".optional()")
  end

  test "keyset with count, optional" do
    {:ok, z} = QuerySchema.render_pagination_schema(%{keyset?: true, countable?: true})
    admitted!(z)
    assert z =~ "after:" and z =~ "before:" and z =~ "count:"
    assert String.ends_with?(z, ".optional()")
  end

  test "mixed is a union" do
    {:ok, z} = QuerySchema.render_pagination_schema(%{offset?: true, keyset?: true})
    admitted!(z)
    assert String.starts_with?(z, "z.union([")
  end

  test "no pagination support errors" do
    assert {:error, :pagination_unsupported} = QuerySchema.render_pagination_schema(%{})
  end

  test "sort uses sortable fields only" do
    {:ok, z} =
      QuerySchema.render_sort_schema_from_fields([
        %{name: "title", sortable?: true},
        %{"name" => "body", "sortable?" => false},
        %{name: "age", sortable?: true}
      ])

    admitted!(z)
    assert z =~ "age|title"
    refute z =~ "body"
  end

  test "sort with none sortable" do
    assert {:error, :sort_fields_empty} =
             QuerySchema.render_sort_schema_from_fields([%{name: "x", sortable?: false}])
  end

  test "get input and nullable result" do
    {:ok, i} = QuerySchema.render_get_input_schema([{"id", "z.uuid()"}])
    admitted!(i)
    assert i == "z.object({id: z.uuid()}).strict()"

    assert {:error, {:get_key_invalid, _}} =
             QuerySchema.render_get_input_schema([{"a-b", "z.any()"}])

    {:ok, r} = QuerySchema.render_get_result_schema("z.object({}).strict()", nullable?: true)
    admitted!(r)
    assert String.ends_with?(r, ".nullable()")
  end
end
