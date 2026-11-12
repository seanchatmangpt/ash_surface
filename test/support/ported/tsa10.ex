defmodule AshSurface.Ported.Tsa10 do
  @moduledoc """
  Support for the TSA-T10 adaptations of generated-TypeScript-text tests: compile real
  Spark resources to the canonical IR (real manifest, real compiler, no doubles) and evaluate a
  rendered Zod expression under real node + real zod against JSON cases.
  """

  alias AshSurface.ZodFixtures.Harness

  @doc "Compiled IRs for `{resource, action}` entrypoints (resources need no domain)."
  def irs(entrypoints, otp_app \\ :ash_surface) do
    {:ok, manifest} =
      Ash.Info.Manifest.generate(otp_app: otp_app, action_entrypoints: entrypoints)

    {:ok, irs} = AshSurface.Ported.AshNames.with_verbatim(fn -> AshSurface.Compiler.compile(manifest) end)
    if is_map(irs), do: Map.values(irs), else: irs
  end

  def ir!(irs, resource, action) do
    Enum.find(irs, &(&1.ash.resource == resource and &1.ash.action == action)) ||
      raise "no IR for #{inspect(resource)} #{action}"
  end

  @doc "Evaluates `zod` (a Zod expression string) against `cases`; returns a list of booleans."
  def node_eval(zod, cases) do
    Harness.zod!()
    dir = Path.join(System.tmp_dir!(), "tsa10_node_#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(dir)
    File.ln_s!(Path.join(Harness.repo_root(), "node_modules"), Path.join(dir, "node_modules"))

    File.write!(Path.join(dir, "t.mjs"), """
    import { z } from "zod";
    const schema = #{zod};
    const cases = #{Jason.encode!(cases)};
    process.stdout.write(JSON.stringify(cases.map(c => schema.safeParse(c).success)));
    """)

    try do
      {out, 0} = Harness.run(Harness.tool!("node"), ["t.mjs"], dir)
      Jason.decode!(out)
    after
      File.rm_rf!(dir)
    end
  end
end
