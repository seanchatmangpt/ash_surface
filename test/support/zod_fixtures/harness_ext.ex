defmodule AshSurface.ZodFixtures.HarnessExt do
  @moduledoc """
  Domain-parametric variant of `AshSurface.ZodFixtures.Harness`: builds the JS
  artifact for any Ash domain (the base harness is hardwired to the Todo
  domain). Reuses the base harness for workspace/tooling.
  """
  alias AshSurface.ZodFixtures.Harness

  @otp_app :ash_surface_zod_fixtures_ext

  @doc "Compiles `domain` (or a list of domains) to the JS artifact text."
  def artifact!(domain_or_domains) do
    domains = List.wrap(domain_or_domains)
    Application.put_env(@otp_app, :ash_domains, domains)
    {:ok, manifest} = Ash.Info.Manifest.generate(otp_app: @otp_app)
    {:ok, irs} = AshSurface.Ported.AshNames.with_verbatim(fn -> AshSurface.Compiler.compile(manifest) end)
    {:ok, artifacts, _meta} = AshSurface.Projectors.JS.project_ir(irs)
    Map.fetch!(artifacts, "ash_surface_client.mjs")
  end

  @doc "Runs the raw-Zod-expression fragment runner; returns the decoded result list."
  def run_fragment!(expression, cases) do
    ts_dir = Harness.workspace!("export const SCHEMAS = {};\n")

    try do
      input = Path.join(ts_dir, "fragment_input.json")
      File.write!(input, Jason.encode!(%{expression: expression, cases: cases}))
      {out, 0} = Harness.run(Harness.tool!("node"), ["fragment_runner.mjs", input], ts_dir)
      Jason.decode!(out)
    after
      Harness.cleanup!(ts_dir)
    end
  end
end
