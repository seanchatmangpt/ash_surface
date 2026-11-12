defmodule AshSurface.DivergenceClose.LeadingUnderscoreRefFormatter do
  @moduledoc "Hand-written real function: the reference rule (Macro.camelize + lowercase-first)."
  def ref(field) do
    case Macro.camelize(to_string(field)) do
      <<f::utf8, r::binary>> -> String.downcase(<<f::utf8>>) <> r
      "" -> ""
    end
  end
end

defmodule AshSurface.DivergenceClose.LeadingUnderscoreDivergenceTest do
  @moduledoc """
  KD-13 court: a leading `_` is preserved (`_x` -> `_x`); the reference drops it (`_x` -> `x`,
  ash_typescript helpers.ex:25-30). Witnessed harm of the reference rule, run in memory through
  the real admitted-set inverse: `x` and `_x` share one client key, so the inverse is ambiguous
  and BOTH fields become unreachable from the client. Also pins the collision law for the
  reference rule's other non-injective inputs (`Foo_bar`/`foo_bar`, `A_b`/`a_b`): refused typed
  by `EmittedKeys` (route arguments) and `FieldName.format_checked/3`.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.RouteSchema
  alias AshSurface.DivergenceClose.LeadingUnderscoreRefFormatter, as: Ref
  alias AshSurface.FieldName

  defp str(n), do: %{"name" => n, "type" => %{"kind" => "string"}, "allow_nil?" => false}

  defp route(names),
    do: [
      %{
        "name" => "t",
        "method" => "post",
        "path" => "/t",
        "arguments" => Enum.map(names, &str/1)
      }
    ]

  test "reference rule: x and _x collide and the inverse refuses both (the harm)" do
    assert Ref.ref("_x") == "x"
    assert Ref.ref("x") == "x"
    assert :error = FieldName.parse_input("x", {Ref, :ref}, [:x, :_x])
    assert :error = FieldName.parse_input("_x", {Ref, :ref}, [:x, :_x])
  end

  test "ash_surface rule: _x stays distinct, both fields round-trip" do
    assert FieldName.compute(:_x, :camel_case) == "_x"
    assert FieldName.compute(:__x_y, :camel_case) == "__xY"
    assert {:ok, :x} = FieldName.parse_input("x", :camel_case, [:x, :_x])
    assert {:ok, :_x} = FieldName.parse_input("_x", :camel_case, [:x, :_x])
    assert {:ok, %{"x" => :x, "_x" => :_x}} = FieldName.client_to_internal([:x, :_x], :camel_case)
    assert {:ok, [b]} = RouteSchema.build(route(["x", "_x"]))
    assert b["body"] =~ "_x:" and b["body"] =~ "x:"
  end

  test "reference-rule non-injective names are refused typed by the emitted-key law" do
    for {a, b, key} <- [{"foo_bar", "Foo_bar", "fooBar"}, {"a_b", "A_b", "aB"}] do
      assert Ref.ref(a) == key and Ref.ref(b) == key
      assert FieldName.compute(a, :camel_case) == key and FieldName.compute(b, :camel_case) == key

      assert {:error, {:emitted_key_collision, _route, ^key, names}} =
               RouteSchema.build(route([a, b]))

      assert Enum.sort(names) == Enum.sort([a, b])
      assert {:error, {:collision, ^key, _}} = FieldName.client_to_internal([a, b], :camel_case)
    end

    assert {:error, {:not_invertible, "Foo_bar", "fooBar"}} =
             FieldName.format_checked("Foo_bar", :camel_case)
  end
end
