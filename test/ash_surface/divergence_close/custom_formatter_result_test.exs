defmodule AshSurface.DivergenceClose.CustomFormatterResultFmt do
  @moduledoc false
  def atom(_), do: :same
  def nil_(_), do: nil
  def int(_), do: 42
  def mixed(:x), do: :same
  def mixed(:y), do: "same"
  def tag(name), do: "t_" <> name
end

defmodule AshSurface.DivergenceClose.CustomFormatterResultTest do
  @moduledoc """
  KD-12 court: a custom formatter returning a non-binary is refused (typed), not passed raw
  (reference) nor coerced. Raw results were witnessed to produce `{"nil":1}` keys and an
  atom-vs-string collision that `Mapping.verify/1` admits (`:ok`), splitting one wire name.
  """
  use ExUnit.Case, async: true

  alias AshSurface.DivergenceClose.CustomFormatterResultFmt, as: Fmt
  alias AshSurface.FieldName
  alias AshSurface.FieldName.Mapping

  test "atom, integer and nil results are refused naming formatter and value" do
    for {f, shown} <- [atom: ":same", int: "42", nil_: "nil"] do
      e = assert_raise ArgumentError, fn -> FieldName.compute(:foo, {Fmt, f}) end
      assert e.message =~ "invalid_custom_formatter_result"
      assert e.message =~ shown
      assert e.message =~ "Fmt"
    end
  end

  test "mixed atom/string results can no longer slip past the collision check" do
    assert_raise ArgumentError, ~r/invalid_custom_formatter_result/, fn ->
      Mapping.verify(fields: [:x, :y], formatter: {Fmt, :mixed})
    end
  end

  test "binary results are unchanged" do
    assert FieldName.compute("foo", {Fmt, :tag}) == "t_foo"
  end
end
