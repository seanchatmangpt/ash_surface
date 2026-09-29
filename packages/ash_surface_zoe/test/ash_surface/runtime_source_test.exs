defmodule AshSurfaceZoe.RuntimeSourceTest do
  @moduledoc """
  Law pinned: the package's JavaScript is ordinary JavaScript + JSDoc + Zod
  (never TypeScript), exports the human-surface schema surface that moved out
  of core, and reaches core's runtime only by the bare `"ash_surface"` name.
  """
  use ExUnit.Case, async: true

  test "exports the human-surface schemas and parser that left the core runtime" do
    assert {:ok, source} = AshSurfaceZoe.runtime_source()

    exported =
      ~r/^export\s+(?:const|function|class)\s+([A-Za-z_$][\w$]*)/m
      |> Regex.scan(source, capture: :all_but_first)
      |> List.flatten()

    for name <-
          ~w(humanSurfaceSchema parseHumanSurfaceProjection possibilitySchema possibilitySetSchema
             whyThisSchema outcomeHypothesisSchema devotionalEpisodeSchema commitmentBoundarySchema
             journeySchema personalizationContextSchema manufactureTraceSchema) do
      assert name in exported, "package no longer exports #{name}"
    end

    assert Enum.uniq(exported) == exported
  end

  test "is TypeScript-free and imports core by package name only" do
    assert {:ok, source} = AshSurfaceZoe.runtime_source()
    assert String.ends_with?(AshSurfaceZoe.runtime_path(), ".mjs")
    refute source =~ ~r/^\s*(export\s+)?(interface|type)\s+\w+\s*(=|\{)/m
    refute source =~ ~r/\bimport\s+type\b/
    assert source =~ ~s|from "zod"|
    assert source =~ ~s|import { SurfaceRuntimeError } from "ash_surface";|
    refute source =~ ~r/from\s+"\.\.?\//
  end

  test "core's runtime no longer carries the human-surface schemas (no back-dependency)" do
    assert {:ok, core} = AshSurface.runtime_source()
    refute core =~ "humanSurfaceSchema"
    refute core =~ "parseHumanSurfaceProjection"
  end
end
