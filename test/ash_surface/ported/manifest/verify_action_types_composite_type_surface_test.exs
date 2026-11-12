defmodule AshSurface.Ported.Manifest.VerifyActionTypes.CompositeTypeTest do
  use ExUnit.Case, async: false

  import AshSurface.Ported.VerifyActionTypesHelper, only: [verify: 1]

  describe "verify/1 - custom composite Ash.Type" do
    test "detects invalid field names in composite type return" do
      defmodule CompositeTypeWithInvalidFields do
        use Ash.Type

        @impl true
        def storage_type(_), do: :map

        @impl true
        def cast_input(nil, _), do: {:ok, nil}
        def cast_input(value, _) when is_map(value), do: {:ok, value}
        def cast_input(_, _), do: :error

        @impl true
        def cast_stored(nil, _), do: {:ok, nil}
        def cast_stored(value, _) when is_map(value), do: {:ok, value}
        def cast_stored(_, _), do: :error

        @impl true
        def dump_to_native(nil, _), do: {:ok, nil}
        def dump_to_native(value, _) when is_map(value), do: {:ok, value}
        def dump_to_native(_, _), do: :error

        @impl true
        def composite?(_), do: true

        @impl true
        def composite_types(_) do
          [
            {:field_1, :string, []},
            {:is_active?, :boolean, []},
            {:value_2, :integer, []}
          ]
        end
      end

      defmodule TestResourceCompositeReturn do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Simple,
          extensions: [AshSurface.Resource]

        surface do
          type_name("TestResourceCompositeReturn")
        end

        attributes do
          uuid_primary_key(:id)
        end

        actions do
          action :get_composite, CompositeTypeWithInvalidFields do
            run(fn _input, _context ->
              {:ok, %{field_1: "test", is_active?: true, value_2: 42}}
            end)
          end
        end
      end

      result = verify([TestResourceCompositeReturn])

      assert {:error, error_message} = result
      assert error_message =~ ~r/Invalid field names found in action return types/
      assert error_message =~ "field_1"
      assert error_message =~ "is_active?"
      assert error_message =~ "value_2"
    end

    test "accepts composite type with typescript_field_names callback" do
      defmodule CompositeTypeWithMappings do
        use Ash.Type

        def typescript_type_name, do: "CompositeWithMappings"

        @impl true
        def storage_type(_), do: :map

        @impl true
        def cast_input(nil, _), do: {:ok, nil}
        def cast_input(value, _) when is_map(value), do: {:ok, value}
        def cast_input(_, _), do: :error

        @impl true
        def cast_stored(nil, _), do: {:ok, nil}
        def cast_stored(value, _) when is_map(value), do: {:ok, value}
        def cast_stored(_, _), do: :error

        @impl true
        def dump_to_native(nil, _), do: {:ok, nil}
        def dump_to_native(value, _) when is_map(value), do: {:ok, value}
        def dump_to_native(_, _), do: :error

        @impl true
        def composite?(_), do: true

        @impl true
        def composite_types(_) do
          [
            {:field_1, :string, []},
            {:is_active?, :boolean, []}
          ]
        end

        def typescript_field_names do
          [
            field_1: "field1",
            is_active?: "isActive"
          ]
        end
      end

      defmodule TestResourceCompositeWithMappings do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Simple,
          extensions: [AshSurface.Resource]

        surface do
          type_name("TestResourceCompositeWithMappings")
        end

        attributes do
          uuid_primary_key(:id)
        end

        actions do
          action :get_composite, CompositeTypeWithMappings do
            run(fn _input, _context ->
              {:ok, %{field_1: "test", is_active?: true}}
            end)
          end
        end
      end

      result =
        verify([TestResourceCompositeWithMappings])

      assert result == :ok
    end

    test "detects invalid field names in composite type used as argument" do
      defmodule CompositeArgTypeWithInvalidFields do
        use Ash.Type

        @impl true
        def storage_type(_), do: :map

        @impl true
        def cast_input(nil, _), do: {:ok, nil}
        def cast_input(value, _) when is_map(value), do: {:ok, value}
        def cast_input(_, _), do: :error

        @impl true
        def cast_stored(nil, _), do: {:ok, nil}
        def cast_stored(value, _) when is_map(value), do: {:ok, value}
        def cast_stored(_, _), do: :error

        @impl true
        def dump_to_native(nil, _), do: {:ok, nil}
        def dump_to_native(value, _) when is_map(value), do: {:ok, value}
        def dump_to_native(_, _), do: :error

        @impl true
        def composite?(_), do: true

        @impl true
        def composite_types(_) do
          [
            {:arg_1, :string, []},
            {:is_valid?, :boolean, []}
          ]
        end
      end

      defmodule TestResourceCompositeArg do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Simple,
          extensions: [AshSurface.Resource]

        surface do
          type_name("TestResourceCompositeArg")
        end

        attributes do
          uuid_primary_key(:id)
        end

        actions do
          action :process_composite, :boolean do
            argument(:data, CompositeArgTypeWithInvalidFields, allow_nil?: false)

            run(fn _input, _context ->
              {:ok, true}
            end)
          end
        end
      end

      result = verify([TestResourceCompositeArg])

      assert {:error, error_message} = result
      assert error_message =~ ~r/Invalid field names found in action return types/
      assert error_message =~ "arg_1"
      assert error_message =~ "is_valid?"
    end

    test "detects invalid field names in nested composite types" do
      defmodule NestedCompositeType do
        use Ash.Type

        @impl true
        def storage_type(_), do: :map

        @impl true
        def cast_input(nil, _), do: {:ok, nil}
        def cast_input(value, _) when is_map(value), do: {:ok, value}
        def cast_input(_, _), do: :error

        @impl true
        def cast_stored(nil, _), do: {:ok, nil}
        def cast_stored(value, _) when is_map(value), do: {:ok, value}
        def cast_stored(_, _), do: :error

        @impl true
        def dump_to_native(nil, _), do: {:ok, nil}
        def dump_to_native(value, _) when is_map(value), do: {:ok, value}
        def dump_to_native(_, _), do: :error

        @impl true
        def composite?(_), do: true

        @impl true
        def composite_types(_) do
          [
            {:name, :string, []},
            {:nested_data, Ash.Type.Map,
             [
               fields: [
                 inner_1: [type: :string],
                 is_nested?: [type: :boolean]
               ]
             ]}
          ]
        end
      end

      defmodule TestResourceNestedComposite do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Simple,
          extensions: [AshSurface.Resource]

        surface do
          type_name("TestResourceNestedComposite")
        end

        attributes do
          uuid_primary_key(:id)
        end

        actions do
          action :get_nested, NestedCompositeType do
            run(fn _input, _context ->
              {:ok, %{name: "test", nested_data: %{inner_1: "a", is_nested?: true}}}
            end)
          end
        end
      end

      result = verify([TestResourceNestedComposite])

      assert {:error, error_message} = result
      assert error_message =~ ~r/Invalid field names found in action return types/
      # Should detect nested invalid field names
      assert error_message =~ "inner_1"
      assert error_message =~ "is_nested?"
    end
  end
end
