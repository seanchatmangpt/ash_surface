defmodule AshSurface.Ported.T1 do
  @moduledoc """
  Lane T1 shared helpers (private to `ported/top`): the real compiled ported domain, its real JS
  artifact (cached once per VM) and real node+zod evaluation of artifact exports. No doubles.
  """
  alias AshSurface.ZodFixtures.Harness

  @doc """
  IRs of the whole ported domain (real manifest + real compiler), compiled once per VM under the
  identity formatter (`AshSurface.Ported.AshNames`): the shared pins assert naming-independent
  semantics over Ash names. Formatter-dependent behavior uses `irs_under/1`/`artifact_under/1`.
  """
  def irs do
    case :persistent_term.get({__MODULE__, :irs}, nil) do
      nil ->
        Application.put_env(:ash_surface_t1, :ash_domains, [AshSurface.Ported.Domain])
        {:ok, manifest} = Ash.Info.Manifest.generate(otp_app: :ash_surface_t1)

        {:ok, irs} =
          AshSurface.Ported.AshNames.with_verbatim(fn ->
            AshSurface.Compiler.compile(manifest)
          end)

        irs = if is_map(irs), do: Map.values(irs), else: irs
        :persistent_term.put({__MODULE__, :irs}, irs)
        irs

      irs ->
        irs
    end
  end

  @doc """
  Freshly compiled IRs of the whole ported domain under `formatter` (the compiler's process-scoped
  `:output_field_formatter` option; cached per formatter, `nil` = the configured default).
  """
  def irs_under(formatter) do
    key = {__MODULE__, :irs_under, formatter}

    case :persistent_term.get(key, nil) do
      nil ->
        Application.put_env(:ash_surface_t1, :ash_domains, [AshSurface.Ported.Domain])
        {:ok, manifest} = Ash.Info.Manifest.generate(otp_app: :ash_surface_t1)
        opts = if is_nil(formatter), do: [], else: [output_field_formatter: formatter]
        {:ok, irs} = AshSurface.Compiler.compile(manifest, opts)
        irs = if is_map(irs), do: Map.values(irs), else: irs

        :persistent_term.put(key, irs)
        irs

      irs ->
        irs
    end
  end

  @doc "The JS artifact of the ported domain compiled under `formatter` (cached per formatter)."
  def artifact_under(formatter) do
    key = {__MODULE__, :artifact_under, formatter}

    case :persistent_term.get(key, nil) do
      nil ->
        {:ok, artifacts, _meta} = AshSurface.Projectors.JS.project_ir(irs_under(formatter))
        art = Map.fetch!(artifacts, "ash_surface_client.mjs")
        :persistent_term.put(key, art)
        art

      art ->
        art
    end
  end

  @doc "The compiled IR of `resource`'s `action` under `formatter`."
  def ir_under(formatter, resource, action),
    do:
      Enum.find(
        irs_under(formatter),
        &(&1.ash.resource == resource and &1.ash.action == action)
      )

  @doc "The JS artifact text of the whole ported domain, projected once per VM."
  def artifact! do
    case :persistent_term.get({__MODULE__, :artifact}, nil) do
      nil ->
        {:ok, artifacts, _meta} = AshSurface.Projectors.JS.project_ir(irs())
        art = Map.fetch!(artifacts, "ash_surface_client.mjs")
        :persistent_term.put({__MODULE__, :artifact}, art)
        art

      art ->
        art
    end
  end

  @doc """
  Real node + real zod: for each `{export_name, payload}` runs `export.safeParse(payload)` against
  the generated artifact and returns the list of booleans (`true` = accepted). A missing export
  raises loudly.
  """
  def node_accepts(cases, artifact \\ nil) when is_list(cases) do
    dir = AshSurface.TestTmp.unique_dir("t1")
    File.ln_s!(Path.join(Harness.repo_root(), "node_modules"), Path.join(dir, "node_modules"))
    Harness.zod!()
    File.write!(Path.join(dir, "client.mjs"), artifact || artifact!())

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

  @doc """
  Real node + real zod: `Object.keys(<export>.shape)` of each named object-schema export of
  `artifact`, as `%{name => [key]}` (a missing or non-object export raises loudly).
  """
  def node_shape_keys(names, artifact) when is_list(names) do
    dir = AshSurface.TestTmp.unique_dir("t1k")
    File.ln_s!(Path.join(Harness.repo_root(), "node_modules"), Path.join(dir, "node_modules"))
    Harness.zod!()
    File.write!(Path.join(dir, "client.mjs"), artifact)

    File.write!(Path.join(dir, "run.mjs"), """
    import * as art from "./client.mjs";
    const out = {};
    for (const name of #{Jason.encode!(names)}) {
      if (!art[name] || !art[name].shape) throw new Error("no object export: " + name);
      out[name] = Object.keys(art[name].shape);
    }
    console.log(JSON.stringify(out));
    """)

    try do
      {out, 0} = Harness.run(Harness.tool!("node"), ["run.mjs"], dir)
      out |> String.split("\n", trim: true) |> List.last() |> Jason.decode!()
    after
      File.rm_rf!(dir)
    end
  end

  @doc "Names of the public aggregate/calculation/attribute/relationship fields of `resource`."
  def public_names(resource) do
    %{
      attributes: names(Ash.Resource.Info.public_attributes(resource)),
      aggregates: names(Ash.Resource.Info.public_aggregates(resource)),
      calculations: names(Ash.Resource.Info.public_calculations(resource)),
      relationships: names(Ash.Resource.Info.public_relationships(resource))
    }
  end

  defp names(list), do: Enum.map(list, & &1.name)

  @doc "Runs `fun` with `:ash_surface` env `key` set to `value`, restoring the prior value."
  def with_env(key, value, fun) do
    prev = Application.fetch_env(:ash_surface, key)

    if is_nil(value),
      do: Application.delete_env(:ash_surface, key),
      else: Application.put_env(:ash_surface, key, value)

    try do
      fun.()
    after
      case prev do
        {:ok, v} -> Application.put_env(:ash_surface, key, v)
        :error -> Application.delete_env(:ash_surface, key)
      end
    end
  end
end
