defmodule AshSurface.Compiler do
  @moduledoc false

  # DiscoverOnce law: discovery reads the source EXACTLY once per forced
  # compile — never once per section, never once per action. The normalized
  # `AshSurface.IR` term is computed inside that single discovery pass and
  # flows, identical, to every injected section. Recompiling an unchanged
  # source serves the memoized compilation with zero reads; re-discovery
  # happens only when forced (`force: true`).

  alias AshSurface.IR

  defmodule Section do
    @moduledoc false

    @callback name() :: atom()
    @callback run(IR.t()) :: term()

    # Every section result echoes the exact IR term it received, making the
    # identical-term law observable from outside the compiler.
    def echo(ir, data), do: %{ir: ir, data: data}
  end

  defmodule Sections.Actions do
    @moduledoc false
    @behaviour AshSurface.Compiler.Section

    @impl true
    def name, do: :actions

    @impl true
    def run(%IR{} = ir),
      do: AshSurface.Compiler.Section.echo(ir, Enum.map(ir.actions, & &1.action))
  end

  defmodule Sections.Transports do
    @moduledoc false
    @behaviour AshSurface.Compiler.Section

    @impl true
    def name, do: :transports

    @impl true
    def run(%IR{} = ir) do
      AshSurface.Compiler.Section.echo(ir, Map.new(ir.actions, &{&1.action, &1.transport}))
    end
  end

  defmodule Sections.PublicIndex do
    @moduledoc false
    @behaviour AshSurface.Compiler.Section

    @impl true
    def name, do: :public_index

    @impl true
    def run(%IR{} = ir) do
      AshSurface.Compiler.Section.echo(ir, for(a <- ir.actions, a.public, do: a.action))
    end
  end

  defmodule Sections.PrivateIndex do
    @moduledoc false
    @behaviour AshSurface.Compiler.Section

    @impl true
    def name, do: :private_index

    @impl true
    def run(%IR{} = ir) do
      AshSurface.Compiler.Section.echo(ir, for(a <- ir.actions, not a.public, do: a.action))
    end
  end

  defmodule Sections.Digest do
    @moduledoc false
    @behaviour AshSurface.Compiler.Section

    @impl true
    def name, do: :digest

    @impl true
    def run(%IR{} = ir), do: AshSurface.Compiler.Section.echo(ir, ir.digest)
  end

  # The five injected sections of the default compilation.
  @default_sections [
    Sections.Actions,
    Sections.Transports,
    Sections.PublicIndex,
    Sections.PrivateIndex,
    Sections.Digest
  ]

  @cache_table __MODULE__.Cache

  @type source :: (-> [IR.action() | atom()]) | [IR.action() | atom()]

  @type compiled :: %{
          required(:ir) => IR.t(),
          required(:sections) => %{optional(atom()) => term()},
          required(:reads) => non_neg_integer()
        }

  @spec compile(source()) :: compiled()
  def compile(source), do: compile(source, [])

  @spec compile(source(), keyword()) :: compiled()
  def compile(source, opts) when is_list(opts) do
    force = Keyword.get(opts, :force, false)
    sections = Keyword.get(opts, :sections, @default_sections)

    case cache_fetch(source) do
      {:ok, cached} when not force ->
        # Recompile of an unchanged source: memoized compilation, zero reads.
        %{cached | reads: 0}

      _miss_or_forced ->
        # The single discovery pass of this run: one source read, one
        # normalization, one IR term for every section.
        ir = discover(source)
        compiled = %{ir: ir, sections: run_sections(ir, sections), reads: 1}
        cache_put(source, compiled)
        compiled
    end
  end

  defp discover(source) when is_function(source, 0), do: source.() |> IR.normalize()
  defp discover(source) when is_list(source), do: IR.normalize(source)

  defp discover(_other) do
    raise ArgumentError, "source must be a zero-arity reader fun or an action declaration list"
  end

  # The IDENTICAL ir term is handed to every section of the run — sections
  # never re-read the source and never re-normalize.
  defp run_sections(ir, sections) do
    Map.new(sections, fn section -> {section.name(), section.run(ir)} end)
  end

  defp cache_fetch(source) do
    case :ets.lookup(cache_table(), source) do
      [{^source, compiled}] -> {:ok, compiled}
      [] -> :error
    end
  end

  defp cache_put(source, compiled), do: :ets.insert(cache_table(), {source, compiled})

  defp cache_table do
    case :ets.whereis(@cache_table) do
      :undefined ->
        try do
          :ets.new(@cache_table, [:named_table, :set, :public, read_concurrency: true])
        catch
          # Another concurrent compile won the creation race.
          :error, :badarg -> @cache_table
        end

      table ->
        table
    end
  end
end
