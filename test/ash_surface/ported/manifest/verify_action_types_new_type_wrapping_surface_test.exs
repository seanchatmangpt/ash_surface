defmodule AshSurface.Ported.Manifest.VerifyActionTypes.NewTypeWrappingTest do
  use ExUnit.Case, async: false

  import AshSurface.Ported.VerifyActionTypesHelper, only: [verify: 1]

  describe "verify/1 - NewType wrapping Map, Keyword, and Tuple types" do
    test "detects invalid field names in NewType wrapping Map" do
      # Define a NewType that wraps Ash.Type.Map with invalid field names
      defmodule MapNewTypeInvalidFields do
        use Ash.Type.NewType,
          subtype_of: :map,
          constraints: [
            fields: [
              field_1: [type: :string],
              is_valid?: [type: :boolean],
              count: [type: :integer]
            ]
          ]
      end

      defmodule TestResourceMapNewType do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Simple,
          extensions: [AshSurface.Resource]

        surface do
          type_name("TestResourceMapNewType")
        end

        attributes do
          uuid_primary_key(:id)
        end

        actions do
          action :get_data, MapNewTypeInvalidFields do
            run(fn _input, _context ->
              {:ok, %{field_1: "test", is_valid?: true, count: 5}}
            end)
          end
        end
      end

      result = verify([TestResourceMapNewType])

      assert {:error, error_message} = result
      assert error_message =~ ~r/Invalid field names found in action return types/
      assert error_message =~ "field_1"
      assert error_message =~ "is_valid?"
    end

    test "detects invalid field names in NewType wrapping Keyword" do
      defmodule KeywordNewTypeInvalidFields do
        use Ash.Type.NewType,
          subtype_of: :keyword,
          constraints: [
            fields: [
              setting_1: [type: :string],
              enabled?: [type: :boolean],
              priority: [type: :integer]
            ]
          ]
      end

      defmodule TestResourceKeywordNewType do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Simple,
          extensions: [AshSurface.Resource]

        surface do
          type_name("TestResourceKeywordNewType")
        end

        attributes do
          uuid_primary_key(:id)
        end

        actions do
          action :get_settings, KeywordNewTypeInvalidFields do
            run(fn _input, _context ->
              {:ok, [setting_1: "value", enabled?: true, priority: 1]}
            end)
          end
        end
      end

      result = verify([TestResourceKeywordNewType])

      assert {:error, error_message} = result
      assert error_message =~ ~r/Invalid field names found in action return types/
      assert error_message =~ "setting_1"
      assert error_message =~ "enabled?"
    end

    test "detects invalid field names in NewType wrapping Tuple" do
      defmodule TupleNewTypeInvalidFields do
        use Ash.Type.NewType,
          subtype_of: :tuple,
          constraints: [
            fields: [
              coord_1: [type: :float],
              coord_2: [type: :float],
              is_valid?: [type: :boolean]
            ]
          ]
      end

      defmodule TestResourceTupleNewType do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Simple,
          extensions: [AshSurface.Resource]

        surface do
          type_name("TestResourceTupleNewType")
        end

        attributes do
          uuid_primary_key(:id)
        end

        actions do
          action :get_coords, TupleNewTypeInvalidFields do
            run(fn _input, _context ->
              {:ok, {1.0, 2.0, true}}
            end)
          end
        end
      end

      result = verify([TestResourceTupleNewType])

      assert {:error, error_message} = result
      assert error_message =~ ~r/Invalid field names found in action return types/
      assert error_message =~ "coord_1"
      assert error_message =~ "coord_2"
      assert error_message =~ "is_valid?"
    end

    test "passes when NewType wrapping Map has typescript_field_names mappings" do
      defmodule MapNewTypeWithMappings do
        use Ash.Type.NewType,
          subtype_of: :map,
          constraints: [
            fields: [
              field_1: [type: :string],
              is_valid?: [type: :boolean],
              count: [type: :integer]
            ]
          ]

        def typescript_field_names do
          [
            field_1: "field1",
            is_valid?: "isValid"
          ]
        end
      end

      defmodule TestResourceMapNewTypeWithMappings do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Simple,
          extensions: [AshSurface.Resource]

        surface do
          type_name("TestResourceMapNewTypeWithMappings")
        end

        attributes do
          uuid_primary_key(:id)
        end

        actions do
          action :get_data, MapNewTypeWithMappings do
            run(fn _input, _context ->
              {:ok, %{field_1: "test", is_valid?: true, count: 5}}
            end)
          end
        end
      end

      result =
        verify([TestResourceMapNewTypeWithMappings])

      assert result == :ok
    end

    test "passes when NewType wrapping Keyword has typescript_field_names mappings" do
      defmodule KeywordNewTypeWithMappings do
        use Ash.Type.NewType,
          subtype_of: :keyword,
          constraints: [
            fields: [
              setting_1: [type: :string],
              enabled?: [type: :boolean],
              priority: [type: :integer]
            ]
          ]

        def typescript_field_names do
          [
            setting_1: :setting1,
            enabled?: :enabled
          ]
        end
      end

      defmodule TestResourceKeywordNewTypeWithMappings do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Simple,
          extensions: [AshSurface.Resource]

        surface do
          type_name("TestResourceKeywordNewTypeWithMappings")
        end

        attributes do
          uuid_primary_key(:id)
        end

        actions do
          action :get_settings, KeywordNewTypeWithMappings do
            run(fn _input, _context ->
              {:ok, [setting_1: "value", enabled?: true, priority: 1]}
            end)
          end
        end
      end

      result =
        verify([TestResourceKeywordNewTypeWithMappings])

      assert result == :ok
    end

    test "passes when NewType wrapping Tuple has typescript_field_names mappings" do
      defmodule TupleNewTypeWithMappings do
        use Ash.Type.NewType,
          subtype_of: :tuple,
          constraints: [
            fields: [
              coord_1: [type: :float],
              coord_2: [type: :float],
              is_valid?: [type: :boolean]
            ]
          ]

        def typescript_field_names do
          [
            coord_1: :coord1,
            coord_2: :coord2,
            is_valid?: :isValid
          ]
        end
      end

      defmodule TestResourceTupleNewTypeWithMappings do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Simple,
          extensions: [AshSurface.Resource]

        surface do
          type_name("TestResourceTupleNewTypeWithMappings")
        end

        attributes do
          uuid_primary_key(:id)
        end

        actions do
          action :get_coords, TupleNewTypeWithMappings do
            run(fn _input, _context ->
              {:ok, {1.0, 2.0, true}}
            end)
          end
        end
      end

      result =
        verify([TestResourceTupleNewTypeWithMappings])

      assert result == :ok
    end

    test "detects invalid field names in NewType used as argument type" do
      defmodule MapNewTypeForArgument do
        use Ash.Type.NewType,
          subtype_of: :map,
          constraints: [
            fields: [
              value_1: [type: :string],
              active?: [type: :boolean]
            ]
          ]
      end

      defmodule TestResourceNewTypeArgument do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Simple,
          extensions: [AshSurface.Resource]

        surface do
          type_name("TestResourceNewTypeArgument")
        end

        attributes do
          uuid_primary_key(:id)
        end

        actions do
          action :process_data, :boolean do
            argument(:data, MapNewTypeForArgument)

            run(fn _input, _context ->
              {:ok, true}
            end)
          end
        end
      end

      result = verify([TestResourceNewTypeArgument])

      assert {:error, error_message} = result
      assert error_message =~ ~r/Invalid field names found in action return types or argument/
      assert error_message =~ "value_1"
      assert error_message =~ "active?"
    end

    test "detects invalid field names in array of NewType" do
      defmodule MapNewTypeForArray do
        use Ash.Type.NewType,
          subtype_of: :map,
          constraints: [
            fields: [
              item_1: [type: :string],
              is_done?: [type: :boolean]
            ]
          ]
      end

      defmodule TestResourceArrayNewType do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Simple,
          extensions: [AshSurface.Resource]

        surface do
          type_name("TestResourceArrayNewType")
        end

        attributes do
          uuid_primary_key(:id)
        end

        actions do
          action :list_items, {:array, MapNewTypeForArray} do
            run(fn _input, _context ->
              {:ok, [%{item_1: "test", is_done?: false}]}
            end)
          end
        end
      end

      result = verify([TestResourceArrayNewType])

      assert {:error, error_message} = result
      assert error_message =~ ~r/Invalid field names found in action return types/
      assert error_message =~ "item_1"
      assert error_message =~ "is_done?"
    end

    test "detects invalid field names in nested NewTypes within union" do
      defmodule NestedMapNewType do
        use Ash.Type.NewType,
          subtype_of: :map,
          constraints: [
            fields: [
              nested_1: [type: :string],
              has_value?: [type: :boolean]
            ]
          ]
      end

      defmodule TestResourceUnionWithNewType do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Simple,
          extensions: [AshSurface.Resource]

        surface do
          type_name("TestResourceUnionWithNewType")
        end

        attributes do
          uuid_primary_key(:id)
        end

        actions do
          action :get_result, :union do
            constraints(
              types: [
                success: [
                  type: NestedMapNewType
                ],
                error: [
                  type: :map,
                  constraints: [
                    fields: [
                      error_code: [type: :integer]
                    ]
                  ]
                ]
              ]
            )

            run(fn _input, _context ->
              {:ok, %{nested_1: "success", has_value?: true}}
            end)
          end
        end
      end

      result = verify([TestResourceUnionWithNewType])

      assert {:error, error_message} = result
      assert error_message =~ ~r/Invalid field names found in action return types/
      assert error_message =~ "nested_1"
      assert error_message =~ "has_value?"
    end
  end
end
