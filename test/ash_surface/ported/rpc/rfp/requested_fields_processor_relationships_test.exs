defmodule AshSurface.RuntimeParity.RequestedFieldsProcessorRelationshipsTest do
  use ExUnit.Case
  alias AshSurface.Ported.RFP, as: RequestedFieldsProcessor

  describe "single level relationships" do
    test "processes belongs_to relationships" do
      {:ok, {select, load, extraction_template}} =
        RequestedFieldsProcessor.process(
          AshSurface.Ported.Todo,
          :read,
          [
            :id,
            :title,
            %{user: [:id, :name, :email]}
          ]
        )

      assert select == [:id, :title]
      assert load == [{:user, [:id, :name, :email]}]
      assert extraction_template == [:id, :title, user: [:id, :name, :email]]
    end

    test "processes has_many relationships" do
      {:ok, {select, load, extraction_template}} =
        RequestedFieldsProcessor.process(
          AshSurface.Ported.Todo,
          :read,
          [
            :id,
            :title,
            %{comments: [:id, :content, :rating]}
          ]
        )

      assert select == [:id, :title]
      assert load == [{:comments, [:id, :content, :rating]}]
      assert extraction_template == [:id, :title, comments: [:id, :content, :rating]]
    end

    test "processes multiple relationships at same level" do
      {:ok, {select, load, extraction_template}} =
        RequestedFieldsProcessor.process(
          AshSurface.Ported.Todo,
          :read,
          [
            :id,
            :title,
            %{
              user: [:id, :name],
              comments: [:id, :content]
            }
          ]
        )

      assert select == [:id, :title]
      # Multiple relationships at the same level
      assert load == [{:user, [:id, :name]}, {:comments, [:id, :content]}]

      assert extraction_template == [
               :id,
               :title,
               user: [:id, :name],
               comments: [:id, :content]
             ]
    end
  end

  describe "nested relationships" do
    test "handles deeply nested relationships correctly" do
      {:ok, {select, load, extraction_template}} =
        RequestedFieldsProcessor.process(
          AshSurface.Ported.Todo,
          :read,
          [
            :id,
            %{
              user: [
                :id,
                :name,
                %{
                  comments: [:id, :content]
                }
              ]
            }
          ]
        )

      assert select == [:id]
      # Now properly includes nested relationship loads
      assert load == [{:user, [:id, :name, {:comments, [:id, :content]}]}]
      assert extraction_template == [:id, user: [:id, :name, comments: [:id, :content]]]
    end

    test "handles three-level nested relationships" do
      {:ok, {select, load, extraction_template}} =
        RequestedFieldsProcessor.process(
          AshSurface.Ported.User,
          :read,
          [
            :id,
            :name,
            %{
              todos: [
                :id,
                :title,
                %{
                  comments: [
                    :id,
                    :content,
                    %{
                      user: [:id, :name]
                    }
                  ]
                }
              ]
            }
          ]
        )

      assert select == [:id, :name]

      assert load == [
               {:todos, [:id, :title, {:comments, [:id, :content, {:user, [:id, :name]}]}]}
             ]

      assert extraction_template == [
               :id,
               :name,
               todos: [:id, :title, comments: [:id, :content, user: [:id, :name]]]
             ]
    end

    test "handles multiple nested relationships in different branches" do
      {:ok, {select, load, extraction_template}} =
        RequestedFieldsProcessor.process(
          AshSurface.Ported.Todo,
          :read,
          [
            :id,
            :title,
            %{
              user: [
                :id,
                :name,
                %{comments: [:id, :content]}
              ],
              comments: [
                :id,
                :rating,
                %{user: [:id, :email]}
              ]
            }
          ]
        )

      assert select == [:id, :title]

      assert load == [
               {:user, [:id, :name, {:comments, [:id, :content]}]},
               {:comments, [:id, :rating, {:user, [:id, :email]}]}
             ]

      assert extraction_template == [
               :id,
               :title,
               user: [:id, :name, comments: [:id, :content]],
               comments: [:id, :rating, user: [:id, :email]]
             ]
    end
  end

  describe "mixed simple fields and relationships" do
    test "handles mixed simple fields and nested relationships" do
      {:ok, {select, load, extraction_template}} =
        RequestedFieldsProcessor.process(
          AshSurface.Ported.Todo,
          :read,
          [
            :id,
            :title,
            :completed,
            %{
              user: [
                :id,
                :email,
                %{
                  comments: [:id, :content, :rating]
                }
              ]
            },
            :created_at
          ]
        )

      assert select == [:id, :title, :completed, :created_at]
      assert load == [{:user, [:id, :email, {:comments, [:id, :content, :rating]}]}]

      assert extraction_template == [
               :id,
               :title,
               :completed,
               :created_at,
               user: [:id, :email, comments: [:id, :content, :rating]]
             ]
    end

    test "handles loadable fields mixed with relationships" do
      {:ok, {select, load, extraction_template}} =
        RequestedFieldsProcessor.process(
          AshSurface.Ported.Todo,
          :read,
          [
            :id,
            :title,
            # aggregate
            :comment_count,
            %{user: [:id, :name]},
            # calculation
            :is_overdue,
            %{comments: [:id, :content]}
          ]
        )

      assert select == [:id, :title]

      assert load == [
               :comment_count,
               {:user, [:id, :name]},
               :is_overdue,
               {:comments, [:id, :content]}
             ]

      assert extraction_template == [
               :id,
               :title,
               :comment_count,
               :is_overdue,
               user: [:id, :name],
               comments: [:id, :content]
             ]
    end
  end

  describe "relationship validation" do
    test "returns error for invalid relationship field" do
      {:error, error} =
        RequestedFieldsProcessor.process(
          AshSurface.Ported.Todo,
          :read,
          [
            %{user: [:invalid_field]}
          ]
        )

      assert error ==
               {:unknown_field, :invalid_field, AshSurface.Ported.User, [:user]}
    end

    test "returns error for invalid nested relationship" do
      {:error, error} =
        RequestedFieldsProcessor.process(
          AshSurface.Ported.Todo,
          :read,
          [
            %{user: [%{invalid_relationship: [:id]}]}
          ]
        )

      assert error ==
               {:unknown_field, :invalid_relationship, AshSurface.Ported.User, [:user]}
    end

    test "returns error for invalid deeply nested field" do
      {:error, error} =
        RequestedFieldsProcessor.process(
          AshSurface.Ported.Todo,
          :read,
          [
            %{
              user: [
                :id,
                %{
                  comments: [:id, :invalid_field]
                }
              ]
            }
          ]
        )

      assert error ==
               {:unknown_field, :invalid_field, AshSurface.Ported.TodoComment, [:user, :comments]}
    end

    test "validates relationship existence before processing nested fields" do
      {:error, error} =
        RequestedFieldsProcessor.process(
          AshSurface.Ported.Todo,
          :read,
          [
            %{nonexistent_relation: [:id, :name]}
          ]
        )

      assert error ==
               {:unknown_field, :nonexistent_relation, AshSurface.Ported.Todo, []}
    end

    test "rejects relationships requested as simple atoms without field specification" do
      {:error, error} =
        RequestedFieldsProcessor.process(
          AshSurface.Ported.Todo,
          :read,
          [
            :id,
            # This should be rejected - relationships must specify fields
            :user
          ]
        )

      assert error == {:requires_field_selection, :relationship, :user, []}
    end
  end

  describe "edge cases" do
    test "rejects empty relationship field lists" do
      {:error, error} =
        RequestedFieldsProcessor.process(
          AshSurface.Ported.Todo,
          :read,
          [
            :id,
            %{user: []}
          ]
        )

      assert error == {:requires_field_selection, :relationship, :user, []}
    end

    test "handles relationship with only nested relationships (no direct fields)" do
      {:ok, {select, load, extraction_template}} =
        RequestedFieldsProcessor.process(
          AshSurface.Ported.Todo,
          :read,
          [
            :id,
            %{
              user: [
                %{comments: [:id, :content]}
              ]
            }
          ]
        )

      assert select == [:id]
      assert load == [{:user, [{:comments, [:id, :content]}]}]
      assert extraction_template == [:id, user: [comments: [:id, :content]]]
    end
  end

  describe "relationship query options (validate_query_opts!)" do
    defp rel(opts, process_opts \\ []) do
      AshSurface.Ported.RFP.process(
        AshSurface.Ported.Todo,
        :read,
        [%{comments: Map.put(opts, :fields, Map.get(opts, :fields, [:id]))}],
        process_opts
      )
    end

    defp nested_query(result) do
      {:ok, {[], [{:comments, %Ash.Query{} = q}], _template}} = result
      q
    end

    test "filter, sort, page and limit/offset are applied to the nested query" do
      q = nested_query(rel(%{filter: %{content: %{eq: "x"}}}))
      assert q.filter != nil

      q = nested_query(rel(%{sort: "content"}))
      assert [{:content, :asc}] = q.sort

      q = nested_query(rel(%{limit: 1, offset: 2}))
      assert q.limit == 1
      assert q.offset == 2
    end

    test "page opts are parsed onto the nested query for a paginated relationship" do
      q = nested_query(rel(%{page: %{limit: 2}}))
      assert q.page == [limit: 2]
    end

    test "args cannot be combined with query opts" do
      assert rel(%{args: %{a: 1}}) == {:error, {:args_and_query_opts_combined, :comments, []}}
    end

    test "query opts on a to-one relationship are rejected" do
      assert {:error, {:query_opts_on_to_one, :user, []}} =
               AshSurface.Ported.RFP.process(AshSurface.Ported.Todo, :read, [
                 %{user: %{fields: [:id], filter: %{}}}
               ])
    end

    test "query opts on a non-relationship field are rejected" do
      assert {:error, {:query_opts_on_non_relationship, :title, :attribute, []}} =
               AshSurface.Ported.RFP.process(AshSurface.Ported.Todo, :read, [
                 %{title: %{fields: [:id], filter: %{}}}
               ])
    end

    test "page cannot be combined with bare limit/offset" do
      assert rel(%{page: %{limit: 2}, limit: 1}) ==
               {:error, {:page_and_limit_offset_combined, :comments, []}}
    end

    test "empty field selection is rejected" do
      assert rel(%{fields: [], limit: 1}) ==
               {:error, {:requires_field_selection, :relationship, :comments, []}}
    end

    test "gate-combination relationships refuse unsupported options" do
      run = fn rel_name, opts ->
        AshSurface.Ported.RFP.process(AshSurface.Ported.Todo, :read, [
          %{rel_name => Map.put(opts, :fields, [:id])}
        ])
      end

      assert run.(:unfilterable_comments, %{filter: %{content: %{eq: "x"}}}) ==
               {:error, {:filter_not_supported, :unfilterable_comments, :unsupported, []}}

      assert run.(:unsortable_comments, %{sort: "content"}) ==
               {:error, {:sort_not_supported, :unsortable_comments, :unsupported, []}}

      assert run.(:unpaginated_comments, %{page: %{limit: 2}}) ==
               {:error, {:nested_pagination_not_supported, :unpaginated_comments, []}}
    end

    test "disabled filter and sort flags refuse the options" do
      assert rel(%{filter: %{content: %{eq: "x"}}}, enable_filter?: false) ==
               {:error, {:filter_not_supported, :comments, :disabled, []}}

      assert rel(%{sort: "content"}, enable_sort?: false) ==
               {:error, {:sort_not_supported, :comments, :disabled, []}}
    end
  end
end
