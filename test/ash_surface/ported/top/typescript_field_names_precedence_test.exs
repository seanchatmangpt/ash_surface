Code.require_file("support/t2.exs", __DIR__)

defmodule AshSurface.Ported.Top.TypescriptFieldNamesPrecedenceTest do
  @moduledoc """
  Adaptation of ash_typescript `typescript_field_names_precedence_test.exs`: a type-level
  `typescript_field_names` mapping is the exact client name of a field under every output
  formatter; the formatter applies only to fields without a mapping.

  Fixtures: `TaskStats` maps `completed?` -> "completed" and `is_urgent?` -> "isUrgent";
  `CustomMetadata` maps every field; `InputParsing.Stats` maps `total_count_1` and `is_complete?`
  but not `last_updated_at`.

  Counterparts: generated TS types -> the Zod object keys the compiler emits for the typed maps
  (mapped names verbatim, asserted under node); RPC run_action -> the projection-side field
  selection/parse (`FieldName`, `RuntimeParity.FieldSelection`) that resolves client names against
  the admitted set. The explicitly configured formatter is applied to UNMAPPED emitted keys and
  never to mapped ones (executed below under `T2.with_env`). Valibot output, typed controller
  result types and the RPC envelope have no counterpart: loud skips in
  `typescript_field_names_precedence_gap_test.exs`.
  """
  use ExUnit.Case, async: false

  alias AshSurface.FieldName
  alias AshSurface.Ported.{CustomMetadata, InputParsing, T2, TaskStats}
  alias AshSurface.RuntimeParity.FieldSelection

  @task_stats_overrides %{completed?: "completed", is_urgent?: "isUrgent"}
  @stats_overrides %{total_count_1: "totalCount1", is_complete?: "isComplete"}
  @custom_overrides %{field_1: "field1", is_active?: "isActive", line_2: "line2"}

  for {formatter, total_count, last_updated_at} <- [
        {:pascal_case, "TotalCount", "LastUpdatedAt"},
        {:snake_case, "total_count", "last_updated_at"}
      ] do
    describe "with output_field_formatter #{inspect(formatter)}" do
      @formatter formatter
      @total_count total_count
      @last_updated_at last_updated_at

      test "typed map names use mappings as-is and format only unmapped fields" do
        # TaskStats: mapped fields as-is, the unmapped `total_count` formatted
        assert FieldName.format_field_for_client(:total_count, TaskStats, @formatter) ==
                 @total_count

        assert FieldName.format_field_for_client(:completed?, TaskStats, @formatter) ==
                 "completed"

        assert FieldName.format_field_for_client(:is_urgent?, TaskStats, @formatter) == "isUrgent"

        # CustomMetadata maps every field
        assert FieldName.format_field_for_client(:field_1, CustomMetadata, @formatter) == "field1"

        assert FieldName.format_field_for_client(:is_active?, CustomMetadata, @formatter) ==
                 "isActive"

        assert FieldName.format_field_for_client(:line_2, CustomMetadata, @formatter) == "line2"

        # the same precedence through the override map the projection hands the formatter
        assert FieldName.format(:completed?, @formatter, @task_stats_overrides) == "completed"
        assert FieldName.format(:total_count, @formatter, @task_stats_overrides) == @total_count
      end

      test "emitted typed-map Zod keys carry the mapped names verbatim" do
        task_stats = T2.zod_full(TaskStats)
        assert task_stats =~ "completed: z.boolean()"
        assert task_stats =~ "isUrgent: z.boolean()"
        refute task_stats =~ ~s("completed?")
        refute task_stats =~ ~s("is_urgent?")

        custom = T2.zod_full(CustomMetadata)
        assert custom =~ "field1: z.string()"
        assert custom =~ "isActive: z.boolean()"
        assert custom =~ "line2: z.string()"
        refute custom =~ "field_1"
        refute custom =~ ~s("is_active?")

        assert {:ok, oks} =
                 T2.node_eval(custom, [
                   %{"field1" => "a", "isActive" => true, "line2" => nil},
                   %{"field1" => "a", "isActive" => true},
                   %{"field_1" => "a", "is_active?" => true}
                 ])

        assert oks == [true, true, false]
      end

      test "emitted types format only unmapped fields under the configured formatter" do
        T2.with_env(:output_field_formatter, @formatter, fn ->
          task_stats = T2.zod_full(TaskStats)
          assert task_stats =~ ~r/(^|[ {])#{@total_count}: z\./
          assert task_stats =~ "completed: z.boolean()"
          assert task_stats =~ "isUrgent: z.boolean()"

          stats = T2.zod_full(InputParsing.Stats)
          assert stats =~ ~r/(^|[ {])#{@last_updated_at}: z\./
          assert stats =~ "totalCount1:"
          assert stats =~ "isComplete:"

          # the formatted key is the one the schema accepts under real zod
          assert {:ok, [true, false]} =
                   T2.node_eval(stats, [
                     %{"totalCount1" => 5, "isComplete" => true, @last_updated_at => nil},
                     %{"totalCount1" => 5, "isComplete" => true, "other_spelling" => 1}
                   ])
        end)
      end

      test "typed map input names use mappings as-is" do
        assert FieldName.format_field_for_client(:total_count_1, InputParsing.Stats, @formatter) ==
                 "totalCount1"

        assert FieldName.format_field_for_client(:is_complete?, InputParsing.Stats, @formatter) ==
                 "isComplete"

        assert FieldName.format_field_for_client(:last_updated_at, InputParsing.Stats, @formatter) ==
                 @last_updated_at
      end

      test "validation schemas use mappings as-is" do
        stats = T2.zod_full(InputParsing.Stats)

        # InputParsing.Stats maps `total_count_1` and `is_complete?`
        assert stats =~ "totalCount1:"
        assert stats =~ "isComplete:"
        refute stats =~ ~r/\bTotalCount1:|\btotal_count_1:|\bIsComplete:|\bis_complete:/

        assert {:ok, [true, false]} =
                 T2.node_eval(stats, [
                   %{"totalCount1" => 5, "isComplete" => true},
                   %{"total_count_1" => 5}
                 ])
      end

      test "nested input keys named as the generated input type resolve to the internal fields" do
        fields = [:total_count_1, :is_complete?, :last_updated_at]
        assert {:ok, parsed} = FieldName.client_to_internal(fields, @formatter, @stats_overrides)

        assert parsed["totalCount1"] == :total_count_1
        assert parsed["isComplete"] == :is_complete?
        assert parsed[@last_updated_at] == :last_updated_at

        # the formatter-spelled name of a MAPPED field is not an accepted alias
        refute Map.has_key?(parsed, FieldName.compute(:total_count_1, @formatter)) and
                 FieldName.compute(:total_count_1, @formatter) != "totalCount1"
      end

      test "field selection accepts and resolves the generated names" do
        admitted = [:total_count, :completed?, :is_urgent?, :average_duration]

        assert {:ok, [:total_count, :completed?, :is_urgent?]} =
                 FieldSelection.select(
                   [@total_count, "completed", "isUrgent"],
                   admitted,
                   [],
                   @formatter,
                   @task_stats_overrides
                 )

        # returns: every internal field maps back to the generated client name
        assert Enum.map(admitted, &FieldName.format(&1, @formatter, @task_stats_overrides)) ==
                 [
                   @total_count,
                   "completed",
                   "isUrgent",
                   FieldName.compute(:average_duration, @formatter)
                 ]

        # the internal spelling of a mapped field is refused as unknown
        assert {:error, {:unknown_field, _, _}} =
                 FieldSelection.select(
                   ["is_urgent"],
                   admitted,
                   [],
                   @formatter,
                   @task_stats_overrides
                 )
      end
    end
  end

  test "type-level overrides are what the typed-map definition carries (single source)" do
    for {type, overrides} <- [
          {TaskStats, @task_stats_overrides},
          {InputParsing.Stats, @stats_overrides},
          {CustomMetadata, @custom_overrides}
        ] do
      names = Map.new(type.typescript_field_names())
      assert Map.new(overrides) == names
    end
  end

  describe "FieldName.wire/3 precedence (override > formatter > configured emitted)" do
    test "a type-level override beats an explicit formatter, whatever the formatter" do
      for formatter <- [:camel_case, :snake_case, :pascal_case] do
        assert FieldName.wire(TaskStats, :completed?, formatter: formatter) == "completed"
        assert FieldName.wire(TaskStats, :is_urgent?, formatter: formatter) == "isUrgent"
        assert FieldName.wire(CustomMetadata, :field_1, formatter: formatter) == "field1"
      end

      # without an explicit formatter the override still wins over the configured one
      FieldName.with_formatter(:pascal_case, fn ->
        assert FieldName.wire(TaskStats, :completed?) == "completed"
      end)
    end

    test "an explicit formatter applies to unmapped fields and differs per formatter" do
      assert FieldName.wire(TaskStats, :total_count, formatter: :snake_case) == "total_count"
      assert FieldName.wire(TaskStats, :total_count, formatter: :pascal_case) == "TotalCount"
      assert FieldName.wire(TaskStats, :total_count, formatter: :camel_case) == "totalCount"
    end
  end

  describe "FieldName.emitted/1 applies the configured output formatter" do
    test "default is camel_case, never the bare internal spelling" do
      assert FieldName.emitted(:total_count_1) == "totalCount1"
      assert FieldName.emitted(:is_complete?) == "isComplete?"
      # RBY re-pin: trailing `?` kept (reference helpers.ex:25-30,73; RBS aligned FieldName.clean/1)
      assert FieldName.wire(nil, :last_updated_at) == "lastUpdatedAt"
      assert FieldName.wire(TaskStats, :average_duration) == "averageDuration"
    end

    test "explicit snake and pascal formatters are honoured" do
      FieldName.with_formatter(:snake_case, fn ->
        assert FieldName.emitted(:last_updated_at) == "last_updated_at"
        assert FieldName.emitted("lastUpdated") == "lastUpdated"
        assert FieldName.wire(nil, :last_updated_at) == "last_updated_at"
      end)

      FieldName.with_formatter(:pascal_case, fn ->
        assert FieldName.emitted(:last_updated_at) == "LastUpdatedAt"
        assert FieldName.wire(nil, :last_updated_at) == "LastUpdatedAt"
        assert FieldName.wire(TaskStats, :total_count) == "TotalCount"
      end)

      assert FieldName.emitted(:last_updated_at) == "lastUpdatedAt"
    end
  end
end
