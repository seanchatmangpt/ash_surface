defmodule AshSurface.Compiler.StructArgumentZodCourtTest do
  @moduledoc """
  F1-structarg courts: an action argument typed `Ash.Type.Struct` with `instance_of: Resource`
  (or a `fields` constraint) renders a per-field strict Zod input object (ash_typescript
  struct-argument rule: public attributes of the resource), never the
  `z.record(z.string(), z.unknown())` fallback. Real manifest -> Compiler -> real node+zod.
  Cyclic `instance_of` renders through a named const (KD-02 machinery).
  """
  use ExUnit.Case, async: false

  alias AshSurface.Compiler
  alias AshSurface.Projectors.JS.ZodGuard
  alias AshSurface.ZodFixtures.StructArg.{Domain, Holder}

  @otp_app :ash_surface_zod_fixtures

  defp schema do
    Application.put_env(@otp_app, :ash_domains, [Domain])
    assert {:ok, manifest} = Ash.Info.Manifest.generate(otp_app: @otp_app)

    assert {:ok, irs} =
             Compiler.compile(manifest,
               output_field_formatter: {AshSurface.Ported.AshNames, :verbatim}
             )

    ir = Enum.find(irs, &(&1.ash.resource == Holder and &1.ash.action == :take))
    assert ir, "take action missing from compiled IR"
    ir.schema
  end

  # Whole emitted program: declarations plus the input expression bound to `S`.
  defp program(zod) do
    [_, expr] = Regex.run(~r/_inputSchema = (z\.object.*?\)\.passthrough\(\));/s, zod)

    decls =
      zod |> String.split("\n") |> Enum.take_while(&(not String.contains?(&1, "_inputSchema")))

    {Enum.join(decls, "\n"), expr}
  end

  defp run(zod, payloads) do
    {decls, expr} = program(zod)
    node = System.find_executable("node") || raise "REQUIRED TOOL MISSING: node"
    dir = Path.join(System.tmp_dir!(), "f1sa_#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(dir)
    File.ln_s!(Path.join(File.cwd!(), "node_modules"), Path.join(dir, "node_modules"))

    File.write!(Path.join(dir, "run.mjs"), """
    import { z } from "zod";
    #{decls}
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

  @id "11111111-1111-1111-1111-111111111111"
  @node %{"id" => @id, "label" => "a", "weight" => 1}

  test "IR carries kind resource + instance_of; zod is a per-field object, not the record fallback" do
    s = schema()
    assert s.input["node"]["type"]["kind"] == "resource"
    assert s.input["node"]["type"]["instance_of"] == "AshSurface.ZodFixtures.StructArg.Node"
    refute s.zod =~ "node: z.record(z.string(), z.unknown())"
    assert s.zod =~ "label: z.string()"
    assert s.zod =~ "weight:"
  end

  test "named const for the cyclic instance_of is guard-admitted" do
    {decls, expr} = program(schema().zod)
    assert decls =~ "Node"
    ids = Regex.scan(~r/const (\w+) =/, decls, capture: :all_but_first) |> List.flatten()
    assert ids != []
    assert :ok = ZodGuard.expression(expr, identifiers: ids)
  end

  test "instance_of struct: valid accepted; unknown key, wrong member type, null/missing refused" do
    zod = schema().zod

    payloads = [
      %{"node" => @node},
      %{"node" => Map.put(@node, "bogus", 1)},
      %{"node" => %{@node | "label" => 3}},
      %{"node" => %{@node | "label" => nil}},
      %{"node" => Map.delete(@node, "label")},
      %{"node" => %{@node | "weight" => -1}},
      %{"node" => %{@node | "weight" => nil}},
      %{},
      %{"node" => "x"}
    ]

    assert run(zod, payloads) == [true, false, false, false, false, false, true, false, false]
  end

  test "allow_nil on the argument: maybe_node accepts null and omission, still validates members" do
    zod = schema().zod

    payloads = [
      %{"node" => @node, "maybe_node" => nil},
      %{"node" => @node},
      %{"node" => @node, "maybe_node" => @node},
      %{"node" => @node, "maybe_node" => %{"label" => 1}},
      %{"node" => nil}
    ]

    assert run(zod, payloads) == [true, true, true, false, false]
  end

  test "cyclic instance_of: recursion validated exactly through the nested child" do
    zod = schema().zod
    deep = %{"label" => "r", "child" => %{"label" => "c", "child" => %{"label" => "g"}}}
    bad = %{"label" => "r", "child" => %{"label" => "c", "child" => %{"label" => 9}}}
    extra = %{"label" => "r", "child" => %{"label" => "c", "zzz" => 1}}

    assert run(zod, [
             %{"node" => deep},
             %{"node" => bad},
             %{"node" => extra}
           ]) == [true, false, false]
  end

  test "fields-constraint struct: per-field object with member constraints and nullability" do
    zod = schema().zod

    payloads = [
      %{"node" => @node, "typed" => %{"count" => 1}},
      %{"node" => @node, "typed" => %{"count" => 1, "note" => nil}},
      %{"node" => @node, "typed" => %{"count" => -1}},
      %{"node" => @node, "typed" => %{"note" => "n"}},
      %{"node" => @node, "typed" => %{"count" => 1, "extra" => 1}},
      %{"node" => @node, "typed" => %{"count" => "1"}}
    ]

    assert run(zod, payloads) == [true, true, false, false, false, false]
  end
end
