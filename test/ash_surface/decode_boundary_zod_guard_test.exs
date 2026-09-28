defmodule AshSurface.DecodeBoundaryZodGuardTest do
  @moduledoc """
  Decode-boundary law for `AshSurface.Projectors.JS.ZodGuard`: the zod text
  inside a decoded IR is untrusted source that the JS projector would embed in
  an executable `.mjs`. The guard must confine it syntactically (Chicago
  school: the real guard, no doubles).

  Laws pinned:

    1. Every denied member (`constructor prototype call apply bind`) and every
       `__`-prefixed member is refused as `{:zod_denied_member, name}` in
       every position (bare member, called member, chained after a valid
       call). This is the guard the mutation falsifier removes
       (`zodguard-allow-constructor`): were `constructor` allowed,
       `z.string().constructor` would be admitted and embedded byte-verbatim.
    2. Totality: for arbitrary token soup the guard returns `{:ok, _, _}` or
       `{:error, _}` — it never raises.
    3. Soundness of admission: whatever the guard admits contains no denied or
       dunder member after a `.`, no statement separator, no template or
       comment syntax, and no arrow — the constructs that reach the `Function`
       constructor or arbitrary code.

  Bounded: 400 cases per property.
  """

  use ExUnit.Case, async: true
  use ExUnitProperties

  alias AshSurface.Projectors.JS.ZodGuard

  @denied ~w(constructor prototype call apply bind)
  @runs 400

  describe "denied members" do
    test "each denied member is refused bare, called, and chained" do
      for member <- @denied ++ ["__proto__", "__defineGetter__", "__x"] do
        for zod <- [
              "z.string()." <> member,
              "z.string()." <> member <> "()",
              "z.string().min(1)." <> member <> "(z.string())",
              "z.object({a: z.string().optional()})." <> member
            ] do
          assert ZodGuard.admit(zod) == {:error, {:zod_denied_member, member}}, inspect(zod)
        end
      end
    end

    test "ordinary zod members remain admitted (the guard is not a blanket refusal)" do
      for zod <- [
            "z.string().min(1).max(10)",
            "z.number().int().nullable()",
            "z.record(z.string(), z.unknown())"
          ] do
        assert ZodGuard.admit(zod) == {:ok, :expression, zod}
      end
    end
  end

  # Token soup biased toward the dangerous vocabulary.
  defp fragment do
    one_of([
      member_of([
        "z",
        ".",
        "(",
        ")",
        ",",
        "{",
        "}",
        "[",
        "]",
        ":",
        ";",
        "=>",
        "`",
        "//",
        "/*",
        "*/",
        "+",
        "=",
        "!",
        "constructor",
        "prototype",
        "call",
        "apply",
        "bind",
        "__proto__",
        "__x",
        "string",
        "number",
        "object",
        "min",
        "max",
        "optional",
        "eval",
        "Function",
        "this",
        "\"a\"",
        "'b'",
        "1",
        "-1.5e3",
        "null",
        "true"
      ]),
      string(:printable, max_length: 4)
    ])
  end

  defp soup do
    map(list_of(fragment(), max_length: 12), &Enum.join(&1, ""))
  end

  defp calls do
    gen all(
          head <-
            member_of([
              "z.string()",
              "z.number()",
              "z.object({})",
              "z.record(z.string(), z.unknown())"
            ]),
          chain <-
            list_of(
              member_of(
                ~w(min max optional nullable constructor prototype call apply bind __proto__ int)
              ),
              max_length: 4
            )
        ) do
      Enum.reduce(chain, head, fn m, acc -> acc <> "." <> m <> "()" end)
    end
  end

  property "admit/1 is total over arbitrary token soup (never raises)" do
    check all(
            text <- one_of([soup(), string(:printable, max_length: 30), binary(max_length: 8)]),
            max_runs: @runs
          ) do
      result = ZodGuard.admit(text)
      assert match?({:ok, _, _}, result) or match?({:error, _}, result)
    end
  end

  property "whatever is admitted contains no gadget vocabulary" do
    check all(text <- one_of([soup(), calls()]), max_runs: @runs) do
      case ZodGuard.admit(text) do
        {:ok, _kind, _embedded} ->
          refute text =~ ~r/\.\s*(constructor|prototype|call|apply|bind|__)/
          refute text =~ ~r/[;`]|\/\/|\/\*|=>/
          refute text =~ ~r/\b(eval|Function|this)\b/

        {:error, _} ->
          :ok
      end
    end
  end

  test "the generators are not vacuous: chains reach both admission and refusal" do
    outcomes =
      calls() |> Enum.take(300) |> Enum.map(&elem(ZodGuard.admit(&1), 0)) |> Enum.frequencies()

    assert outcomes[:ok] > 10
    assert outcomes[:error] > 10
  end
end
