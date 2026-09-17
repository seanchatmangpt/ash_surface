defmodule AshSurface.FormatterRegistrationCanaryTest do
  @moduledoc """
  CHICAGO canary for the chicago-formatter-retire-033 decision: the surface
  never registers Spark formatter extensions for modules that do not exist.

  The witnessed defect (ticket chicago-formatter-retire-033): the retired
  `lib/ash_surface/formatter.ex` declared itself a "Spark.Formatter plugin for
  the ggen-manufactured AshSurface DSL" and registered `AshSurface.Resource` —
  a module that has never existed. The repo's real surface is Ash resources
  plus their manifests (`use Ash.Resource`; AGENTS.md canonical boundaries 1-3):
  `ash_surface` CONSUMES Ash semantics, it is not a Spark DSL, so there was
  nothing to wire the plugin to. The module was retired (not wired) and the
  decision is ledgered as a HANDWRITTEN + UNSUPPORTED pair.

  This canary makes the decorative pattern permanent law, no_local_do-style:

    * METHOD: every file under `lib/ash_surface/**/*.ex` plus the root
      `lib/ash_surface.ex` envelope, and `.formatter.exs` itself, are walked
      in-test via File.read!/1 + Code.string_to_quoted!/1 — the tree as it is,
      not a cached list.
    * LAW 1: every `extensions/0` definition on the surface whose body is a
      literal module list registers REAL modules — `Code.ensure_loaded?/1`
      must succeed for every named module at test time (the project is fully
      compiled before tests run, so a missing module is the observed state,
      not an inference).
    * LAW 2: every `plugins:` entry in `.formatter.exs` names a real module.
    * NON-VACUITY: the detector itself is exercised against the retired
      subject's exact source (must trip) and against a wired registration on
      a real module (must pass), so the guard cannot silently rot while the
      tree carries zero registrations.

  A future formatter plugin is not forbidden: register a real extension
  module and wire it via `.formatter.exs` `plugins:` — the canary stays green.
  Only the unwired-registration pattern (extension names nothing real) trips.
  """

  use ExUnit.Case, async: true

  @repo_root Path.expand("../..", __DIR__)
  @formatter_config Path.join(@repo_root, ".formatter.exs")
  @retired_subject "lib/ash_surface/formatter.ex"

  @files Enum.sort(Path.wildcard(Path.join(@repo_root, "lib/**/*.ex")))

  # -------------------------------------------------------------------------
  # Detector — public so the self-proof tests exercise the exact code path
  # the live-tree tripwires run.
  # -------------------------------------------------------------------------

  @doc "Modules literally registered by zero-arg `extensions/0` defs in `ast`."
  def registered_extension_modules(ast) do
    {_, acc} =
      Macro.prewalk(ast, [], fn
        {:def, _, [{:extensions, _, args}, body]} = node, acc when args in [nil, []] ->
          {node, acc ++ literal_module_list(body)}

        node, acc ->
          {node, acc}
      end)

    acc
  end

  # `[do: [...]]` body that is a literal list of module aliases.
  defp literal_module_list(do: body) when is_list(body) do
    for {:__aliases__, _, parts} <- body, do: Module.concat(parts)
  end

  defp literal_module_list(_), do: []

  @doc "Modules registered under `plugins:` in formatter-config `ast` (keyword form)."
  def registered_plugins(ast) do
    {_, acc} =
      Macro.prewalk(ast, [], fn
        # Literal keyword data: [plugins: [...]] entries are 2-tuples.
        {:plugins, value} = node, acc when is_list(value) ->
          {node, acc ++ for({:__aliases__, _, parts} <- value, do: Module.concat(parts))}

        # Call/argument-position keyword: {:plugins, meta, [...]}.
        {:plugins, _, value} = node, acc when is_list(value) ->
          {node, acc ++ for({:__aliases__, _, parts} <- value, do: Module.concat(parts))}

        node, acc ->
          {node, acc}
      end)

    acc
  end

  @doc "The observed state that makes a registration decorative: the module cannot be loaded."
  def unknown_module?(module), do: Code.ensure_loaded?(module) == false

  @doc "Violation strings for one source file's AST."
  def scan_ast(ast, ctx) do
    extensions = registered_extension_modules(ast)
    plugins = registered_plugins(ast)

    for module <- Enum.uniq(extensions ++ plugins),
        unknown_module?(module) do
      "#{ctx}: extensions registration names nonexistent module #{inspect(module)} — " <>
        "unwired-registration pattern (chicago-formatter-retire-033)"
    end
  end

  defp read_sources! do
    for path <- @files do
      source = File.read!(path)
      {path, source, Code.string_to_quoted!(source)}
    end
  end

  defp rel(path), do: Path.relative_to(path, @repo_root)

  # -------------------------------------------------------------------------
  # Method guard
  # -------------------------------------------------------------------------

  test "walk is real: lib/**/*.ex is non-empty and every file parses" do
    # GUARDS THE METHOD: a walk over an empty or stale glob is a silently
    # disabled canary; truncation is evidence, never permission.
    assert length(@files) >= 8,
           "lib walk shrank to #{length(@files)} files — canary unenforced"

    for {path, _source, ast} <- read_sources!() do
      assert is_tuple(ast), "#{rel(path)} did not produce an AST"
    end
  end

  # -------------------------------------------------------------------------
  # TRIPWIRES over the live tree
  # -------------------------------------------------------------------------

  test "TRIPWIRE unwired-registration: every extensions/0 registration on the surface names a real module" do
    # LAW: the retired formatter.ex registered AshSurface.Resource — a module
    # that has never existed — making both the registration and the module
    # decorative. A registration that names nothing real is a lie to
    # Spark.Formatter; it must never reappear on the surface.
    violations =
      for {path, _source, ast} <- read_sources!(),
          violation <- scan_ast(ast, rel(path)) do
        violation
      end
      |> Enum.uniq()

    assert violations == [],
           """
           Decorative formatter registration detected on the surface.
           Falsifiers survived:
           #{Enum.map_join(violations, "\n", &"  - #{&1}")}
           """
  end

  test "TRIPWIRE unwired-registration: every .formatter.exs plugins entry names a real module" do
    # LAW: a plugin wired into the project formatter config must exist; this
    # is the registration side of the same lie, one file over.
    source = File.read!(@formatter_config)
    ast = Code.string_to_quoted!(source)

    violations = scan_ast(ast, Path.relative_to(@formatter_config, @repo_root))

    assert violations == [], Enum.map_join(violations, "\n")
  end

  # -------------------------------------------------------------------------
  # NON-VACUITY self-proof — the detector is proven live in both directions
  # even though the tree currently carries zero registrations.
  # -------------------------------------------------------------------------

  test "SELF-PROOF RED: the retired decorative subject's exact source trips the canary" do
    # The retired subject, verbatim (chicago-formatter-retire-033): a plugin
    # shape registering AshSurface.Resource, which has never existed.
    retired_source = """
    defmodule AshSurface.Formatter do
      @moduledoc "Spark.Formatter plugin for the ggen-manufactured AshSurface DSL."

      @spec extensions() :: [module()]
      def extensions, do: [AshSurface.Resource]
    end
    """

    ast = Code.string_to_quoted!(retired_source)

    assert [AshSurface.Resource] = registered_extension_modules(ast)

    ctx = rel(Path.join(@repo_root, @retired_subject))

    assert [violation] = scan_ast(ast, ctx)

    assert String.starts_with?(violation, ctx <> ": ")
    assert violation =~ "AshSurface.Resource"
    assert violation =~ "nonexistent module"
    assert unknown_module?(AshSurface.Resource)
  end

  test "SELF-PROOF GREEN: a wired registration on real modules scans clean" do
    wired_source = """
    defmodule FutureSurface.Formatter do
      @moduledoc "A LAWFUL future plugin: real extension module, wired by config."

      @spec extensions() :: [module()]
      def extensions, do: [AshSurface.Event]

      @spec features(term()) :: [extensions: [String.t()]]
      def features(_opts), do: [extensions: [".ex", ".exs"]]
    end
    """

    ast = Code.string_to_quoted!(wired_source)

    assert [AshSurface.Event] = registered_extension_modules(ast)
    refute unknown_module?(AshSurface.Event)
    assert scan_ast(ast, "fixture") == []

    # Non-registration bodies stay out of the law's scope entirely.
    assert registered_extension_modules(Code.string_to_quoted!("def extensions, do: []")) == []

    assert registered_extension_modules(
             Code.string_to_quoted!("def extensions, do: extensions()")
           ) == []

    assert registered_extension_modules(
             Code.string_to_quoted!("def features(_opts), do: [extensions: [\".ex\"]]")
           ) == []
  end

  test "SELF-PROOF RED: a plugins: entry naming a nonexistent module trips the config law" do
    plugin_config = """
    [
      inputs: ["{mix,.formatter}.exs"],
      plugins: [AshSurface.Resource, AshSurface.Event]
    ]
    """

    ast = Code.string_to_quoted!(plugin_config)

    assert [AshSurface.Resource, AshSurface.Event] = registered_plugins(ast)
    assert unknown_module?(AshSurface.Resource)
    refute unknown_module?(AshSurface.Event)

    assert [violation] = scan_ast(ast, ".formatter.exs")
    assert violation =~ "AshSurface.Resource"
    refute violation =~ "AshSurface.Event"
  end
end
