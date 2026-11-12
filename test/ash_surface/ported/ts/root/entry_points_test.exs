defmodule AshSurface.Ported.TS.Root.EntryPointsTest do
  @moduledoc """
  Adapts the ash_typescript root entry points `runZodTests.ts` (runtime runner that tallies
  shouldPass/shouldFail constraint cases under node), `shouldPass.ts` / `shouldFail.ts`
  (aggregators: the first must compile, the second must not) and, via the same tally, the
  `runValibotTests.ts` sibling is NOT covered here (Valibot gap, valibot_gap_test.exs).

  The runner is node + real zod (`test/ts/fragment_runner.mjs`); expressions come from the real
  `ZodType.fragment/2`, not hand-written schemas. Aggregators: the tsc half lives in
  struct_field_selection_test.exs (clean compile + wrong-expectation rejection).
  """
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.ZodType
  alias AshSurface.ZodFixtures.HarnessExt

  # {name, definition, valid payloads (shouldPass), invalid payloads (shouldFail)}
  @cases [
    {"integer min/max",
     %{"type" => %{"kind" => "integer"}, "constraints" => %{"min" => 1, "max" => 100}},
     [1, 50, 100], [0, 101, "5", 1.5]},
    {"string length",
     %{"type" => %{"kind" => "string"}, "constraints" => %{"min_length" => 2, "max_length" => 5}},
     ["ab", "abcde"], ["a", "abcdef", 3]},
    {"regex", %{"type" => %{"kind" => "string"}, "constraints" => %{"match" => "^[a-z]+$"}},
     ["abc", "z"], ["ABC", "a1", ""]}
  ]

  for {name, definition, good, bad} <- @cases do
    test "#{name}: shouldPass cases succeed and shouldFail cases fail under node zod" do
      expr = ZodType.fragment(unquote(Macro.escape(definition)))

      cases =
        Enum.map(
          unquote(Macro.escape(good)),
          &%{label: "pass #{inspect(&1)}", expect: true, payload: &1}
        ) ++
          Enum.map(
            unquote(Macro.escape(bad)),
            &%{label: "fail #{inspect(&1)}", expect: false, payload: &1}
          )

      results = HarnessExt.run_fragment!(expr, cases)
      assert length(results) == length(cases)
      failed = for r <- results, r["success"] != r["expect"], do: {r["label"], r["issues"]}
      assert failed == [], "#{unquote(name)} #{expr}: #{inspect(failed)}"
    end
  end

  test "the runner tally is not vacuous: a wrong expectation is reported as a mismatch" do
    expr = ZodType.fragment(%{"type" => %{"kind" => "integer"}, "constraints" => %{"min" => 1}})
    [r] = HarnessExt.run_fragment!(expr, [%{label: "x", expect: true, payload: 0}])
    refute r["success"] == r["expect"]
  end

  describe "fragment expressions are the real constraint chains" do
    test "integer bounds appear as min/max in the expression" do
      expr =
        ZodType.fragment(%{
          "type" => %{"kind" => "integer"},
          "constraints" => %{"min" => 1, "max" => 100}
        })

      assert expr =~ "z.number().int()"
      assert expr =~ ".min(1)"
      assert expr =~ ".max(100)"
    end

    test "boundary values are exact: min inclusive, max inclusive, one beyond rejected" do
      expr =
        ZodType.fragment(%{
          "type" => %{"kind" => "integer"},
          "constraints" => %{"min" => 10, "max" => 20}
        })

      results =
        HarnessExt.run_fragment!(
          expr,
          for {p, e} <- [
                {9, false},
                {10, true},
                {20, true},
                {21, false},
                {15.5, false},
                {nil, false}
              ] do
            %{label: inspect(p), expect: e, payload: p}
          end
        )

      assert for(r <- results, r["success"] != r["expect"], do: r["label"]) == []
    end

    test "string length bounds are inclusive on both ends and reject non-strings" do
      expr =
        ZodType.fragment(%{
          "type" => %{"kind" => "string"},
          "constraints" => %{"min_length" => 3, "max_length" => 4}
        })

      results =
        HarnessExt.run_fragment!(
          expr,
          for {p, e} <- [
                {"ab", false},
                {"abc", true},
                {"abcd", true},
                {"abcde", false},
                {7, false}
              ] do
            %{label: inspect(p), expect: e, payload: p}
          end
        )

      assert for(r <- results, r["success"] != r["expect"], do: r["label"]) == []
    end

    test "a different regex yields a different accept set (the pattern is honoured)" do
      expr =
        ZodType.fragment(%{
          "type" => %{"kind" => "string"},
          "constraints" => %{"match" => "^[0-9]+$"}
        })

      results =
        HarnessExt.run_fragment!(
          expr,
          for {p, e} <- [{"123", true}, {"abc", false}, {"12a", false}] do
            %{label: inspect(p), expect: e, payload: p}
          end
        )

      assert for(r <- results, r["success"] != r["expect"], do: r["label"]) == []
    end

    test "unknown kind falls back to z.unknown() and accepts anything" do
      assert ZodType.fragment(%{}) == "z.unknown()"
    end
  end

  describe "string constraint details" do
    test "allow_empty? false with min_length 0 still enforces non-empty" do
      expr =
        ZodType.fragment(%{
          "type" => %{"kind" => "string"},
          "constraints" => %{"allow_empty?" => false, "min_length" => 0}
        })

      assert expr =~ ".min(1)"

      results =
        HarnessExt.run_fragment!(expr, [
          %{label: "empty", expect: false, payload: ""},
          %{label: "a", expect: true, payload: "a"}
        ])

      assert for(r <- results, r["success"] != r["expect"], do: r["label"]) == []
    end

    test "regex match_flags are emitted and honoured (case-insensitive)" do
      expr =
        ZodType.fragment(%{
          "type" => %{"kind" => "string"},
          "constraints" => %{"match" => "^[a-z]+$", "match_flags" => "i"}
        })

      assert expr =~ ~r{/i\)}

      results =
        HarnessExt.run_fragment!(expr, [
          %{label: "upper", expect: true, payload: "ABC"},
          %{label: "digit", expect: false, payload: "A1"}
        ])

      assert for(r <- results, r["success"] != r["expect"], do: r["label"]) == []
    end
  end
end
