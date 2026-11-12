defmodule AshSurface.F1ErrCamelTest do
  use ExUnit.Case, async: false

  alias AshSurface.Compiler.ErrorSchema
  alias AshSurface.Errors
  alias AshSurface.ZodFixtures.HarnessExt

  defp invalid(field, path),
    do: %{
      Ash.Error.Changes.InvalidAttribute.exception(
        field: field,
        message: "must be %{min}",
        vars: [min: 3]
      )
      | path: path
    }

  test "fields, vars.field and path segments are camelCased without a field_names mapping" do
    [e] = Errors.to_errors(invalid(:first_name, [:first_name, :nick_name]))
    assert e["fields"] == ["firstName"]
    assert e["path"] == ["firstName", "nickName"]
    assert e["vars"]["field"] == "firstName"
  end

  test "message is the bare template (reference Map.get(error, :message)) with vars" do
    [e] = Errors.to_errors(invalid(:first_name, []))
    assert e["message"] == "must be %{min}"
    assert e["vars"]["min"] == 3
  end

  test "snake_case and pascal_case formatters" do
    [s] = Errors.to_errors(invalid(:first_name, []), formatter: :snake_case)
    assert s["fields"] == ["first_name"]
    [p] = Errors.to_errors(invalid(:first_name, []), formatter: :pascal_case)
    assert p["Fields"] == ["FirstName"]
  end

  test "unknown formatter is a typed refusal" do
    assert_raise ArgumentError, ~r/unknown_formatter/, fn ->
      Errors.to_errors(invalid(:first_name, []), formatter: :shouty)
    end
  end

  test "formatted error validates under node+zod ErrorSchema" do
    [e] = Errors.to_errors(invalid(:first_name, [:first_name]))

    assert [%{"success" => true}] =
             HarnessExt.run_fragment!(ErrorSchema.base(), [
               %{label: "camel", expect: true, payload: e}
             ])
  end
end
