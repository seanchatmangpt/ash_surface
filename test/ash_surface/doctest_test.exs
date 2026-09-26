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
    * `AshSurface.Transport` (chicago-doctest-sweep-052) — `select/3`'s
      undelegated preference law, the dimension-weighed frontier (preference
      never picks a dominated alternative), and the typed refusals;
      `facts_from_profile/1`'s normalize/not-delegated/refusal contract.
    * `AshSurface.Standing` — the vocabulary gates: `valid?/1`, `validate!/1`,
      and `refused?/1` (base members are never refusals; `:UNKNOWN` is not a
      standing at all).
    * `AshSurface.MXEpisode.compose/1` — the closed-loop composition over the
      real Observation/PlanningEpisode/Event projections, the frozen
      five-step decomposition witnesses, the subject-binding law, and the
      missing-parts refusal.
    * `AshSurface.Intent.create/3` — the content-addressed triple: pinned
      sha256 id, and time-is-not-identity replay.
    * `AshSurface.Projectors.ARIA.project_ir/2` — the ARIA contract shape and
      the read-never-infer + OBSERVE-only live-region laws.
  """

  use ExUnit.Case, async: true

  doctest AshSurface
  doctest AshSurface.Compiler
  doctest AshSurface.Transport
  doctest AshSurface.Standing
  doctest AshSurface.MXEpisode
  doctest AshSurface.Intent
  doctest AshSurface.Projectors.ARIA
end
