defmodule AshSurface.Ported.Codegen.AggregateCalculationSupportTest do
  @moduledoc """
  Adaptation of ash_typescript `codegen/aggregate_calculation_support_test.exs`.

  Aggregates can reference a calculation on the related resource instead of an attribute.
  The reference asserts the generated filter TypeScript and the generated resource schema
  text (`totalWeightedScore?: {eq?: number ...}`, `weightedScores?: number[]`). ash_surface
  emits Zod, so the same two claims are asserted as (a) the aggregate facts the IR carries
  (`ResourceFacts`: kind `integer`, list element `integer`), and (b) the filter envelope
  `FilterSchema` renders from those facts, executed under node with real zod: numeric
  operators on the aggregate field accept numbers and reject strings.

  Test resources (inline, real Ash): Todo has `sum`/`max`/`first`/`list` aggregates over the
  `:weighted_score` integer calculation on TodoComment.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.{FilterSchema, ResourceFacts}

  defmodule TodoComment do
    use Ash.Resource,
      domain: nil,
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    ets do
      private?(true)
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:todo_id, :uuid, public?: true)
      attribute(:like_count, :integer, public?: true)
    end

    calculations do
      calculate(:weighted_score, :integer, expr(like_count * 2), public?: true)
    end

    actions do
      defaults([:read])
    end
  end

  defmodule Todo do
    use Ash.Resource,
      domain: nil,
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    ets do
      private?(true)
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:title, :string, public?: true)
    end

    relationships do
      has_many :comments, AshSurface.Ported.Codegen.AggregateCalculationSupportTest.TodoComment do
        destination_attribute(:todo_id)
        public?(true)
      end
    end

    aggregates do
      sum(:total_weighted_score, :comments, :weighted_score, public?: true)
      max(:max_weighted_score, :comments, :weighted_score, public?: true)
      first(:first_weighted_score, :comments, :weighted_score, public?: true)
      list(:weighted_scores, :comments, :weighted_score, public?: true)
    end

    actions do
      defaults([:read])
    end
  end

  setup_all do
    facts = AshSurface.Ported.AshNames.facts(Todo, Ash.Resource.Info.action(Todo, :read))
    {:ok, zod} = FilterSchema.render_filter_schema(facts.filter_entries)
    %{facts: facts, zod: zod}
  end

  defp node_parse(zod, value) do
    js =
      "import {z} from 'zod'; const s = #{zod}; " <>
        "const r = s.safeParse(JSON.parse(process.argv[1])); process.stdout.write(String(r.success));"

    {out, 0} =
      System.cmd("node", ["--input-type=module", "-e", js, Jason.encode!(value)],
        cd: File.cwd!(),
        stderr_to_stdout: true
      )

    out == "true"
  end

  describe "filter envelope - sum aggregate over calculations" do
    test "generates filter type for sum aggregate over calculation", %{facts: facts, zod: zod} do
      entry = Enum.find(facts.filter_entries, &(&1["name"] == "total_weighted_score"))
      assert entry["type"]["kind"] == "integer"

      # eq / greater-than style operators, numeric values (reference: eq?: number, greaterThan?: number)
      assert node_parse(zod, %{field: "total_weighted_score", op: "eq", value: 4})
      assert node_parse(zod, %{field: "total_weighted_score", op: "gt", value: 4})
      refute node_parse(zod, %{field: "total_weighted_score", op: "eq", value: "4"})
      refute node_parse(zod, %{field: "total_weighted_score", op: "contains", value: "4"})
    end
  end

  describe "resource facts - aggregates over calculations resolve the calculation's type" do
    test "sum aggregate over calculation has correct type", %{facts: facts} do
      assert %{kind: :sum, field: "weighted_score", field_kind: "integer"} =
               Enum.find(facts.aggregates, &(&1.name == "total_weighted_score"))
    end

    test "max aggregate over calculation has correct type", %{facts: facts} do
      assert %{kind: :max, field_kind: "integer"} =
               Enum.find(facts.aggregates, &(&1.name == "max_weighted_score"))

      entry = Enum.find(facts.filter_entries, &(&1["name"] == "max_weighted_score"))
      assert entry["type"]["kind"] == "integer"
    end

    test "first aggregate over calculation has correct type", %{facts: facts} do
      assert %{kind: :first, field_kind: "integer"} =
               Enum.find(facts.aggregates, &(&1.name == "first_weighted_score"))

      entry = Enum.find(facts.filter_entries, &(&1["name"] == "first_weighted_score"))
      assert entry["type"]["kind"] == "integer"
    end

    test "list aggregate over calculation has correct type", %{facts: facts, zod: zod} do
      # a list aggregate is an array of the calculation's type (reference: number[])
      assert %{kind: :list, field_kind: "integer"} =
               Enum.find(facts.aggregates, &(&1.name == "weighted_scores"))

      entry = Enum.find(facts.filter_entries, &(&1["name"] == "weighted_scores"))
      assert entry["type"]["kind"] == "array"
      assert entry["items"]["kind"] == "integer"

      # array filter operators over the list aggregate take integer elements
      assert node_parse(zod, %{field: "weighted_scores", op: "has", value: 3})
      refute node_parse(zod, %{field: "weighted_scores", op: "has", value: "3"})
    end
  end
end
