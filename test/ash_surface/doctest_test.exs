defmodule AshSurface.DoctestTest do
  @moduledoc """
  Runs the repo's IEx doctests (gapfix-test-surface-015: the repo had zero
  doctest entries). The examples live on the boundary modules' own docs:

    * `AshSurface.from_manifest/2` — the empty-manifest surface build with a
      projection profile, plus the unknown-action-profile refusal.
    * `AshSurface.Compiler.compile/1` and `compile/2` — the fail-closed gates:
      the empty `:sections` refusal, the partial-binding refusal that names
      the missing keys, and (since the default adapters landed,
      gapfix-adapters-001) the empty-manifest success shape `{:ok, []}` — the
      example that previously pinned the missing-adapters refusal
      (`{:invalid_section_module, ...}`) was re-pinned at integration when
      that refusal became unreachable through the defaults. The compile
      success path over real sections needs all five section doubles and is
      covered (with real doubles) in `AshSurface.CompilerTest`; doc examples
      cannot reference test doubles, so the docs pin the laws that ARE the
      module's documented surface.
  """

  use ExUnit.Case, async: true

  doctest AshSurface
  doctest AshSurface.Compiler
end
