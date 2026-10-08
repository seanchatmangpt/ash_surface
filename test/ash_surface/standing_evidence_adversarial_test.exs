defmodule AshSurface.StandingEvidenceAdversarialTest do
  @moduledoc """
  Adversarial standing-evidence court: fabricated evidence claims must be
  refused with exact typed errors, never silently carried, widened, or
  re-labeled.

  Exercises the REAL constructors (`AshSurface.Observation.create/3`) and the
  REAL vocabulary owner (`AshSurface.Standing`) — no test doubles. The
  adversarial corpus:

    * bare `:REFUSED` (an unnamed refusal is a fabricated refusal),
    * `:UNKNOWN` (a post-dispatch transport outcome, never a standing),
    * off-vocabulary atoms, strings, and non-atom garbage,
    * a synthetic `REFUSED_*` member no consumer ever emitted (prefix law),
  plus the positive side: admitted evidence survives `create/3` unchanged —
  the constructor must carry the caller's standing, not rewrite it.
  """

  use ExUnit.Case, async: true

  alias AshSurface.Observation
  alias AshSurface.Standing

  @admitted_vocabulary "[:ALIVE, :PARTIAL_ALIVE, :BLOCKED, :BUILD_BROKEN, :UNSUPPORTED]"

  defp off_vocabulary_message(standing) do
    "invalid standing #{inspect(standing)}; admitted standings are #{@admitted_vocabulary} " <>
      "plus the REFUSED class (every :\"REFUSED_*\" atom — a refusal must name its reason)"
  end

  # ---- adversarial corpus -------------------------------------------------

  describe "adversarial: fabricated evidence is refused at the constructor boundary" do
    test "bare :REFUSED evidence cannot enter an Observation" do
      assert_raise ArgumentError, off_vocabulary_message(:REFUSED), fn ->
        Observation.create("subject-x", %{"k" => "v"}, standing: :REFUSED)
      end
    end

    test ":UNKNOWN evidence cannot enter an Observation" do
      assert_raise ArgumentError, ~r/UNKNOWN is a post-dispatch outcome/, fn ->
        Observation.create("subject-x", %{"k" => "v"}, standing: :UNKNOWN)
      end
    end

    @tag :w326_off_vocabulary
    test "off-vocabulary atoms, strings, and garbage are all refused" do
      corpus = [:BOGUS, :ALIVE_UPGRADED, "ALIVE", "REFUSED_NO_AUTHORITY", 42, nil, %{}, []]

      for offender <- corpus do
        assert_raise ArgumentError, off_vocabulary_message(offender), fn ->
          Observation.create("subject-x", %{}, standing: offender)
        end
      end
    end

    test "a valid REFUSED_* atom IS admissible evidence and survives unchanged" do
      obs = Observation.create("subject-x", %{"k" => "v"}, standing: :REFUSED_EVIDENCE_MISSING)

      assert obs.standing == :REFUSED_EVIDENCE_MISSING
      assert Standing.valid?(:REFUSED_EVIDENCE_MISSING)
      assert Standing.refused?(:REFUSED_EVIDENCE_MISSING)
    end

    test "synthetic REFUSED member no consumer ever emitted is admitted by prefix law" do
      synthetic = :"REFUSED_W326_ADVERSARIAL_PROBE_#{System.unique_integer([:positive])}"

      assert Standing.valid?(synthetic)
      obs = Observation.create("subject-x", %{}, standing: synthetic)
      assert obs.standing == synthetic
    end

    test "an :ALIVE claim is carried verbatim — no silent widening or rewrite" do
      obs = Observation.create("subject-x", %{"k" => "v"}, standing: :PARTIAL_ALIVE)

      assert obs.standing == :PARTIAL_ALIVE
      assert Standing.validate!(obs.standing) == obs.standing
    end

    test "validate! round trip is identity for every admitted base standing" do
      for standing <- Standing.base_standings() do
        assert Standing.validate!(standing) == standing
        assert Standing.valid?(standing)
        refute Standing.refused?(standing)
      end
    end
  end
end
