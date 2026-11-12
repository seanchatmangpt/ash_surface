defmodule AshSurface.Compiler.NumberLiteral do
  @moduledoc """
  The ONE canonical JavaScript spelling of a numeric constraint value rendered
  into generated zod text.

  Elixir interpolation spells floats the Erlang way (`1.0`, `1.0e20`, `-0.0`);
  this module spells every number exactly as ECMAScript `Number.prototype.toString`
  does (`1`, `100000000000000000000`, `1e+21`, `1e-7`, `0`): the shortest digit
  string that round-trips to the identical IEEE double, no trailing `.0`, `-0.0`
  rendered `0`. Better than ash_typescript, which interpolates (`1.0e20`); proven
  by `test/ash_surface/compiler/number_literal_test.exs` (node parses the literal
  back to the identical double) and mirrored byte-identically by
  `numberLiteral` in `conformance/js/reference.mjs`.

  Integers beyond +-2^53 are rendered through their nearest double (what a JS
  parser would produce anyway). Non-finite values cannot exist as Elixir floats; an
  integer too large for a double raises `ArgumentError` (refused, never emitted).
  """

  @max_safe 9_007_199_254_740_992

  @spec render!(number()) :: String.t()
  def render!(n) when is_integer(n) and abs(n) <= @max_safe, do: Integer.to_string(n)

  def render!(n) when is_integer(n) do
    render!(n * 1.0)
  rescue
    ArithmeticError -> raise ArgumentError, "integer #{n} is not representable as a finite double"
  end

  def render!(f) when is_float(f) do
    if f == 0.0 do
      "0"
    else
      {sign, digits, point} = decompose(f)
      sign <> js_layout(digits, point)
    end
  end

  def render!(other), do: raise(ArgumentError, "not a number: #{inspect(other)}")

  # Shortest round-trip digits via Float.to_string/1, normalised to
  # {sign, digit_string_without_trailing_zeros, n} meaning 0.DIGITS * 10^n.
  defp decompose(f) do
    str = Float.to_string(f)

    {sign, str} =
      if String.starts_with?(str, "-"),
        do: {"-", binary_part(str, 1, byte_size(str) - 1)},
        else: {"", str}

    {mant, exp} =
      case String.split(str, "e") do
        [m, e] -> {m, String.to_integer(e)}
        [m] -> {m, 0}
      end

    [int, frac] = String.split(mant, ".")
    all = int <> frac
    lead = byte_size(all) - byte_size(String.trim_leading(all, "0"))
    digits = all |> String.trim_leading("0") |> String.trim_trailing("0")
    {sign, digits, byte_size(int) + exp - lead}
  end

  # ECMAScript Number::toString layout (k digits, decimal exponent n).
  defp js_layout(d, n) do
    k = byte_size(d)

    cond do
      k <= n and n <= 21 ->
        d <> String.duplicate("0", n - k)

      0 < n and n <= 21 ->
        binary_part(d, 0, n) <> "." <> binary_part(d, n, k - n)

      -6 < n and n <= 0 ->
        "0." <> String.duplicate("0", -n) <> d

      true ->
        e = n - 1
        es = if(e < 0, do: "-", else: "+") <> Integer.to_string(abs(e))

        if k == 1,
          do: d <> "e" <> es,
          else: binary_part(d, 0, 1) <> "." <> binary_part(d, 1, k - 1) <> "e" <> es
    end
  end
end
