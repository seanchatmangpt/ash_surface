defmodule AshSurface.Compiler.SectionSchemaConstraintsTest do
  @moduledoc """
  Census D-03 court (lane b1a): the `:schema` section carries each argument's
  whole declared type fact set. A real Ash resource (ETS fixture
  `AshSurface.ZodFixtures.Constraints.Form`) with a regex `match` containing
  `\\d`, `allow_empty?: false`, an array with item constraints, an enum, a
  defaulted attribute, a typed struct and a union is compiled through
  `Compiler.compile/2`; the emitted zod is asserted textually, admitted by
  `ZodGuard`, byte-identical across runs, and executed under real zod in node.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Compiler
  alias AshSurface.Projectors.JS.ZodGuard
  alias AshSurface.ZodFixtures.Constraints.{Domain, Form}

  @action :create
  @otp_app :ash_surface_zod_fixtures

  defp compile! do
    # Manifest path: unified inputs = accepted attributes + arguments.
    # (sync module: the otp_app env is shared with the Harness).
    Application.put_env(@otp_app, :ash_domains, [Domain])
    assert {:ok, manifest} = Ash.Info.Manifest.generate(otp_app: @otp_app)
    assert {:ok, irs} = Compiler.compile(manifest)
    ir = Enum.find(irs, &(&1.ash.resource == Form and &1.ash.action == @action))
    assert ir, "create action missing from compiled IR"
    ir.schema
  end

  defp input_expression(zod) do
    [expr] =
      Regex.run(
        ~r/_inputSchema = (z\.object\(\{\n.*?\n\}\)\.passthrough\(\));/s,
        zod,
        capture: :all_but_first
      )

    expr
  end

  # Executes `expr` under real zod in node; returns [bool] per payload.
  defp run_zod(expr, payloads) do
    root = File.cwd!()
    node = System.find_executable("node") || raise "REQUIRED TOOL MISSING: node"
    dir = Path.join(System.tmp_dir!(), "b1a_#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(dir)
    File.ln_s!(Path.join(root, "node_modules"), Path.join(dir, "node_modules"))

    File.write!(Path.join(dir, "run.mjs"), """
    import { z } from "zod";
    const S = #{expr};
    const ps = #{Jason.encode!(payloads)};
    process.stdout.write(JSON.stringify(ps.map((p) => S.safeParse(p).success)));
    """)

    try do
      {out, 0} = System.cmd(node, ["run.mjs"], cd: dir, stderr_to_stdout: true)
      Jason.decode!(out)
    after
      File.rm_rf!(dir)
    end
  end

  @valid %{
    "name" => "abc1",
    "kind" => "basic",
    "code" => "123",
    "tags" => ["ab", "cde"],
    "level" => 3,
    "stats" => %{"count" => 2},
    "ref" => %{"text" => "hi"}
  }

  describe "emitted zod text" do
    test "constraint chains, optionality, enum, array, struct and union all present" do
      zod = compile!().zod
      input = input_expression(zod)

      # name: allow_empty? false => min(1), max_length => max(80), match => regex
      # with the `\d` class carried verbatim into the JS literal
      assert input =~ ~r/name: z\.string\(\)\.min\(1\)\.max\(80\)\.regex\(\/\^\[a-z\\d\]\+/

      # argument `code`: allow_empty? + max_length + match
      assert input =~ ~r/code: z\.string\(\)\.min\(1\)\.max\(3\)\.regex\(\/\^\\d\{3\}/

      # enum
      assert input =~ ~s|kind: z.enum(["basic", "premium"])|

      # array with item constraints, omittable
      assert input =~ "tags: z.array(z.string().min(2).max(5)).nullable().optional()"

      # defaulted attribute is omittable and carries its numeric bounds
      assert input =~ "level: z.number().int().min(1).max(9).nullable().optional()"

      # typed struct and union render structured (never silent z.unknown)
      assert input =~ "stats: z.object({ count: z.number().int().min(0)"
      assert input =~ "ref: z.union([z.object({text: z.string().min(1)}).strict()"
      refute input =~ "z.unknown()"
    end

    test "ZodGuard admits the input expression and the section is byte-identical across runs" do
      first = compile!()
      second = compile!()

      assert {:ok, :expression, _} = ZodGuard.admit(input_expression(first.zod))
      assert first.zod == second.zod
      assert first.input == second.input
    end

    test "IR input slice carries the declared facts (not only the kind)" do
      input = compile!().input

      assert input["name"]["constraints"]["allow_empty?"] == false
      assert input["name"]["constraints"]["max_length"] == 80
      assert is_binary(input["name"]["constraints"]["match"])
      assert input["tags"]["type"]["kind"] == "array"
      assert input["tags"]["type"]["items"]["constraints"]["min_length"] == 2
      assert input["kind"]["type"]["values"] == ["basic", "premium"]
      assert input["level"]["optional"] == true
      assert input["ref"]["type"]["kind"] == "union"

      assert Enum.map(input["ref"]["type"]["members"], & &1["name"]) == ["number", "text"] or
               Enum.map(input["ref"]["type"]["members"], & &1["name"]) == ["text", "number"]
    end
  end

  describe "executed under real zod" do
    setup do
      {:ok, expr: input_expression(compile!().zod)}
    end

    test "a valid payload passes", %{expr: expr} do
      assert run_zod(expr, [@valid]) == [true]
    end

    test "too-short name, bad regex, bad enum, bad code and bad item all fail", %{expr: expr} do
      payloads = [
        Map.put(@valid, "name", ""),
        Map.put(@valid, "name", "ABC-!"),
        Map.put(@valid, "kind", "gold"),
        Map.put(@valid, "code", "12"),
        Map.put(@valid, "code", "abc"),
        Map.put(@valid, "tags", ["a"]),
        Map.put(@valid, "level", 10),
        Map.put(@valid, "stats", %{"count" => -1}),
        Map.put(@valid, "ref", %{"other" => 1})
      ]

      assert run_zod(expr, payloads) == List.duplicate(false, length(payloads))
    end

    test "defaulted / nil-able inputs may be omitted", %{expr: expr} do
      minimal = Map.take(@valid, ["name", "kind", "code"])
      assert run_zod(expr, [minimal]) == [true]
    end
  end
end
