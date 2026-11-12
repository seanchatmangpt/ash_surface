defmodule AshSurface.Compiler.ZodTypeS3bTest do
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.{RouteSchema, ZodType}
  alias AshSurface.Projectors.JS.ZodGuard

  @moduletag :s3b

  # Runs a JS body in node with real zod 4; the body assigns `out` (JSON-able).
  defp node_run(body) do
    node = System.find_executable("node") || raise "REQUIRED TOOL MISSING: node"
    dir = Path.join(System.tmp_dir!(), "s3b_#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(dir)
    File.ln_s!(Path.join(File.cwd!(), "node_modules"), Path.join(dir, "node_modules"))

    File.write!(Path.join(dir, "run.mjs"), """
    import { z } from "zod";
    let out;
    #{body}
    process.stdout.write(JSON.stringify(out));
    """)

    {out, 0} = System.cmd(node, ["run.mjs"], cd: dir, stderr_to_stdout: true)
    File.rm_rf!(dir)
    Jason.decode!(out)
  end

  defp frag(match),
    do: ZodType.fragment(%{"type" => %{"kind" => "string"}, "constraints" => %{"match" => match}})

  # [bool] per payload; false also when the expression throws at load.
  defp accepts(expr, payloads) do
    node_run("""
    try { const S = #{expr};
      out = #{Jason.encode!(payloads)}.map((p) => S.safeParse(p).success);
    } catch (e) { out = {throws: String(e)}; }
    """)
  end

  describe "SK-s1 #1 leading ] in class" do
    test "refused typed, never emitted" do
      for s <- ["[]abc]", "[^]abc]"] do
        assert {:error, {:pcre_only, "leading ] in class"}} = ZodType.regex_check(s)
        assert frag(s) == "z.string()"
      end

      assert :ok = ZodType.regex_check("[\\]abc]")

      assert {:ok, :expression, _} = ZodGuard.admit(frag("^\\e[a-z]{2}$"))

      assert accepts(frag("[\\]abc]"), ["]", "a", "x"]) == [true, true, false]
    end
  end

  describe "SK-s1 #2 PCRE-only escapes" do
    test "\\e \\a \\x{..} translated faithfully; \\N \\V \\o refused" do
      assert accepts(frag("^\\e$"), ["\u001b", "e"]) == [true, false]
      assert accepts(frag("^\\a$"), ["\u0007", "a"]) == [true, false]
      assert accepts(frag("^\\x{41}$"), ["A", "x41", "x"]) == [true, false, false]
      assert accepts(frag("^\\x{9}$"), ["\t"]) == [true]

      for s <- ["\\N", "\\V", "\\o{101}", "\\x{263A}", "\\x{}"] do
        assert {:error, _} = ZodType.regex_check(s), s
        assert frag(s) == "z.string()"
      end
    end
  end

  describe "SK-s1 #3 quantifier grammar" do
    test "stacked / assertion-targeted quantifiers refused, valid ones load" do
      for s <- ["a{2}+", "^*", "a{2}{3}", "a**", "a?*", "$*", "\\b+", "{2}a", "(?:a|{2})"] do
        assert {:error, _} = ZodType.regex_check(s), s
      end

      for s <- ["a{2}", "a{2,}", "a{2,3}?", "a{,3}", "a{x}", "(?=a)*", "x{0}"] do
        assert :ok = ZodType.regex_check(s), s
      end
    end

    # seed 20_261_111 -- 300 patterns from a small grammar
    test "property (seed 20261111): accepted => node constructs; refused => typed error" do
      :rand.seed(:exsss, {20_261_111, 7, 3})

      atoms =
        String.split(
          ~S"a b . \d \w \b \B ^ $ [ab] [^a] [] []x] [^]x] \e \a \x{41} \N \V \o{1} \) \{ ( (?: (?= ) | { } {2} {2,} {2,3} * + ? \x41 \]",
          " "
        )

      sources =
        for _ <- 1..300 do
          for _ <- 1..Enum.random(1..5), into: "", do: Enum.random(atoms)
        end
        |> Enum.reject(&(&1 == ""))

      results =
        node_run("""
        out = #{Jason.encode!(sources)}.map((src) => {
          try { new RegExp(src); return true; } catch (e) { return false; }
        });
        """)

      # the fragment itself (translated body) must also load in zod
      loads =
        node_run("""
        out = #{Jason.encode!(Enum.map(sources, &frag/1))}.map(() => null);
        out = [];
        #{Enum.map_join(sources, "\n", fn s -> "try { #{frag(s)}; out.push(true) } catch (e) { out.push(false) }" end)}
        """)

      for {{src, raw_ok}, loaded} <- Enum.zip(Enum.zip(sources, results), loads) do
        case ZodType.regex_check(src) do
          :ok ->
            assert loaded, "accepted but fragment throws in node: #{inspect(src)}"
            # accepted sources whose raw form node rejects must be translated forms only
            if not raw_ok,
              do:
                assert(
                  src =~ "\\x{" or src =~ "\\e" or src =~ "\\a",
                  "raw throws: #{inspect(src)}"
                )

          {:error, _} = e ->
            assert frag(src) == "z.string()", inspect({src, e})
        end
      end
    end
  end

  describe "SK-s1 #4 strict numeric coercion for path/query" do
    defp built(kind, verb, path) do
      {:ok, [r]} =
        RouteSchema.build([
          %{
            "name" => "r",
            "method" => verb,
            "path" => path,
            "arguments" => [
              %{"name" => "n", "type" => %{"kind" => kind}, "allow_nil?" => false}
            ],
            "returns" => %{"type" => %{"kind" => "string"}}
          }
        ])

      r
    end

    @bad [
      "0x10",
      "0b11",
      "0o7",
      "1e3",
      "1E3",
      " 5 ",
      "5 ",
      "-0",
      "Infinity",
      "NaN",
      "",
      "+5",
      "1_0",
      "5."
    ]

    test "int args: only canonical decimal strings coerce (node+zod, path and query)" do
      for {verb, path, key} <- [{"get", "/x/:n", "params"}, {"get", "/x", "query"}] do
        r = built("integer", verb, path)
        good = ["5", "-5", "007", "0"]
        # route schemas are descriptors (arrow fn in preprocess), not ZodGuard input
        res = accepts(r[key], Enum.map(good ++ @bad, &%{"n" => &1}))
        assert res == List.duplicate(true, length(good)) ++ List.duplicate(false, length(@bad))
        assert accepts(r[key], [%{"n" => "1.5"}]) == [false]
      end
    end

    test "float args: canonical decimals with fraction only" do
      r = built("float", "get", "/x")
      good = ["5", "-5.25", "0.5", "10.0"]
      bad = @bad -- ["5."]
      res = accepts(r["query"], Enum.map(good ++ bad ++ ["5."], &%{"n" => &1}))
      assert res == List.duplicate(true, length(good)) ++ List.duplicate(false, length(bad) + 1)
    end
  end

  describe "SK-s1 #5 uuid_v7" do
    test "uuid_v7 rejects non-RFC UUIDs like ash_typescript z.uuid(); uuid stays guid" do
      v7 = "018f4c3e-7b1a-7c2d-8e3f-0123456789ab"
      v4 = "550e8400-e29b-41d4-a716-446655440000"
      odd = "12345678-1234-1234-1234-123456789abc"
      f = fn k -> ZodType.fragment(%{"type" => %{"kind" => k}}) end
      assert f.("uuid_v7") == "z.uuid()"
      assert f.("uuid") == "z.guid()"
      assert accepts(f.("uuid_v7"), [v7, v4, odd, "nope"]) == [true, true, false, false]
      assert accepts(f.("uuid"), [v7, v4, odd, "nope"]) == [true, true, true, false]
    end
  end
end
