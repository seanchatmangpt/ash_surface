defmodule AshSurface.Ported.Resource.TypescriptFieldNamesTest do
  use ExUnit.Case, async: false

  describe "verify/1 integration - typescript_field_names" do
    test "VerifyMapFieldNames suggests NewType with typescript_field_names for invalid names" do
      silence_stderr(fn ->
        defmodule TestResourceWithInvalidMapNames do
          use Ash.Resource,
            domain: nil,
            data_layer: Ash.DataLayer.Ets,
            validate_domain_inclusion?: false,
            extensions: [AshSurface.Resource]

          surface do
            type_name("TestResourceWithInvalidMapNames")
          end

          attributes do
            uuid_primary_key(:id)

            attribute :data, :map do
              public?(true)

              constraints(
                fields: [
                  field_1: [type: :string],
                  is_active?: [type: :boolean]
                ]
              )
            end
          end
        end
      end)

      result =
        AshSurface.VerifierChecker.check_all_verifiers([
          __MODULE__.TestResourceWithInvalidMapNames
        ])

      assert {:error, error_message} = result
      assert error_message =~ "Create a custom Ash.Type.NewType"
      assert error_message =~ "typescript_field_names/0"
      assert error_message =~ "defmodule MyApp.MyCustomType"
    end
  end

  # Compiling fixture modules that intentionally fail Spark verification makes
  # Elixir's parallel checker echo the raised DslError to stderr, so silence it.
  defp silence_stderr(fun) do
    {result, _stderr} = ExUnit.CaptureIO.with_io(:standard_error, fun)
    result
  end
end
