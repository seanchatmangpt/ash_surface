Code.require_file("support/t1.exs", __DIR__)

defmodule AshSurface.Ported.Top.NonFieldCalculationTest do
  @moduledoc """
  Adapted from ash_typescript `non_field_calculation_test.exs`: calculations declared with
  `field?: false` are excluded from every generated surface. `.ts` text assertions become real
  Ash facts (`field?`), the compiler's `ResourceFacts` filter/sort entries, the generated Zod
  artifact text, and real node+zod acceptance/rejection of the field in filter and sort schemas.
  """
  use ExUnit.Case, async: true

  # first use compiles the whole ported domain (cached per VM); allow for a loaded machine
  @moduletag timeout: 900_000

  alias AshSurface.Ported.{T1, Todo}

  test "fixture: internal_score is a public calculation with field?: false" do
    calc = Ash.Resource.Info.calculation(Todo, :internal_score)
    assert calc.public? and calc.field? == false
    assert Ash.Resource.Info.calculation(Todo, :is_overdue).field?
  end

  describe "calculations with field?: false" do
    test "are excluded from the resource's create/read input schemas (unified resource schema)" do
      art = T1.artifact!()
      [read] = Regex.run(~r/export const Todo_read_schema = z\.object\(\{.*?\}\)/s, art)
      [create] = Regex.run(~r/export const Todo_create_schema = z\.object\(\{.*?\}\)/s, art)
      refute read =~ "internal_score"
      refute create =~ "internal_score"
    end

    test "are excluded from the primitive (sortable) field set; field calculations stay" do
      facts = AshSurface.Ported.AshNames.facts(Todo, Ash.Resource.Info.action(Todo, :read))
      sortable = Enum.map(facts.sortable_fields, &to_string/1)
      refute "internal_score" in sortable
      assert "filtered_data" in sortable

      assert [false, true] ==
               T1.node_accepts([
                 {"Todo_read_sort_schema", "internal_score"},
                 {"Todo_read_sort_schema", "filtered_data"}
               ])
    end

    test "are excluded from filter types, field calculations stay (real zod)" do
      entries =
        AshSurface.Ported.AshNames.facts(Todo, Ash.Resource.Info.action(Todo, :read)).filter_entries

      names = Enum.map(entries, &(&1["name"] || &1[:name]))
      refute "internal_score" in names
      assert "is_overdue" in names
      assert "days_until_due" in names

      assert [false, true, true] ==
               T1.node_accepts([
                 {"Todo_read_filter_schema", %{field: "internal_score", op: "eq", value: 1}},
                 {"Todo_read_filter_schema", %{field: "is_overdue", op: "eq", value: true}},
                 {"Todo_read_filter_schema", %{field: "days_until_due", op: "gt", value: 0}}
               ])
    end

    test "are excluded from the full generated output" do
      art = T1.artifact!()
      refute art =~ "internal_score"
      assert art =~ "is_overdue"
      assert art =~ "days_until_due"
    end
  end
end
