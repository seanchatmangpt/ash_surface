defmodule AshSurface.Ported.Manifest.VerifyActionTypes.ValidFieldNamesTest do
  use ExUnit.Case, async: false

  import AshSurface.Ported.VerifyActionTypesHelper, only: [verify: 1]

  describe "verify/1 - valid field names pass" do
    test "passes for valid field names in return type" do
      defmodule TestResourceValidReturn do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Simple,
          extensions: [AshSurface.Resource]

        surface do
          type_name("TestResourceValidReturn")
        end

        attributes do
          uuid_primary_key(:id)
        end

        actions do
          action :get_valid_data, :map do
            constraints(
              fields: [
                total: [type: :integer],
                completed: [type: :integer],
                is_active: [type: :boolean]
              ]
            )

            run(fn _input, _context ->
              {:ok, %{total: 10, completed: 5, is_active: true}}
            end)
          end
        end
      end

      result = verify([TestResourceValidReturn])

      assert result == :ok
    end

    test "passes for valid field names in argument type" do
      defmodule TestResourceValidArg do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Simple,
          extensions: [AshSurface.Resource]

        surface do
          type_name("TestResourceValidArg")
        end

        attributes do
          uuid_primary_key(:id)
        end

        actions do
          action :process_valid_data, :boolean do
            argument :data, :map do
              constraints(
                fields: [
                  field_name: [type: :string],
                  count: [type: :integer],
                  is_enabled: [type: :boolean]
                ]
              )
            end

            run(fn _input, _context ->
              {:ok, true}
            end)
          end
        end
      end

      result = verify([TestResourceValidArg])

      assert result == :ok
    end

    test "passes for CRUD actions (return type is resource)" do
      defmodule TestResourceCrud do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Simple,
          extensions: [AshSurface.Resource]

        surface do
          type_name("TestResourceCrud")
        end

        attributes do
          uuid_primary_key(:id)
          attribute(:title, :string, public?: true)
        end

        actions do
          defaults([:read, :create])
        end
      end

      result = verify([TestResourceCrud])

      assert result == :ok
    end
  end
end
