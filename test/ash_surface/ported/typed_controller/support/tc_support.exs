defmodule AshSurface.Ported.TypedController.Support do
  @moduledoc false
  # Private fixtures for the typed_controller test port (lane T14): descriptor builders and a
  # real node+zod parse harness (per-call unique tmp dir).
  alias AshSurface.ZodFixtures.Harness

  def arg(name, kind \\ "string", extra \\ %{}) do
    Map.merge(
      %{"name" => name, "type" => %{"kind" => kind}, "allow_nil?" => false},
      extra
    )
  end

  def route(name, method, path, args \\ [], extra \\ %{}) do
    Map.merge(
      %{"name" => name, "method" => method, "path" => path, "arguments" => args},
      extra
    )
  end

  def build!(routes) do
    {:ok, built} = AshSurface.Compiler.RouteSchema.build(routes)
    built
  end

  @doc "Parses each case with the zod schema source `schema`; returns a list of booleans."
  def node_parse(schema, cases) do
    dir = Path.join(System.tmp_dir!(), "t14_tc_#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(dir)

    try do
      File.ln_s!(Path.join(Harness.repo_root(), "node_modules"), Path.join(dir, "node_modules"))
      Harness.zod!()

      File.write!(Path.join(dir, "run.mjs"), """
      import { z } from "zod";
      const s = #{schema};
      const cases = #{Jason.encode!(cases)};
      process.stdout.write(JSON.stringify(cases.map((c) => s.safeParse(c).success)));
      """)

      {out, 0} = Harness.run(Harness.tool!("node"), ["run.mjs"], dir)
      Jason.decode!(out)
    after
      File.rm_rf!(dir)
    end
  end
end
