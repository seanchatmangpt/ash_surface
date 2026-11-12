defmodule AshSurface.Ported.Manifest.VerifyActionTypes.ResourceReturnTypesTest do
  use ExUnit.Case, async: false

  import AshSurface.Ported.VerifyActionTypesHelper, only: [verify: 1]

  describe "verify/1 - regular Ash resource return types" do
    test "detects invalid field names in regular Ash resource returned by generic action" do
      # Referenced resource without AshTypescript.Resource extension
      # to avoid resource-level verifier catching the invalid names first
      defmodule ReferencedResourceNoExt do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Simple

        attributes do
          uuid_primary_key(:id)
          attribute(:field_1, :string, public?: true)
          attribute(:is_valid?, :boolean, public?: true)
        end

        actions do
          defaults([:read])
        end
      end

      defmodule TestResourceReturnsResource do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Simple,
          extensions: [AshSurface.Resource]

        surface do
          type_name("TestResourceReturnsResource")
        end

        attributes do
          uuid_primary_key(:id)
        end

        actions do
          action :get_referenced, :struct do
            constraints(instance_of: ReferencedResourceNoExt)

            run(fn _input, _context ->
              {:ok,
               %ReferencedResourceNoExt{id: Ash.UUID.generate(), field_1: "test", is_valid?: true}}
            end)
          end
        end
      end

      result = verify([TestResourceReturnsResource])

      assert {:error, error_message} = result
      assert error_message =~ ~r/Invalid field names found in action return types/
      assert error_message =~ "field_1"
      assert error_message =~ "is_valid?"
    end

    test "passes when regular Ash resource has field_names mappings" do
      defmodule ReferencedResourceWithMappings do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Simple,
          extensions: [AshSurface.Resource]

        surface do
          type_name("ReferencedResourceWithMappings")
          field_names(field_1: "field1", is_valid?: "isValid")
        end

        attributes do
          uuid_primary_key(:id)
          attribute(:field_1, :string, public?: true)
          attribute(:is_valid?, :boolean, public?: true)
        end

        actions do
          defaults([:read])
        end
      end

      defmodule TestResourceReturnsResourceWithMappings do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Simple,
          extensions: [AshSurface.Resource]

        surface do
          type_name("TestResourceReturnsResourceWithMappings")
        end

        attributes do
          uuid_primary_key(:id)
        end

        actions do
          action :get_referenced, :struct do
            constraints(instance_of: ReferencedResourceWithMappings)

            run(fn _input, _context ->
              {:ok,
               %ReferencedResourceWithMappings{
                 id: Ash.UUID.generate(),
                 field_1: "test",
                 is_valid?: true
               }}
            end)
          end
        end
      end

      result =
        verify([TestResourceReturnsResourceWithMappings])

      assert result == :ok
    end

    test "detects invalid field names in array of regular Ash resources" do
      # Referenced resource without AshTypescript.Resource extension
      defmodule ReferencedResourceForArrayNoExt do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Simple

        attributes do
          uuid_primary_key(:id)
          attribute(:item_1, :string, public?: true)
        end

        actions do
          defaults([:read])
        end
      end

      defmodule TestResourceReturnsArrayOfResources do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Simple,
          extensions: [AshSurface.Resource]

        surface do
          type_name("TestResourceReturnsArrayOfResources")
        end

        attributes do
          uuid_primary_key(:id)
        end

        actions do
          action :list_referenced, {:array, :struct} do
            constraints(items: [instance_of: ReferencedResourceForArrayNoExt])

            run(fn _input, _context ->
              {:ok, [%ReferencedResourceForArrayNoExt{id: Ash.UUID.generate(), item_1: "test"}]}
            end)
          end
        end
      end

      result =
        verify([TestResourceReturnsArrayOfResources])

      assert {:error, error_message} = result
      assert error_message =~ ~r/Invalid field names found in action return types/
      assert error_message =~ "item_1"
    end
  end
end
