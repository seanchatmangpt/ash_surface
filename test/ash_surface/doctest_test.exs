defmodule AshSurface.DoctestTest do
  @moduledoc """
  Runs the repo's IEx doctests (gapfix-test-surface-015: the repo had zero
  doctest entries). The examples live on the boundary modules' own docs:

    * `AshSurface.from_manifest/2` — the empty-manifest surface build with a
      projection profile, plus the unknown-action-profile refusal.
    * `AshSurface.Compiler.compile/1` and `compile/2` — the fail-closed gates:
      the missing default section adapters, the empty `:sections` refusal, and
      the partial-binding refusal that names the missing keys. The compile
      success path needs all five section doubles and is covered (with real
      doubles) in `AshSurface.CompilerTest`; doc examples cannot reference
      test doubles, so the docs pin the refusals that ARE the module's
      documented law.
  """

  use ExUnit.Case, async: true

  doctest AshSurface
  doctest AshSurface.Compiler
end
