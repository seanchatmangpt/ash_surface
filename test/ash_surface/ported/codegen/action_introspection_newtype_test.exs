defmodule AshSurface.Ported.Codegen.ActionIntrospectionNewTypeTest do
  @moduledoc """
  Adaptation of ash_typescript `rpc/codegen/helpers/action_introspection_newtype_test.exs`.

  The reference unit-tests `ActionIntrospection.action_returns_field_selectable_type?/1`,
  which classifies a generic action's return type as `:typed_map`, `:array_of_typed_map` or
  `:unconstrained_map` after unwrapping NewTypes. ash_surface has no such helper: the same
  classification is the `TypeFacts.analyze/2` definition of the action's `returns` type
  (kind `map` with `fields` = typed map; `array` of that = array of typed map; `map` without
  fields = unconstrained map). Each reference test maps to one test here, asserted on real
  generic actions of a real resource instead of hand-built action maps.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.TypeFacts

  defmodule Suggestion do
    use Ash.Type.NewType,
      subtype_of: :map,
      constraints: [
        fields: [
          name: [type: :string, allow_nil?: false],
          category: [type: :string],
          score: [type: :integer]
        ]
      ]
  end

  defmodule Probe do
    use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Simple

    attributes do
      uuid_primary_key(:id)
    end

    actions do
      defaults([:read])

      action :one, AshSurface.Ported.Codegen.ActionIntrospectionNewTypeTest.Suggestion do
        run(fn _input, _ctx -> {:ok, %{name: "n", category: nil, score: 1}} end)
      end

      action :many,
             {:array, AshSurface.Ported.Codegen.ActionIntrospectionNewTypeTest.Suggestion} do
        run(fn _input, _ctx -> {:ok, []} end)
      end

      action :typed_direct, :map do
        constraints(fields: [total: [type: :integer], count: [type: :integer]])
        run(fn _input, _ctx -> {:ok, %{total: 1, count: 1}} end)
      end

      action :untyped_direct, :map do
        run(fn _input, _ctx -> {:ok, %{}} end)
      end
    end
  end

  defp analysis(name) do
    action = Ash.Resource.Info.action(Probe, name)
    TypeFacts.analyze(action.returns, action.constraints)
  end

  defp field_names(%{definition: %{"type" => %{"fields" => fields}}}),
    do: Enum.map(fields, & &1["name"])

  describe "classification of NewType-wrapped map returns" do
    test "single NewType wrapping :map with fields is a typed map" do
      a = analysis(:one)
      assert a.kind == "map"
      assert a.subtype_of == "map"
      assert field_names(a) == ["name", "category", "score"]
    end

    test "array of NewType wrapping :map with fields is an array of typed map" do
      a = analysis(:many)
      assert a.kind == "array"
      assert %{"type" => %{"kind" => "map", "fields" => fields}} = a.definition["type"]["items"]
      assert Enum.map(fields, & &1["name"]) == ["name", "category", "score"]
    end
  end

  describe "existing behavior is preserved" do
    test "non-generic action has no return type (the reference's :not_generic_action)" do
      read = Ash.Resource.Info.action(Probe, :read)
      assert read.type == :read
      assert TypeFacts.analyze(Map.get(read, :returns), []).kind == "unknown"
    end

    test "direct Ash.Type.Map with fields is a typed map" do
      a = analysis(:typed_direct)
      assert a.kind == "map"
      assert field_names(a) == ["total", "count"]
    end

    test "direct Ash.Type.Map without fields is an unconstrained map" do
      a = analysis(:untyped_direct)
      assert a.kind == "map"
      refute Map.has_key?(a.definition["type"], "fields")
    end
  end
end
