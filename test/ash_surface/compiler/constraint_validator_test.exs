defmodule AshSurface.Compiler.ConstraintValidatorTest do
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.ConstraintValidator, as: V
  alias AshSurface.Compiler.ZodType
  alias AshSurface.ZodFixtures.Harness

  @runner Path.expand("../../js/constraint_validation_agreement.test.mjs", __DIR__)

  defp d(kind, constraints \\ %{}, extra \\ %{}),
    do: Map.merge(%{"type" => %{"kind" => kind}, "constraints" => constraints}, extra)

  defp arr(item, constraints \\ %{}),
    do: %{"type" => %{"kind" => "array", "items" => item}, "constraints" => constraints}

  describe "issue shape" do
    test "codes and paths" do
      assert {:error, [%{code: "invalid_type", path: []}]} = V.validate(d("string"), 1)

      assert {:error, [%{code: "too_small"}]} =
               V.validate(d("string", %{"min_length" => 3}), "ab")

      assert {:error, [%{code: "too_big"}]} = V.validate(d("integer", %{"max" => 3}), 4)
      assert {:error, [%{code: "invalid_format"}]} = V.validate(d("uuid"), "nope")

      assert {:error, [%{code: "invalid_value"}]} =
               V.validate(d("string", %{"one_of" => ["a"]}), "b")

      assert {:error, [%{code: "invalid_type", path: [1]}]} =
               V.validate(arr(d("integer")), [1, "x"])

      assert :ok = V.validate(d("string", %{}, %{"allow_nil?" => true}), nil)
    end
  end

  defp static_cases do
    uuid4 = "123e4567-e89b-42d3-a456-426614174000"

    [
      {d("string"), "hi"},
      {d("string"), 1},
      {d("string"), nil},
      {d("string"), ""},
      {d("string", %{"min_length" => 3}), "ab"},
      {d("string", %{"min_length" => 3}), "abc"},
      {d("string", %{"max_length" => 3}), "abcd"},
      {d("string", %{"max_length" => 3}), "abc"},
      {d("string", %{"allow_empty?" => false}), ""},
      {d("string", %{"allow_empty?" => false}), "x"},
      {d("string", %{"allow_empty?" => false, "min_length" => 3}), "ab"},
      {d("string", %{"allow_empty?" => true}), ""},
      {d("string", %{"max_length" => 2}), "😀"},
      {d("string", %{"max_length" => 1}), "😀"},
      {d("string", %{"match" => "^[a-z0-9-]+$"}), "ab-1"},
      {d("string", %{"match" => "^[a-z0-9-]+$"}), "AB"},
      {d("string", %{"match" => "^[a-z]+$", "match_flags" => "i"}), "ABC"},
      {d("string", %{"match" => "^[a-z]+$"}), "ABC"},
      {d("string", %{"match" => "(?<=a)b"}), "zzz"},
      {d("ci_string", %{"min_length" => 2}), "a"},
      {d("binary", %{"max_length" => 2}), "abc"},
      {d("integer"), 5},
      {d("integer"), 5.0},
      {d("integer"), 5.5},
      {d("integer"), "5"},
      {d("integer"), 9_007_199_254_740_992},
      {d("integer"), -3},
      {d("integer", %{"min" => 0, "max" => 10}), -1},
      {d("integer", %{"min" => 0, "max" => 10}), 0},
      {d("integer", %{"min" => 0, "max" => 10}), 10},
      {d("integer", %{"min" => 0, "max" => 10}), 11},
      {d("integer", %{"greater_than" => 0}), 0},
      {d("integer", %{"greater_than" => 0}), 1},
      {d("integer", %{"less_than" => 5}), 5},
      {d("integer", %{"less_than" => 5}), 4},
      {d("float"), 1.5},
      {d("float", %{"min" => 0.5}), 0.4},
      {d("float", %{"max" => 2.5}), 2.5},
      {d("float", %{"greater_than" => 1.0, "less_than" => 2.0}), 1.5},
      {d("float", %{"greater_than" => 1.0, "less_than" => 2.0}), 2.0},
      {d("decimal"), "1.25"},
      {d("decimal"), 1.25},
      {d("decimal", %{"match" => "^\\d+\\.\\d+$"}), "12"},
      {d("boolean"), true},
      {d("boolean"), "true"},
      {d("boolean"), 0},
      {d("uuid"), uuid4},
      {d("uuid"), "123e4567-e89b-02d3-a456-426614174000"},
      {d("uuid"), "00000000-0000-0000-0000-000000000000"},
      {d("uuid"), "xyz"},
      {d("uuid"), 4},
      {d("uuid_v7"), uuid4},
      {d("uuid"), String.upcase(uuid4)},
      {d("date"), "2024-02-29"},
      {d("date"), "2023-02-29"},
      {d("date"), "2024-13-01"},
      {d("date"), "2024-04-31"},
      {d("date"), "2024-4-1"},
      {d("date"), "1900-02-29"},
      {d("date"), "2000-02-29"},
      {d("time"), "12:30"},
      {d("time"), "12:30:45"},
      {d("time"), "12:30:45.123"},
      {d("time"), "24:00"},
      {d("time"), "12:60"},
      {d("time"), "1:30"},
      {d("utc_datetime"), "2024-05-01T10:00:00Z"},
      {d("utc_datetime"), "2024-05-01T10:00:00.123456Z"},
      {d("utc_datetime"), "2024-05-01T10:00:00+02:00"},
      {d("utc_datetime"), "2024-05-01T10:00:00"},
      {d("utc_datetime"), "2024-05-01T10:00Z"},
      {d("utc_datetime"), "2024-05-01"},
      {d("datetime"), "2024-02-30T10:00:00Z"},
      {d("naive_datetime"), "2024-05-01T25:00:00Z"},
      {d("duration"), "P1D"},
      {d("duration"), "PT5M"},
      {d("duration"), "P1W"},
      {d("duration"), "P1W2D"},
      {d("duration"), "P"},
      {d("duration"), "PT"},
      {d("duration"), "1D"},
      {d("duration"), "P1Y2M3DT4H5M6S"},
      {d("atom"), "open"},
      {d("atom"), :open},
      {d("string", %{"one_of" => ["open", "closed"]}), "open"},
      {d("string", %{"one_of" => ["open", "closed"]}), "shut"},
      {d("atom", %{"one_of" => [:open, :closed]}), "closed"},
      {d("atom", %{"one_of" => [:open]}), 1},
      {d("integer", %{"one_of" => [1, 2, 3]}), 2},
      {d("integer", %{"one_of" => [1, 2, 3]}), 4},
      {d("integer", %{"one_of" => [1, 2, 3]}), "2"},
      {d("integer", %{"one_of" => [7]}), 7},
      {d("enum", %{}, %{"values" => ["a", "b"]}), "a"},
      {d("enum", %{}, %{"values" => ["a", "b"]}), "c"},
      {d("map"), %{"a" => 1}},
      {d("map"), []},
      {d("map"), nil},
      {d("map"), "x"},
      {d("term"), nil},
      {d("any"), %{"a" => [1]}},
      {d("unmapped_kind_xyz"), 5},
      {arr(d("string")), ["a", "b"]},
      {arr(d("string")), ["a", 1]},
      {arr(d("string")), "a"},
      {arr(d("string"), %{"min_length" => 2}), ["a"]},
      {arr(d("string"), %{"max_length" => 1}), ["a", "b"]},
      {arr(d("integer", %{"min" => 0})), [1, -1]},
      {arr(d("string")), []},
      {arr(d("string"), %{"min_length" => 1}), []},
      {arr(arr(d("integer"))), [[1], [2, "x"]]},
      {arr(d("uuid")), [uuid4, "bad"]},
      {%{"type" => %{"kind" => "array"}, "constraints" => %{}}, [1, "a", nil]},
      {d("vector"), [1, 2.5]},
      {d("vector"), [1, "a"]},
      {d("string", %{}, %{"allow_nil?" => true}), nil},
      {d("string"), nil},
      {d("string", %{}, %{"optional" => true}), :missing},
      {d("string"), :missing},
      {d("string", %{}, %{"allow_nil?" => true}), :missing},
      {d("string", %{}, %{"has_default" => true}), :missing},
      {d("integer", %{"min" => 1}, %{"allow_nil?" => true, "optional" => true}), :missing},
      {%{"subtype_of" => "string", "subtype_constraints" => %{"min_length" => 2}}, "a"},
      {%{"subtype_of" => "string", "subtype_constraints" => %{"min_length" => 2}}, "ab"},
      {d("any"), :missing}
    ]
  end

  defp property_cases do
    :rand.seed(:exsss, {314, 159, 265})

    strings =
      for _ <- 1..150 do
        s = StreamData.string(:printable, max_length: 8) |> Enum.take(1) |> hd()
        s = if :rand.uniform() < 0.2, do: s <> "😀", else: s

        c =
          Enum.reduce(["min_length", "max_length"], %{}, fn k, acc ->
            if :rand.uniform() < 0.6, do: Map.put(acc, k, :rand.uniform(9) - 1), else: acc
          end)

        {d("string", c), s}
      end

    numbers =
      for _ <- 1..150 do
        kind = Enum.random(["integer", "float"])

        gen = fn ->
          if kind == "integer", do: :rand.uniform(21) - 11, else: (:rand.uniform(210) - 110) / 10
        end

        c =
          Enum.reduce(~w(min max greater_than less_than), %{}, fn k, acc ->
            if :rand.uniform() < 0.35, do: Map.put(acc, k, gen.()), else: acc
          end)

        {d(kind, c), gen.()}
      end

    strings ++ numbers
  end

  test "agreement with real zod safeParse over the full table (static + property)" do
    table = static_cases() ++ property_cases()
    assert length(table) >= 60

    indexed = Enum.with_index(table)

    schemas =
      Enum.map_join(indexed, "\n", fn {{def, _v}, i} -> "  c#{i}: #{ZodType.fragment(def)}," end)

    artifact = "import { z } from \"zod\";\nexport const SCHEMAS = {\n#{schemas}\n};\n"

    cases =
      Enum.map(indexed, fn {{_d, v}, i} ->
        if v == :missing, do: %{id: "c#{i}", missing: true}, else: %{id: "c#{i}", payload: v}
      end)

    Harness.zod!()
    dir = Path.join(System.tmp_dir!(), "ash_surface_cv_#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    File.ln_s!(Path.join(Harness.repo_root(), "node_modules"), Path.join(dir, "node_modules"))
    File.write!(Path.join(dir, "schemas.mjs"), artifact)
    File.write!(Path.join(dir, "cases.json"), Jason.encode!(cases))
    File.cp!(@runner, Path.join(dir, "runner.mjs"))

    {out, 0} =
      Harness.run(Harness.tool!("node"), ["runner.mjs", "schemas.mjs", "cases.json"], dir)

    results = Jason.decode!(out)

    disagreements =
      for {{def, v}, i} <- indexed, r = Enum.at(results, i), V.valid?(def, v) != r["success"] do
        %{
          i: i,
          def: def,
          value: v,
          elixir: V.valid?(def, v),
          zod: r["success"],
          zod_issues: r["issues"],
          frag: ZodType.fragment(def)
        }
      end

    IO.puts("AGREEMENT #{length(table) - length(disagreements)}/#{length(table)}")
    assert disagreements == [], inspect(disagreements, limit: :infinity, pretty: true)
  end
end
