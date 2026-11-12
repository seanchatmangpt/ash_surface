defmodule AshSurface.Ported.T2 do
  @moduledoc """
  Lane T2 shared helpers (private to `ported/top`): real node+zod evaluation of an emitted
  Zod expression, real Ash facts/type analysis, scoped `:ash_surface` env edits and inline
  resource compilation. No doubles.
  """
  alias AshSurface.Compiler.{ResourceFacts, TypeFacts, ZodType}
  alias AshSurface.ZodFixtures.Harness

  @doc "Runs `expr` under real node+zod; returns `{:ok, [boolean]}` (one per payload) or `{:throw, msg}`."
  def node_eval(expr, payloads) do
    dir = AshSurface.TestTmp.unique_dir("t2")
    File.ln_s!(Path.join(Harness.repo_root(), "node_modules"), Path.join(dir, "node_modules"))
    Harness.zod!()

    File.write!(Path.join(dir, "s.mjs"), """
    import { z } from "zod";
    const payloads = #{Jason.encode!(payloads)};
    try {
      const s = #{expr};
      console.log(JSON.stringify({ok: payloads.map((p) => s.safeParse(p).success)}));
    } catch (e) { console.log(JSON.stringify({throw: String(e.message)})); }
    """)

    {out, 0} = Harness.run(Harness.tool!("node"), ["s.mjs"], dir)
    File.rm_rf!(dir)

    case Jason.decode!(out |> String.split("\n", trim: true) |> List.last()) do
      %{"ok" => oks} -> {:ok, oks}
      %{"throw" => msg} -> {:throw, msg}
    end
  end

  @doc """
  Evaluates `expr` under real node + zod as `s`, then runs the JS `probe` (a function body with
  `s` in scope) and returns its JSON-decoded result (e.g. `Object.keys(s.shape)`,
  per-key `safeParse`).
  """
  def node_probe(expr, probe) do
    dir = AshSurface.TestTmp.unique_dir("t2p")
    File.ln_s!(Path.join(Harness.repo_root(), "node_modules"), Path.join(dir, "node_modules"))
    Harness.zod!()

    File.write!(Path.join(dir, "s.mjs"), """
    import { z } from "zod";
    const s = #{expr};
    console.log(JSON.stringify((() => { #{probe} })()));
    """)

    {out, 0} = Harness.run(Harness.tool!("node"), ["s.mjs"], dir)
    File.rm_rf!(dir)
    out |> String.split("\n", trim: true) |> List.last() |> Jason.decode!()
  end

  @doc "IRs of the whole ported domain, compiled once per VM (real manifest + real compiler)."
  def irs do
    case :persistent_term.get({__MODULE__, :irs}, nil) do
      nil ->
        Application.put_env(:ash_surface_t2, :ash_domains, [AshSurface.Ported.Domain])
        {:ok, manifest} = Ash.Info.Manifest.generate(otp_app: :ash_surface_t2)

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

  @doc "The compiled IR of `resource`'s `action`."
  def ir(resource, action),
    do: Enum.find(irs(), &(&1.ash.resource == resource and &1.ash.action == action))

  @doc "Resource facts of the resource's `:read` action (sortable fields, filter entries, ...)."
  def read_facts(resource, action \\ :read),
    do:
      AshSurface.Ported.AshNames.with_verbatim(fn ->
        ResourceFacts.build(resource, Ash.Resource.Info.action(resource, action))
      end)

  @doc "Zod expression for a raw Ash `type` + `constraints` (the ash_surface `get_ts_type` analogue)."
  def zod(type, constraints \\ [], opts \\ []),
    do:
      type |> TypeFacts.analyze(constraints) |> Map.fetch!(:definition) |> ZodType.fragment(opts)

  @doc """
  Full Zod expression for a raw Ash type, the way the compiler renders it: containers (typed
  map/struct/keyword/tuple/union/embedded/array-of-container) through `EmbeddedSchema`, scalars
  through `ZodType`.
  """
  def zod_full(type, constraints \\ []) do
    definition = TypeFacts.analyze(type, constraints).definition

    if AshSurface.Compiler.EmbeddedSchema.container?(definition) do
      {:ok, zod} =
        AshSurface.Ported.AshNames.with_verbatim(fn ->
          AshSurface.Compiler.EmbeddedSchema.render(definition)
        end)

      zod
    else
      ZodType.fragment(definition)
    end
  end

  @doc """
  Record Zod expression of `resource` (`RecordSchema.render/2`) as a self-contained IIFE so the
  named declarations travel with it into one `T2.node_eval/2` run.
  """
  def record_zod(resource, opts \\ []) do
    {:ok, %{declarations: decls, expression: expr}} =
      AshSurface.Ported.AshNames.with_verbatim(fn ->
        AshSurface.Compiler.RecordSchema.render(resource, opts)
      end)

    :ok =
      AshSurface.Projectors.JS.ZodGuard.expression(expr,
        identifiers: Enum.map(decls, &elem(&1, 0))
      )

    "(() => { #{AshSurface.Compiler.EmbeddedSchema.declarations_source(%{declarations: decls})} return #{expr}; })()"
  end

  @doc "A named-field definition (as `EmbeddedSchema` consumes) from a raw Ash type."
  def field(name, type, constraints \\ [], allow_nil? \\ true) do
    TypeFacts.analyze(type, constraints).definition
    |> Map.merge(%{"name" => to_string(name), "allow_nil?" => allow_nil?})
    |> then(&if(allow_nil?, do: Map.put(&1, "omittable", true), else: &1))
  end

  @doc "Type-fact kind string for a raw Ash type."
  def kind(type, constraints \\ []), do: TypeFacts.kind(type, constraints)

  @doc "Runs `fun` with `:ash_surface` env `key` set to `value`, restoring the prior value."
  def with_env(key, value, fun) do
    prev = Application.fetch_env(:ash_surface, key)
    Application.put_env(:ash_surface, key, value)

    try do
      fun.()
    after
      case prev do
        {:ok, v} -> Application.put_env(:ash_surface, key, v)
        :error -> Application.delete_env(:ash_surface, key)
      end
    end
  end

  @doc "Compiles an inline surface resource (stderr captured); returns `{module, stderr}`."
  def compile_resource(body, surface \\ "projection :read") do
    name = "Elixir.AshSurface.Ported.T2.R#{System.unique_integer([:positive])}"

    out =
      ExUnit.CaptureIO.capture_io(:stderr, fn ->
        Code.compile_string("""
        defmodule #{name} do
          use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Simple,
            validate_domain_inclusion?: false, extensions: [AshSurface.Resource]
          #{body}
          surface do
            #{surface}
          end
        end
        """)
      end)

    {String.to_existing_atom(name), out}
  end
end
