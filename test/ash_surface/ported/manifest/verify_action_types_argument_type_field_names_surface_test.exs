defmodule AshSurface.Ported.Manifest.VerifyActionTypes.ArgumentTypeFieldNamesTest do
  use ExUnit.Case, async: false

  import AshSurface.Ported.VerifyActionTypesHelper, only: [verify: 1]

  describe "verify/1 - argument type field names" do
    test "detects invalid field names in map argument type" do
      defmodule TestResourceMapArg do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Simple,
          extensions: [AshSurface.Resource]

        surface do
          type_name("TestResourceMapArg")
        end

        attributes do
          uuid_primary_key(:id)
        end

        actions do
          action :process_data, :boolean do
            argument :data, :map do
              constraints(
                fields: [
                  field_1: [type: :string],
                  is_valid?: [type: :boolean]
                ]
              )
            end

            run(fn _input, _context ->
              {:ok, true}
            end)
          end
        end
      end

      result = verify([TestResourceMapArg])

      assert {:error, error_message} = result

      assert error_message =~
               ~r/Invalid field names found in action return types or argument types/

      assert error_message =~ "field_1"
      assert error_message =~ "is_valid?"
    end

    test "detects invalid field names in union argument type" do
      defmodule TestResourceUnionArg do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Simple,
          extensions: [AshSurface.Resource]

        surface do
          type_name("TestResourceUnionArg")
        end

        attributes do
          uuid_primary_key(:id)
        end

        actions do
          action :handle_input, :boolean do
            argument :input, :union do
              constraints(
                types: [
                  option_a: [
                    type: :map,
                    constraints: [
                      fields: [
                        value_1: [type: :string]
                      ]
                    ]
                  ]
                ]
              )
            end

            run(fn _input, _context ->
              {:ok, true}
            end)
          end
        end
      end

      result = verify([TestResourceUnionArg])

      assert {:error, error_message} = result

      assert error_message =~
               ~r/Invalid field names found in action return types or argument types/

      assert error_message =~ "value_1"
    end

    test "detects invalid field names in array of maps argument type" do
      defmodule TestResourceArrayMapArg do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Simple,
          extensions: [AshSurface.Resource]

        surface do
          type_name("TestResourceArrayMapArg")
        end

        attributes do
          uuid_primary_key(:id)
        end

        actions do
          action :process_items, :boolean do
            argument :items, {:array, :map} do
              constraints(
                items: [
                  fields: [
                    item_1: [type: :string]
                  ]
                ]
              )
            end

            run(fn _input, _context ->
              {:ok, true}
            end)
          end
        end
      end

      result = verify([TestResourceArrayMapArg])

      assert {:error, error_message} = result

      assert error_message =~
               ~r/Invalid field names found in action return types or argument types/

      assert error_message =~ "item_1"
    end
  end
end
