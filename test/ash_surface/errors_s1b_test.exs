defmodule AshSurface.ErrorsS1bTest do
  use ExUnit.Case, async: true

  alias AshSurface.{ErrorFormatter, Errors}
  alias AshSurface.Compiler.ErrorSchema

  defmodule Boom do
    defexception [:message]
  end

  defmodule Out do
    def format_error(_), do: raise("formatter boom")
  end

  defmodule DropHandler do
    def handle_error(_e, _c), do: nil
  end

  test "non-table Ash struct is unhandled (UUID only), not leaked" do
    err = Ash.Error.Framework.AssumptionFailed.exception(message: "secret internals")
    [out] = Errors.to_errors(err, show_raised_errors: false)
    refute inspect(out) =~ "secret internals"
    assert out["type"] == "unknown_error"
    assert out["details"]["errorId"]
  end

  test "module-valued :resource var loses Elixir prefix" do
    err = Ash.Error.Query.NotFound.exception(resource: My.App.Thing, primary_key: %{id: 1})
    [out] = Errors.to_errors(err)
    assert out["type"] == "not_found"
    refute inspect(out) =~ "Elixir."
    assert out["vars"]["resource"] == "Thing"
  end

  test "printable integer lists stay lists; tuple map keys do not break Jason" do
    err =
      Ash.Error.Changes.InvalidAttribute.exception(field: :a, value: [72, 105], message: "bad")

    [out] = Errors.to_errors(err)
    assert out["vars"]["value"] == [72, 105]

    assert {:ok, _} =
             Jason.encode(
               Errors.to_errors(
                 Ash.Error.Changes.InvalidAttribute.exception(field: :a, value: %{{1, 2} => 3})
               )
             )
  end

  test "user data keys inside vars values are not camelized" do
    err =
      Ash.Error.Changes.InvalidAttribute.exception(
        field: :a,
        value: %{"snake_key" => 1},
        message: "x"
      )

    [out] = Errors.to_errors(err)
    assert out["vars"]["value"] == %{"snake_key" => 1}
  end

  test "raising output formatter fails closed" do
    err = Ash.Error.Query.NotFound.exception(resource: My.App.Thing)
    [out] = Errors.to_errors(err, error_output_formatter: Out)
    assert out["type"] == "unknown_error"
  end

  test "handler returning nil drops the error" do
    err = Ash.Error.Query.NotFound.exception(resource: My.App.Thing)
    assert [] == Errors.to_errors(err, default_handler: DropHandler)
  end

  test "field_errors keys follow formatter" do
    assert ErrorSchema.field_errors([:street_line]) =~ "streetLine"
    assert ErrorSchema.field_errors([:street_line], formatter: :snake_case) =~ "street_line"
    assert ErrorSchema.base() =~ ".passthrough()"
    assert ErrorFormatter.format_name("a_b", :camel_case) == "aB"
  end
end
