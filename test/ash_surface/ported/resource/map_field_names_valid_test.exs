defmodule AshSurface.Ported.Resource.MapFieldNamesValidTest do
  @moduledoc """
  Port of ash_typescript `resource/map_field_names_valid_test.exs`. The reference only
  asserts the module compiles; the port also runs the real verifier path
  (`AshSurface.VerifierChecker`) and requires `:ok`.
  """
  use ExUnit.Case, async: true

  describe "valid field names" do
    test "allows valid field names in map type constraints" do
      defmodule TestResourceWithValidMapFields do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Ets,
          validate_domain_inclusion?: false,
          extensions: [AshSurface.Resource]

        surface do
          type_name("TestResourceWithValidMapFields")
        end

        attributes do
          uuid_primary_key(:id)

          attribute :metadata, :map do
            public?(true)

            constraints(
              fields: [
                field1: [type: :string],
                is_active: [type: :boolean],
                normal_field: [type: :string]
              ]
            )
          end
        end
      end

      assert TestResourceWithValidMapFields

      assert :ok =
               AshSurface.VerifierChecker.check_all_verifiers([TestResourceWithValidMapFields])
    end

    test "allows valid field names in nested structures" do
      defmodule TestResourceWithValidNestedFields do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Ets,
          validate_domain_inclusion?: false,
          extensions: [AshSurface.Resource]

        surface do
          type_name("TestResourceWithValidNestedFields")
        end

        attributes do
          uuid_primary_key(:id)

          attribute :data, :map do
            public?(true)

            constraints(
              fields: [
                nested: [
                  type: :map,
                  constraints: [
                    fields: [
                      field1: [type: :string],
                      isActive: [type: :boolean],
                      deep_nested: [
                        type: :map,
                        constraints: [
                          fields: [
                            value: [type: :string]
                          ]
                        ]
                      ]
                    ]
                  ]
                ]
              ]
            )
          end
        end
      end

      assert TestResourceWithValidNestedFields

      assert :ok =
               AshSurface.VerifierChecker.check_all_verifiers([TestResourceWithValidNestedFields])
    end
  end
end
