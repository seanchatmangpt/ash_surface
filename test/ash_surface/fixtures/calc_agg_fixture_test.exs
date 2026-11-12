defmodule AshSurface.Fixtures.CalcAggFixtureTest do
  use ExUnit.Case, async: true
  alias AshSurface.ZodFixtures.CalcAgg.Item

  test "calculations with and without arguments" do
    calcs = Map.new(Ash.Resource.Info.calculations(Item), &{&1.name, &1})
    assert Map.keys(calcs) |> Enum.sort() == [:matched, :padded, :scaled, :shout, :tiered]
    assert calcs.shout.arguments == []
    assert [%{name: :factor, constraints: c}] = calcs.scaled.arguments
    assert c[:min] == 1 and c[:max] == 10
    assert [%{constraints: c}] = calcs.tiered.arguments
    assert c[:one_of] == [:gold, :silver, :bronze]
    assert [%{constraints: c}] = calcs.matched.arguments
    assert {Spark.Regex, :cache, ["^[A-Z]{3}$", _]} = c[:match]
  end

  test "all aggregate kinds present" do
    kinds = Ash.Resource.Info.aggregates(Item) |> Map.new(&{&1.name, &1.kind})

    assert kinds == %{
             line_count: :count,
             total_qty: :sum,
             avg_price: :avg,
             min_price: :min,
             max_price: :max,
             first_label: :first,
             all_labels: :list,
             has_lines: :exists
           }
  end
end
