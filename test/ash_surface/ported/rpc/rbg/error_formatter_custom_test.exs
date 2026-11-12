defmodule AshSurface.Ported.Rpc.Rbg.Fmt do
  @moduledoc "Lane RBG: real custom formatter functions (real module, not a mock)."
  def tag(name), do: "t_" <> name
  def with_arg(name, a), do: name <> "|" <> a
  def with_two(name, a, b), do: name <> "|" <> a <> "|" <> b
  def atom_result(name), do: String.to_atom("x" <> name)
  def int_result(_name), do: 42
  def nil_result(_name), do: nil
  def empty_result(_name), do: ""
end

defmodule AshSurface.Ported.Rpc.Rbg.ErrorFormatterCustomTest do
  @moduledoc """
  Lane RBG: ErrorFormatter.format_name/2 custom `{m, f}` / `{m, f, args}`.

  Reference ash_typescript field_formatter.ex:321-325 and :419-423 call
  `apply(module, function, [field_name | extra_args])`: name first, extra args after. The
  reference returns the function result as-is; ash_surface (FieldName.call_custom) refuses
  a non-binary result (atom/integer/nil) rather than coercing it
  (RBI: now refused with typed `invalid_custom_formatter_result`, KD-12).
  """
  use ExUnit.Case, async: true

  alias AshSurface.ErrorFormatter, as: EF
  alias AshSurface.Ported.Rpc.Rbg.Fmt

  test "{m, f} calls f(name) and does not upcase or otherwise alter the result" do
    assert EF.format_name(:foo_bar, {Fmt, :tag}) == "t_foo_bar"
  end

  test "{m, f, args} applies the extra args (not the plain name)" do
    assert EF.format_name(:foo, {Fmt, :with_arg, ["A"]}) == "foo|A"
    assert EF.format_name("foo", {Fmt, :with_two, ["A", "B"]}) == "foo|A|B"
  end

  test "argument order: name first, args after" do
    assert EF.format_name(:n, {Fmt, :with_two, ["1", "2"]}) == "n|1|2"
    refute EF.format_name(:n, {Fmt, :with_two, ["1", "2"]}) == "1|n|2"
  end

  test "{m, f, []} equals {m, f}" do
    assert EF.format_name(:z, {Fmt, :tag, []}) == EF.format_name(:z, {Fmt, :tag})
  end

  test "non-binary or empty results are refused with invalid_custom_formatter_result" do
    for f <- [:atom_result, :int_result, :nil_result, :empty_result] do
      err = assert_raise ArgumentError, fn -> EF.format_name(:ab, {Fmt, f}) end
      assert err.message =~ "invalid_custom_formatter_result"
      assert err.message =~ "Fmt"
    end
  end

  test "custom formatter drives error key and placeholder rewriting end to end" do
    err = %{message: "bad %{field_x}", vars: %{field_x: 1}}
    out = EF.format(err, {Fmt, :tag})
    assert out == %{"t_message" => "bad %{t_field_x}", "t_vars" => %{"t_field_x" => 1}}
  end
end
