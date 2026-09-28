defmodule AshSurfaceZoe.NoLocalDoTest do
  @moduledoc """
  Law pinned (carried over from core's `AshSurface.NoLocalDoTest` when the ZOE
  family left core): "AshSurface does not determine whether it may DO."

  Every file under this package's `lib/` is walked as an AST. The human-surface
  family are plain in-memory struct constructors (`create/2..4` returning
  `%__MODULE__{}`), so none may call Ash `create/update/destroy/calculate/...`
  on a non-family module, spawn/Task, or bind `do_authority` locally.
  """

  use ExUnit.Case, async: true

  @lib Path.expand("../../lib", __DIR__)
  @files Path.wildcard(Path.join(@lib, "**/*.ex")) |> Enum.sort()

  @family ~w(HumanSurface PersonalizationContext Possibility PossibilitySet CommitmentBoundary
             DevotionalEpisode Journey ManufactureTrace OutcomeHypothesis WhyThis)a

  @action_funs ~w(create update destroy calculate bulk_create bulk_update bulk_destroy
                  run_action execute_action)a
  @process_funs ~w(spawn spawn_link spawn_monitor spawn_opt send send_after exit hibernate)a

  defp asts do
    for file <- @files, do: {file, file |> File.read!() |> Code.string_to_quoted!()}
  end

  defp remote_calls(ast) do
    {_, acc} =
      Macro.prewalk(ast, [], fn
        {{:., _, [{:__aliases__, _, parts}, fun]}, _, args} = node, acc when is_atom(fun) ->
          {node, [{parts, fun, length(args)} | acc]}

        node, acc ->
          {node, acc}
      end)

    acc
  end

  test "the walk is real: all eleven family modules, the namespace and the projector are parsed" do
    assert length(@files) == 13
  end

  test "no Ash action call on a non-family module" do
    offenders =
      for {file, ast} <- asts(),
          {parts, fun, _} <- remote_calls(ast),
          fun in @action_funs,
          not (List.last(parts) in @family or parts in [[:AshSurface, :Vocabulary]]),
          do: {Path.basename(file), Enum.join(parts, "."), fun}

    assert offenders == []
  end

  test "no Task / process spawning anywhere in the package" do
    offenders =
      for {file, ast} <- asts(),
          {parts, fun, _} <- remote_calls(ast),
          List.last(parts) == :Task or
            (parts in [[:Process], [:Kernel], [:erlang]] and fun in @process_funs),
          do: {Path.basename(file), Enum.join(parts, "."), fun}

    assert offenders == []
  end

  test "no local do_authority derivation (DO-ness is read, never computed)" do
    offenders =
      for {file, ast} <- asts(),
          {:do_authority, _, ctx} <-
            Macro.prewalk(ast, [], fn n, a -> {n, [n | a]} end) |> elem(1),
          is_atom(ctx),
          do: Path.basename(file)

    assert offenders == []
  end
end
