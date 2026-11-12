defmodule AshSurface.RuntimeParity.RequestedFieldsProcessorTypedStructsTest do
  use ExUnit.Case
  alias AshSurface.Ported.RFP, as: RequestedFieldsProcessor

  describe "simple typed struct fields" do
    test "processes typed struct attribute fields correctly" do
      {:ok, {select, load, extraction_template}} =
        RequestedFieldsProcessor.process(
          AshSurface.Ported.Todo,
          :read,
          [
            :id,
            :title,
            %{timestamp_info: [:created_by, :created_at, :updated_by]}
          ]
        )

      assert select == [:id, :title, :timestamp_info]
      assert load == []

      assert extraction_template == [
               :id,
               :title,
               timestamp_info: [:created_by, :created_at, :updated_by]
             ]
    end

    test "processes all typed struct fields" do
      {:ok, {select, load, extraction_template}} =
        RequestedFieldsProcessor.process(
          AshSurface.Ported.Todo,
          :read,
          [
            :id,
            %{timestamp_info: [:created_by, :created_at, :updated_by, :updated_at]}
          ]
        )

      assert select == [:id, :timestamp_info]
      assert load == []

      assert extraction_template == [
               :id,
               timestamp_info: [:created_by, :created_at, :updated_by, :updated_at]
             ]
    end

    test "processes statistics typed struct with numeric fields" do
      {:ok, {select, load, extraction_template}} =
        RequestedFieldsProcessor.process(
          AshSurface.Ported.Todo,
          :read,
          [
            :id,
            %{statistics: [:view_count, :edit_count, :completion_time_seconds]}
          ]
        )

      assert select == [:id, :statistics]
      assert load == []

      assert extraction_template == [
               :id,
               statistics: [:view_count, :edit_count, :completion_time_seconds]
             ]
    end

    test "processes statistics typed struct with composite fields" do
      {:ok, {select, load, extraction_template}} =
        RequestedFieldsProcessor.process(
          AshSurface.Ported.Todo,
          :read,
          [
            :id,
            %{statistics: [:view_count, :performance_metrics]}
          ]
        )

      assert select == [:id, :statistics]
      assert load == []
      assert extraction_template == [:id, statistics: [:view_count, :performance_metrics]]
    end

    test "processes mixed typed struct fields with regular attributes" do
      {:ok, {select, load, extraction_template}} =
        RequestedFieldsProcessor.process(
          AshSurface.Ported.Todo,
          :read,
          [
            :id,
            :title,
            %{timestamp_info: [:created_by, :created_at]},
            %{statistics: [:view_count, :edit_count]}
          ]
        )

      assert select == [:id, :title, :timestamp_info, :statistics]
      assert load == []

      assert extraction_template == [
               :id,
               :title,
               timestamp_info: [:created_by, :created_at],
               statistics: [:view_count, :edit_count]
             ]
    end
  end

  describe "typed struct fields with other field types" do
    test "processes typed struct with relationships" do
      {:ok, {select, load, extraction_template}} =
        RequestedFieldsProcessor.process(
          AshSurface.Ported.Todo,
          :read,
          [
            :id,
            %{timestamp_info: [:created_by, :created_at]},
            %{user: [:id, :name]}
          ]
        )

      assert select == [:id, :timestamp_info]
      assert load == [{:user, [:id, :name]}]

      assert extraction_template == [
               :id,
               timestamp_info: [:created_by, :created_at],
               user: [:id, :name]
             ]
    end

    test "processes typed struct with aggregates" do
      {:ok, {select, load, extraction_template}} =
        RequestedFieldsProcessor.process(
          AshSurface.Ported.Todo,
          :read,
          [
            :id,
            %{statistics: [:view_count, :edit_count]},
            :comment_count
          ]
        )

      assert select == [:id, :statistics]
      assert load == [:comment_count]

      assert extraction_template == [
               :id,
               :comment_count,
               statistics: [:view_count, :edit_count]
             ]
    end

    test "processes typed struct with calculations" do
      {:ok, {select, load, extraction_template}} =
        RequestedFieldsProcessor.process(
          AshSurface.Ported.Todo,
          :read,
          [
            :id,
            %{timestamp_info: [:created_by, :updated_by]},
            :is_overdue
          ]
        )

      assert select == [:id, :timestamp_info]
      assert load == [:is_overdue]

      assert extraction_template == [
               :id,
               :is_overdue,
               timestamp_info: [:created_by, :updated_by]
             ]
    end
  end

  describe "error handling for typed structs" do
    test "returns error for invalid typed struct field" do
      {:error, error} =
        RequestedFieldsProcessor.process(
          AshSurface.Ported.Todo,
          :read,
          [
            %{timestamp_info: [:invalid_field]}
          ]
        )

      assert error ==
               {:unknown_field, :invalid_field, "field_constrained_type", [:timestamp_info]}
    end

    test "returns error for invalid nested typed struct field" do
      {:error, error} =
        RequestedFieldsProcessor.process(
          AshSurface.Ported.Todo,
          :read,
          [
            %{statistics: [:view_count, :invalid_field]}
          ]
        )

      assert error == {:unknown_field, :invalid_field, "field_constrained_type", [:statistics]}
    end

    test "returns error for duplicate typed struct fields" do
      {:error, error} =
        RequestedFieldsProcessor.process(
          AshSurface.Ported.Todo,
          :read,
          [
            %{timestamp_info: [:created_by, :created_at, :created_by]}
          ]
        )

      assert error == {:duplicate_field, :created_by, [:timestamp_info]}
    end

    test "returns error when typed struct is requested as simple atom" do
      {:error, error} =
        RequestedFieldsProcessor.process(
          AshSurface.Ported.Todo,
          :read,
          [
            :timestamp_info
          ]
        )

      assert error == {:requires_field_selection, :field_constrained_type, :timestamp_info, []}
    end

    test "returns error when typed struct is requested as empty map" do
      {:error, error} =
        RequestedFieldsProcessor.process(
          AshSurface.Ported.Todo,
          :read,
          [
            %{statistics: []}
          ]
        )

      assert error == {:requires_field_selection, :field_constrained_type, :statistics, []}
    end
  end

  describe "create actions with typed structs" do
    test "processes typed struct fields correctly in create actions" do
      {:ok, {select, load, extraction_template}} =
        RequestedFieldsProcessor.process(
          AshSurface.Ported.Todo,
          :create,
          [
            :id,
            :title,
            %{timestamp_info: [:created_by, :created_at]}
          ]
        )

      assert select == [:id, :title, :timestamp_info]
      assert load == []
      assert extraction_template == [:id, :title, timestamp_info: [:created_by, :created_at]]
    end

    test "processes statistics typed struct in create actions" do
      {:ok, {select, load, extraction_template}} =
        RequestedFieldsProcessor.process(
          AshSurface.Ported.Todo,
          :create,
          [
            :id,
            %{statistics: [:view_count, :performance_metrics]}
          ]
        )

      assert select == [:id, :statistics]
      assert load == []
      assert extraction_template == [:id, statistics: [:view_count, :performance_metrics]]
    end
  end

  describe "update actions with typed structs" do
    test "processes typed struct fields correctly in update actions" do
      {:ok, {select, load, extraction_template}} =
        RequestedFieldsProcessor.process(
          AshSurface.Ported.Todo,
          :update,
          [
            :id,
            :title,
            %{timestamp_info: [:updated_by, :updated_at]},
            %{statistics: [:edit_count]}
          ]
        )

      assert select == [:id, :title, :timestamp_info, :statistics]
      assert load == []

      assert extraction_template == [
               :id,
               :title,
               timestamp_info: [:updated_by, :updated_at],
               statistics: [:edit_count]
             ]
    end
  end

  describe "map field nesting within typed structs" do
    test "allows nested field selection from maps with field constraints" do
      # The statistics typed struct contains performance_metrics which is a map with field constraints
      requested_fields = [
        %{
          statistics: [
            :view_count,
            %{performance_metrics: [:focus_time_seconds, :efficiency_score]}
          ]
        }
      ]

      result =
        RequestedFieldsProcessor.process(
          AshSurface.Ported.Todo,
          :read,
          requested_fields
        )

      assert {:ok, {[:statistics], [], template}} = result

      assert template == [
               {:statistics,
                [
                  :view_count,
                  {:performance_metrics, [:focus_time_seconds, :efficiency_score]}
                ]}
             ]
    end

    test "rejects invalid field names in nested maps within typed structs" do
      requested_fields = [
        %{
          statistics: [
            %{performance_metrics: [:invalid_field]}
          ]
        }
      ]

      result =
        RequestedFieldsProcessor.process(
          AshSurface.Ported.Todo,
          :read,
          requested_fields
        )

      assert {:error,
              {:unknown_field, :invalid_field, "map", [:statistics, :performance_metrics]}} =
               result
    end

    test "validates duplicate field detection in maps within typed structs" do
      requested_fields = [
        %{
          statistics: [
            %{
              performance_metrics: [
                :efficiency_score,
                # duplicate
                :efficiency_score
              ]
            }
          ]
        }
      ]

      result =
        RequestedFieldsProcessor.process(
          AshSurface.Ported.Todo,
          :read,
          requested_fields
        )

      assert {:error, {:duplicate_field, :efficiency_score, [:statistics, :performance_metrics]}} =
               result
    end

    test "supports all valid fields in performance_metrics map" do
      requested_fields = [
        %{
          statistics: [
            %{
              performance_metrics: [
                :focus_time_seconds,
                :interruption_count,
                :efficiency_score,
                :task_complexity
              ]
            }
          ]
        }
      ]

      result =
        RequestedFieldsProcessor.process(
          AshSurface.Ported.Todo,
          :read,
          requested_fields
        )

      assert {:ok, {[:statistics], [], template}} = result

      assert template == [
               {:statistics,
                [
                  {:performance_metrics,
                   [
                     :focus_time_seconds,
                     :interruption_count,
                     :efficiency_score,
                     :task_complexity
                   ]}
                ]}
             ]
    end

    test "handles mixed selection of map fields and regular fields in typed struct" do
      requested_fields = [
        :id,
        %{
          statistics: [
            :view_count,
            :edit_count,
            %{performance_metrics: [:efficiency_score, :task_complexity]},
            :difficulty_rating
          ]
        }
      ]

      result =
        RequestedFieldsProcessor.process(
          AshSurface.Ported.Todo,
          :read,
          requested_fields
        )

      assert {:ok, {[:id, :statistics], [], template}} = result

      assert template == [
               :id,
               {:statistics,
                [
                  :view_count,
                  :edit_count,
                  :difficulty_rating,
                  {:performance_metrics, [:efficiency_score, :task_complexity]}
                ]}
             ]
    end
  end

  describe "select_typed_struct_fields/4 direct (shield-free)" do
    alias AshSurface.RuntimeParity.RequestedFields.{Compat, FieldSelector}

    setup do
      m = AshSurface.Ported.RFP.manifest()
      res = Ash.Info.Manifest.get_resource!(Compat.resource_lookup(m), AshSurface.Ported.Todo)
      type = Ash.Info.Manifest.get_type(Compat.type_lookup(m), res.fields[:statistics].type.module)

      ctx = %{manifest: m, enable_filter?: true, enable_sort?: true, load_restrictions: :none}
      {:ok, type: type, ctx: ctx}
    end

    test "duplicate fields throw duplicate_field", %{type: type, ctx: ctx} do
      assert catch_throw(
               FieldSelector.select_typed_struct_fields(
                 type,
                 [:view_count, :view_count],
                 [:x],
                 ctx
               )
             ) == {:duplicate_field, :view_count, [:x]}
    end

    test "empty selection throws requires_field_selection", %{type: type, ctx: ctx} do
      assert catch_throw(FieldSelector.select_typed_struct_fields(type, [], [:x], ctx)) ==
               {:requires_field_selection, :field_constrained_type, nil}
    end

    test "wire names resolve through the reverse map to internal atoms", %{type: type, ctx: ctx} do
      assert FieldSelector.select_typed_struct_fields(
               type,
               ["allCompleted", :view_count],
               [:x],
               ctx
             ) == {[], [], [:all_completed?, :view_count]}
    end

    test "unmapped string name stays a string and is an unknown field", %{type: type, ctx: ctx} do
      # Runtime-built so the name is never in the atom table regardless of which other
      # tests loaded (reference: String.to_existing_atom, else the string stays).
      bogus = "no_such_field_#{System.unique_integer([:positive])}"

      assert catch_throw(FieldSelector.select_typed_struct_fields(type, [bogus], [:x], ctx)) ==
               {:unknown_field, bogus, "field_constrained_type", [:x]}
    end
  end
end
