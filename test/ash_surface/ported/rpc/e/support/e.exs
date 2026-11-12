Code.require_file("fixtures.exs", __DIR__)

defmodule AshSurface.Ported.E do
  @moduledoc """
  Lane T12 shared helpers (private to `ported/rpc/e`): compile throwaway real Ash resources from
  source text, run the real ash_surface verifier over them, and evaluate real generated Zod under
  real node. No doubles.
  """
  alias AshSurface.ZodFixtures.Harness

  @doc "Compiles `source` (module definitions), silencing compiler stderr. Returns the module list."
  def compile!(source) do
    {mods, _stderr} =
      ExUnit.CaptureIO.with_io(:standard_error, fn ->
        source
        |> Code.compile_string("t12_fixture.ex")
        |> Enum.map(&elem(&1, 0))
        |> Enum.reject(&(&1 |> Module.split() |> hd() == "Inspect"))
      end)

    mods
  end

  @doc "Real verifier path: `:ok | {:error, message}` (stderr from re-verification silenced)."
  def check(modules) do
    {result, _stderr} =
      ExUnit.CaptureIO.with_io(:standard_error, fn ->
        AshSurface.VerifierChecker.check_all_verifiers(List.wrap(modules))
      end)

    result
  end

  @doc "Unique module-name prefix so per-test fixtures never collide."
  def uniq(prefix), do: "#{prefix}#{System.unique_integer([:positive])}"

  @doc "IRs of `domains` through the real manifest + compiler."
  def irs(domains) do
    app = :"ash_surface_t12_#{System.unique_integer([:positive])}"
    Application.put_env(app, :ash_domains, List.wrap(domains))
    {:ok, manifest} = Ash.Info.Manifest.generate(otp_app: app)
    {:ok, irs} = AshSurface.Ported.AshNames.with_verbatim(fn -> AshSurface.Compiler.compile(manifest) end)
    if is_map(irs), do: Map.values(irs), else: irs
  end

  @doc "JS artifact text projected from an explicit list of IRs (real projector)."
  def artifact_from_irs!(irs) do
    {:ok, artifacts, _meta} = AshSurface.Projectors.JS.project_ir(irs)
    Map.fetch!(artifacts, "ash_surface_client.mjs")
  end

  @doc "JS artifact text of the whole ported fixture domain, projected once per VM."
  def artifact!(domains \\ [AshSurface.Ported.Domain]) do
    key = {__MODULE__, :artifact, domains}

    case :persistent_term.get(key, nil) do
      nil ->
        {:ok, artifacts, _meta} = AshSurface.Projectors.JS.project_ir(irs(domains))
        art = Map.fetch!(artifacts, "ash_surface_client.mjs")
        :persistent_term.put(key, art)
        art

      art ->
        art
    end
  end

  @doc """
  Real node + real zod: for each `{export_name, payload}` runs `export.safeParse(payload)`
  against `artifact` and returns `true` (accepted) / `false` per case. Missing export raises.
  """
  def node_accepts(artifact, cases) do
    dir = Path.join(System.tmp_dir!(), "t12_#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(dir)
    File.ln_s!(Path.join(Harness.repo_root(), "node_modules"), Path.join(dir, "node_modules"))
    Harness.zod!()
    File.write!(Path.join(dir, "client.mjs"), artifact)

    File.write!(Path.join(dir, "run.mjs"), """
    import * as art from "./client.mjs";
    const cases = #{Jason.encode!(Enum.map(cases, fn {n, p} -> [n, p] end))};
    const out = cases.map(([name, payload]) => {
      const s = art[name];
      if (!s) return {missing: name};
      return {ok: s.safeParse(payload).success};
    });
    console.log(JSON.stringify(out));
    """)

    try do
      {out, 0} = Harness.run(Harness.tool!("node"), ["run.mjs"], dir)

      out
      |> String.split("\n", trim: true)
      |> List.last()
      |> Jason.decode!()
      |> Enum.map(fn
        %{"ok" => ok} -> ok
        %{"missing" => name} -> raise "artifact export missing: #{name}"
      end)
    after
      File.rm_rf!(dir)
    end
  end
end

defmodule AshSurface.Ported.E.Zod do
  @moduledoc """
  Lane T12 helpers over a projected artifact: export-block/line extraction (text of the real
  generated Zod) and a one-process real-node batch evaluator.
  """
  alias AshSurface.Ported.E

  @doc "Text of `export const <name> = ...;` up to its closing `});`/`);` line."
  def block!(artifact, name) do
    case Regex.run(~r/export const #{Regex.escape(name)} = .*?\n\}\)[^\n]*;/s, artifact) do
      [block] -> block
      nil -> raise "export block not found: #{name}"
    end
  end

  @doc "The single generated line for `key` inside an export block."
  def line!(block, key) do
    pat = ~r/^\s*"?#{Regex.escape(key)}"?: .*$/m

    case Regex.run(pat, block) do
      [line] -> String.trim(line)
      nil -> raise "key not found in block: #{key}"
    end
  end

  @doc """
  Evaluates labelled `{label, export, payload}` cases under real node + zod in ONE process and
  returns `%{label => accepted?}`.
  """
  def batch!(artifact, cases) do
    results = E.node_accepts(artifact, Enum.map(cases, fn {_l, export, p} -> {export, p} end))
    cases |> Enum.map(&elem(&1, 0)) |> Enum.zip(results) |> Map.new()
  end
end
