defmodule AshSurface.Ported.Top.UnionTypesTest do
  @moduledoc """
  Port of ash_typescript `union_types_test.exs`. Reachability is Ash's own manifest walker
  (a shared dependency, same code under both libraries); the ash_surface-side assertion is that
  the compiler's embedded closure (`TypeFacts.embedded_resources/1`) reaches the same embedded
  resources through union members and array items.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.TypeFacts
  alias AshSurface.Ported.{InputParsing, Todo, TodoContent, TodoMetadata}

  defp reachable(resources) do
    {reachable, _} = Ash.Info.Manifest.Generator.Reachability.find_reachable(resources)
    reachable
  end

  defp attribute_definitions(resource) do
    resource
    |> Ash.Resource.Info.public_attributes()
    |> Enum.map(&TypeFacts.analyze(&1.type, &1.constraints).definition)
  end

  describe "union type support" do
    test "discovers embedded resources from union types" do
      reachable = reachable([Todo])

      assert TodoContent.TextContent in reachable
      assert TodoContent.ChecklistContent in reachable
      assert TodoContent.LinkContent in reachable

      # ash_surface compile closure: the same embedded resources by name
      closure = Todo |> attribute_definitions() |> TypeFacts.embedded_resources()
      assert Map.has_key?(closure, inspect(TodoContent.TextContent))
      assert Map.has_key?(closure, inspect(TodoContent.ChecklistContent))
      assert Map.has_key?(closure, inspect(TodoContent.LinkContent))
    end

    test "identifies union type attributes correctly" do
      embedded_from_todo = Enum.filter(reachable([Todo]), &Ash.Resource.Info.embedded?/1)
      assert length(embedded_from_todo) >= 3

      kinds =
        for attr <- Ash.Resource.Info.public_attributes(Todo), attr.name == :content do
          TypeFacts.analyze(attr.type, attr.constraints).kind
        end

      assert kinds == ["union"]
    end

    test "discovers embedded resources referenced through array attributes" do
      assert TodoMetadata in reachable([Todo])
      assert InputParsing.HistoryEntry in reachable([InputParsing.Resource])

      closure = Todo |> attribute_definitions() |> TypeFacts.embedded_resources()
      assert Map.has_key?(closure, inspect(TodoMetadata))

      history = InputParsing.Resource |> attribute_definitions() |> TypeFacts.embedded_resources()
      assert Map.has_key?(history, inspect(InputParsing.HistoryEntry))
    end
  end
end
