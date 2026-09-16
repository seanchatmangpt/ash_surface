defmodule AshSurface.RefactorSafetyNetTest do
  @moduledoc """
  Refactor safety net — the integration canary (ticket refactor-safety-net-003).

  The chicago zero-config test wave (t01-t40) landed 40 law suites through a
  40-branch merge. A merge that silently drops a file compiles green and passes
  every surviving suite — the loss is invisible until someone reaches for the
  law that is no longer there. This canary makes the drop loud: every
  load-bearing chicago-wave suite is pinned here by short name and canonical
  path, and any missing file breaks the build immediately.

  Law under test: each load-bearing suite EXISTS at its canonical path.

  ## The canon (short name -> canonical path -> law)

    * `transport_select`    -> transport_select_test.exs    -> transport law: selector
    * `transport_fallback`  -> transport_fallback_test.exs  -> transport law: fallback ladder
    * `transport_outcome`   -> transport_outcome_test.exs   -> transport law: outcome states
    * `transport_falsifiers`-> transport_falsifiers_test.exs-> transport law: falsifiers
    * `digest`              -> digest_test.exs               -> SHA-256 cross-language digest law
    * `golden_stability`    -> action_id_test.exs            -> frozen golden id stability law
    * `validator`           -> resource/validator_test.exs   -> resource validator law
    * `validator_adversarial`-> resource/validator_adversarial_test.exs -> adversarial validator falsifiers

  `golden_stability` is the suite whose own header freezes the golden tables
  and names "the action_id stability law"; it lives at `action_id_test.exs`.

  Renames are legal but must be conscious: update the canon table in the same
  change, or this canary fails. Deletions are refused — a chicago law suite
  may only be removed by removing its law.
  """

  use ExUnit.Case, async: true

  # {short name, canonical path (from test/), law one-liner}
  @canon [
    {"transport_select", "ash_surface/transport_select_test.exs", "transport law: selector"},
    {"transport_fallback", "ash_surface/transport_fallback_test.exs",
     "transport law: fallback ladder"},
    {"transport_outcome", "ash_surface/transport_outcome_test.exs",
     "transport law: outcome states"},
    {"transport_falsifiers", "ash_surface/transport_falsifiers_test.exs",
     "transport law: falsifiers"},
    {"digest", "ash_surface/digest_test.exs", "SHA-256 cross-language digest law"},
    {"golden_stability", "ash_surface/action_id_test.exs", "frozen golden id stability law"},
    {"validator", "ash_surface/resource/validator_test.exs", "resource validator law"},
    {"validator_adversarial", "ash_surface/resource/validator_adversarial_test.exs",
     "adversarial validator falsifiers"}
  ]

  test "the canon pins every load-bearing suite exactly once (no shadowed pins)" do
    paths = Enum.map(@canon, fn {_name, path, _law} -> path end)

    assert length(paths) == length(Enum.uniq(paths)),
           "canon table has duplicate paths — a pin is shadowing another"
  end

  for {short_name, path, law} <- @canon do
    test "canary: #{short_name} suite exists at canonical path #{path} (#{law})" do
      absolute = Path.expand(Path.join("../", unquote(path)), __DIR__)

      assert File.exists?(absolute),
             "integration dropped #{unquote(short_name)} (#{unquote(law)}): " <>
               "expected #{unquote(path)} to exist — restore the suite or consciously " <>
               "amend the canon in the same change; never delete a chicago law silently"
    end
  end
end
