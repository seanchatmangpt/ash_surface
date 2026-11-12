defmodule AshSurface.Ported.Manifest.VerifyActionTypes.ReturnTypeFieldNamesTest do
  use ExUnit.Case, async: false

  import AshSurface.Ported.VerifyActionTypesHelper, only: [verify: 1]

  describe "verify/1 - return type field names" do
    test "detects invalid field names in map return type" do
      defmodule TestResourceMapReturn do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Simple,
          extensions: [AshSurface.Resource]

        surface do
          type_name("TestResourceMapReturn")
        end

        attributes do
          uuid_primary_key(:id)
        end

        actions do
          action :get_data, :map do
            constraints(
              fields: [
                field_1: [type: :string],
                is_valid?: [type: :boolean]
              ]
            )

            run(fn _input, _context ->
              {:ok, %{field_1: "test", is_valid?: true}}
            end)
          end
        end
      end

      result = verify([TestResourceMapReturn])

      assert {:error, error_message} = result
      assert error_message =~ ~r/Invalid field names found in action return types/
      assert error_message =~ "field_1"
      assert error_message =~ "is_valid?"
    end

    test "detects invalid field names in keyword return type" do
      defmodule TestResourceKeywordReturn do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Simple,
          extensions: [AshSurface.Resource]

        surface do
          type_name("TestResourceKeywordReturn")
        end

        attributes do
          uuid_primary_key(:id)
        end

        actions do
          action :get_options, :keyword do
            constraints(
              fields: [
                setting_1: [type: :string],
                enabled?: [type: :boolean]
              ]
            )

            run(fn _input, _context ->
              {:ok, [setting_1: "test", enabled?: true]}
            end)
          end
        end
      end

      result = verify([TestResourceKeywordReturn])

      assert {:error, error_message} = result
      assert error_message =~ ~r/Invalid field names found in action return types/
      assert error_message =~ "setting_1"
      assert error_message =~ "enabled?"
    end

    test "detects invalid field names in tuple return type" do
      defmodule TestResourceTupleReturn do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Simple,
          extensions: [AshSurface.Resource]

        surface do
          type_name("TestResourceTupleReturn")
        end

        attributes do
          uuid_primary_key(:id)
        end

        actions do
          action :get_coords, :tuple do
            constraints(
              fields: [
                value_1: [type: :float],
                value_2: [type: :float]
              ]
            )

            run(fn _input, _context ->
              {:ok, {1.0, 2.0}}
            end)
          end
        end
      end

      result = verify([TestResourceTupleReturn])

      assert {:error, error_message} = result
      assert error_message =~ ~r/Invalid field names found in action return types/
      assert error_message =~ "value_1"
      assert error_message =~ "value_2"
    end

    test "detects invalid field names in union return type members" do
      defmodule TestResourceUnionReturn do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Simple,
          extensions: [AshSurface.Resource]

        surface do
          type_name("TestResourceUnionReturn")
        end

        attributes do
          uuid_primary_key(:id)
        end

        actions do
          action :get_result, :union do
            constraints(
              types: [
                success: [
                  type: :map,
                  constraints: [
                    fields: [
                      result_1: [type: :string]
                    ]
                  ]
                ],
                error: [
                  type: :map,
                  constraints: [
                    fields: [
                      error_code?: [type: :integer]
                    ]
                  ]
                ]
              ]
            )

            run(fn _input, _context ->
              {:ok, %{result_1: "success"}}
            end)
          end
        end
      end

      result = verify([TestResourceUnionReturn])

      assert {:error, error_message} = result
      assert error_message =~ ~r/Invalid field names found in action return types/
      assert error_message =~ "result_1"
      assert error_message =~ "error_code?"
    end

    test "detects invalid field names in array of maps return type" do
      defmodule TestResourceArrayMapReturn do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Simple,
          extensions: [AshSurface.Resource]

        surface do
          type_name("TestResourceArrayMapReturn")
        end

        attributes do
          uuid_primary_key(:id)
        end

        actions do
          action :list_items, {:array, :map} do
            constraints(
              items: [
                fields: [
                  item_1: [type: :string],
                  active?: [type: :boolean]
                ]
              ]
            )

            run(fn _input, _context ->
              {:ok, [%{item_1: "test", active?: true}]}
            end)
          end
        end
      end

      result = verify([TestResourceArrayMapReturn])

      assert {:error, error_message} = result
      assert error_message =~ ~r/Invalid field names found in action return types/
      assert error_message =~ "item_1"
      assert error_message =~ "active?"
    end
  end
end
