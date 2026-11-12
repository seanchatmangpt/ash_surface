defmodule AshSurface.Compiler.ZodTypeWave3Test do
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.{QuerySchema, ZodType}
  alias AshSurface.Projectors.JS.ZodGuard

  # Real zod 4 under node: [bool] per payload, or %{"throws" => msg} at load.
  defp zod(expr, payloads) do
    node = System.find_executable("node") || raise "REQUIRED TOOL MISSING: node"
    dir = Path.join(System.tmp_dir!(), "s1f_#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(dir)
    File.ln_s!(Path.join(File.cwd!(), "node_modules"), Path.join(dir, "node_modules"))

    File.write!(Path.join(dir, "run.mjs"), """
    import { z } from "zod";
    let out;
    try {
      const S = #{expr};
      out = #{Jason.encode!(payloads)}.map((p) => S.safeParse(p).success);
    } catch (e) { out = {throws: String(e)}; }
    process.stdout.write(JSON.stringify(out));
    """)

    {out, 0} = System.cmd(node, ["run.mjs"], cd: dir, stderr_to_stdout: true)
    File.rm_rf!(dir)
    Jason.decode!(out)
  end

  defp frag(match, flags \\ nil) do
    c = %{"match" => match}
    c = if flags, do: Map.put(c, "match_flags", flags), else: c
    ZodType.fragment(%{"type" => %{"kind" => "string"}, "constraints" => c})
  end

  describe "M1 regex detector" do
    test "trailing backslash is refused, never emitted unterminated" do
      assert {:error, :trailing_backslash} = ZodType.regex_check("abc\\")
      assert frag("abc\\") == "z.string()"

      assert [%{constraint: "match", reason: :trailing_backslash}] =
               ZodType.dropped_constraints(%{
                 "type" => %{"kind" => "string"},
                 "constraints" => %{"match" => "abc\\"}
               })

      # chained with a second field: the object still lexes and loads in node
      expr = "z.object({a: #{frag("abc\\")}, b: #{frag("^x")}})"
      assert {:ok, _, _} = ZodGuard.admit(expr)
      assert zod(expr, [%{"a" => "q", "b" => "x"}]) == [true]
    end

    for src <- [
          "a\\zb",
          "a\\Zb",
          "\\h",
          "\\R",
          "a\\Kb",
          "\\Qa.b\\E",
          "\\pL",
          "\\p{L}",
          "[[:alpha:]]",
          "a++",
          "a*+",
          "a?+",
          "(?i)a",
          "(?<=a)b",
          "(?<!a)b",
          "(?>a)",
          "(?P<n>a)",
          "(a",
          "a)",
          "[abc",
          "*a",
          "",
          "a\nb"
        ] do
      test "refused with typed error: #{inspect(src)}" do
        assert {:error, _} = ZodType.regex_check(unquote(src))
        refute ZodType.regex_safe_for_js?(unquote(src))
        assert frag(unquote(src)) == "z.string()"
      end
    end

    test "false positives fixed: escaped quantifier chars and escaped (?" do
      for src <- ["[*+?]\\+", "\\++", "^\\(?id$", "a\\+\\+", "[+*]\\+x"] do
        assert :ok = ZodType.regex_check(src), src
        assert frag(src) =~ ".regex(/"
      end

      expr = frag("^\\(?id$")
      assert {:ok, _, _} = ZodGuard.admit(expr)
      assert zod(expr, ["(id", "id", "(?i)id", "xid"]) == [true, true, false, false]

      expr = frag("^[*+?]\\+$")
      assert zod(expr, ["*+", "?+", "++", "+", "a+"]) == [true, true, true, false, false]
    end

    test "$ keeps PCRE trailing-newline semantics in node (accept/reject agrees with Elixir)" do
      expr = frag("^ab$")
      assert {:ok, _, _} = ZodGuard.admit(expr)
      payloads = ["ab", "ab\n", "ab\n\n", "abc", "xab"]
      elixir = for p <- payloads, do: Regex.match?(~r/^ab$/, p)
      assert zod(expr, payloads) == elixir
      # m flag: JS and PCRE both line-anchor; no translation
      assert frag("^ab$", "m") == "z.string().regex(/^ab$/m)"
      # escaped and class dollars are literal, untouched
      assert frag("a\\$") == "z.string().regex(/a\\$/)"
      assert frag("[$]") == "z.string().regex(/[$]/)"
    end

    test "slash inside regex and class is escaped and loads" do
      expr = frag("^a/b[/]$")
      assert {:ok, _, _} = ZodGuard.admit(expr)
      assert zod(expr, ["a/b/", "ab"]) == [true, false]
    end
  end

  describe "M2 sort schema" do
    test "emits a regex literal that loads in zod 4 and agrees on inputs" do
      assert {:ok, expr} = QuerySchema.render_sort_schema(["name", "age"])
      assert expr =~ ".regex(/"
      assert {:ok, _, ^expr} = ZodGuard.admit(expr)
      ok = ["name", "-age", "+name", "++name", "--age", "name,-age", "age,+name"]
      bad = ["", "foo", "name,", ",name", "name,foo", "-", "n ame"]

      assert zod(expr, ok ++ bad) ==
               List.duplicate(true, length(ok)) ++ List.duplicate(false, length(bad))
    end

    test "array variant loads and accepts arrays" do
      assert {:ok, expr} = QuerySchema.render_sort_schema(["name"], array?: true)
      assert zod(expr, ["name", ["name", "-name"], [1], 5]) == [true, true, false, false]
    end
  end

  describe "L4 pagination" do
    test "max_limit 0 / negative / non-integer refused" do
      for bad <- [0, -1, 1.5, "9"] do
        assert {:error, {:invalid_max_limit, ^bad}} =
                 QuerySchema.render_pagination_schema(%{offset?: true, max_limit: bad})
      end
    end

    test "limit optionality matches ash_typescript (required only when pagination required and no default)" do
      accept = fn opts, payload ->
        {:ok, expr} = QuerySchema.render_pagination_schema(Map.merge(%{offset?: true}, opts))
        assert {:ok, _, _} = ZodGuard.admit(expr)
        hd(zod(expr, [payload]))
      end

      # page present without limit
      assert accept.(%{required?: false}, %{}) == true
      assert accept.(%{required?: true, default_limit?: true}, %{}) == true
      assert accept.(%{required?: true, default_limit?: false}, %{}) == false
      assert accept.(%{required?: true}, %{limit: 5}) == true
      assert accept.(%{max_limit: 10}, %{limit: 11}) == false
    end
  end

  describe "L3 atom-keyed definitions" do
    test "required?/default/items/subtype survive stringify" do
      d = %{type: %{kind: :string}, required?: false}
      assert ZodType.fragment(d) == "z.string().optional()"
      assert ZodType.fragment(%{type: %{kind: :string}, default: "x"}) == "z.string().optional()"
      assert ZodType.fragment(%{type: %{kind: :string}}) == "z.string()"

      assert ZodType.fragment(%{type: %{kind: :array, items: %{"kind" => "integer"}}}) ==
               "z.array(z.number().int())"

      assert ZodType.fragment(%{type: %{kind: :enum, values: ["b", "a"]}}) ==
               ~s|z.enum(["a", "b"])|
    end
  end

  describe "better-than-ash_typescript kinds" do
    test "uuid accepts any 8-4-4-4-12 hex UUID (Ecto), still rejects non-UUIDs" do
      expr = ZodType.fragment(%{"type" => %{"kind" => "uuid"}})
      assert expr == "z.guid()"

      ps = [
        "123e4567-e89b-02d3-a456-426614174000",
        "123e4567-e89b-42d3-a456-426614174000",
        "nope",
        "123e4567e89b02d3a456426614174000"
      ]

      assert zod(expr, ps) == [true, true, false, false]
      # the strict form ash_typescript emits rejects the first (the accepted-input gap closed)
      assert zod("z.uuid()", ps) == [false, true, false, false]
    end

    test "naive_datetime accepts zoneless ISO; ash_typescript form rejects it" do
      expr = ZodType.fragment(%{"type" => %{"kind" => "naive_datetime"}})
      assert expr == "z.iso.datetime({local: true})"
      assert {:ok, _, _} = ZodGuard.admit(expr)
      ps = ["2024-01-01T10:00:00", "2024-01-01T10:00:00Z", "2024-01-01", "x"]
      assert zod(expr, ps) == [true, true, false, false]
      assert zod("z.iso.datetime()", ps) == [false, true, false, false]
    end
  end

  describe "emitted fixtures are all admitted by the guard allow-list" do
    test "every table kind renders to an admitted expression" do
      for kind <- ZodType.kinds() do
        assert {:ok, _, _} = ZodGuard.admit(ZodType.base(kind)), kind
      end
    end

    test "constraint chains, pagination, sort, query params are admitted" do
      c = %{"min" => 1, "max" => 9, "greater_than" => 0, "less_than" => 10}

      assert {:ok, _, _} =
               ZodGuard.admit(
                 ZodType.fragment(%{"type" => %{"kind" => "float"}, "constraints" => c})
               )

      assert {:ok, _, _} = ZodGuard.admit(frag("^a$", "i"))

      {:ok, p} =
        QuerySchema.render_pagination_schema(%{offset?: true, keyset?: true, countable?: true})

      assert {:ok, _, _} = ZodGuard.admit(p)
      {:ok, s} = QuerySchema.render_sort_schema(["a"], array?: true)
      assert {:ok, _, _} = ZodGuard.admit(s)
      assert {:ok, _, _} = ZodGuard.admit(QuerySchema.render_pagination_schema() |> elem(1))
    end
  end
end
