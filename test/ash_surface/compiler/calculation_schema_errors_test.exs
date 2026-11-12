defmodule AshSurface.Compiler.CalculationSchemaErrorsTest do
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.CalculationSchema, as: CS
  alias AshSurface.Projectors.JS.ZodGuard

  defp calc(name, args \\ []), do: %{name: name, arguments: args, return_kind: :string}

  test "calculation error branches" do
    assert {:error, :calc_facts_empty} = CS.render_calculation_schema([])
    assert {:error, {:calc_facts_not_a_list, %{}}} = CS.render_calculation_schema(%{})

    assert {:error, {:calc_name_duplicate, "a"}} =
             CS.render_calculation_schema([calc("a"), calc("a")])

    assert {:error, {:calc_name_invalid, ""}} = CS.render_calculation_schema([calc("")])
    assert {:error, {:calc_name_invalid, 1}} = CS.render_calculation_schema([calc(1)])

    dup = [%{name: "x", kind: :string}, %{name: "x", kind: :string}]

    assert {:error, {:arg_name_duplicate, "a", "x"}} =
             CS.render_calculation_schema([calc("a", dup)])

    assert {:error, {:arg_name_invalid, "a", _}} =
             CS.render_calculation_schema([calc("a", [%{name: 1, kind: :string}])])

    assert {:error, {:calc_arguments_not_a_list, "a", :nope}} =
             CS.render_calculation_schema([%{name: "a", arguments: :nope}])

    assert {:error, :calc_facts_empty} = CS.render_calculation_result_schemas([])
    assert {:error, {:calc_facts_not_a_list, 1}} = CS.render_calculation_result_schemas(1)
  end

  test "aggregate error branches" do
    assert {:error, :agg_facts_empty} = CS.render_aggregate_schemas([])
    assert {:error, {:agg_facts_not_a_list, 1}} = CS.render_aggregate_schemas(1)
    assert {:error, {:agg_facts_not_a_list, 1}} = CS.render_aggregate_metadata(1)

    assert {:error, {:agg_name_invalid, ""}} =
             CS.render_aggregate_schemas([%{name: "", kind: :count}])

    assert {:error, {:agg_name_duplicate, "n"}} =
             CS.render_aggregate_schemas([%{name: "n", kind: :count}, %{name: "n", kind: :sum}])

    assert {:error, {:aggregate_kind_unknown, :bogus}} =
             CS.render_aggregate_schemas([%{name: "n", kind: :bogus}])

    assert {:error, {:aggregate_kind_unknown, :bogus}} =
             CS.render_aggregate_metadata([%{name: "n", kind: :bogus}])
  end

  test "ZodGuard refusal is typed, not a crash" do
    # Fragment text smuggled via a refused kind never escapes: names are JSON
    # literals, so the only guard-refusal path is a non-admitted fragment.
    assert {:ok, zod} = CS.render_calculation_schema([calc(~s|a"); evil(|)])
    assert {:ok, _, _} = ZodGuard.admit(zod)
  end
end
