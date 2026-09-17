defmodule AshSurface.StandingTest do
  @moduledoc """
  chicago-standing-table-029: exhaustive state table for the standing
  vocabulary (F3, single canonical owner: `AshSurface.Standing`).

  Exercises the REAL subject — no test doubles. The table covers:

    * every admitted base standing (all 5): valid, not a refusal, and a
      `validate!/1` identity round trip,
    * the whole open REFUSED class as witnessed in the repo plus a synthetic
      member no consumer has ever emitted (prefix law is the exhaustiveness
      argument for an open class),
    * the bare `:REFUSED` boundary: an unnamed refusal is a fabricated
      refusal and is rejected,
    * the `:UNKNOWN` boundary: rejected with the exact message naming it as
      a post-dispatch outcome,
    * the constructor contract: `Observation`, `PlanningEpisode` and `Event`
      refusals fire with their exact ArgumentError messages.
  """

  use ExUnit.Case, async: true

  alias AshSurface.Event
  alias AshSurface.Observation
  alias AshSurface.PlanningEpisode
  alias AshSurface.Standing

  @base_standings [:ALIVE, :PARTIAL_ALIVE, :BLOCKED, :BUILD_BROKEN, :UNSUPPORTED]

  # The REFUSED class is open (prefix law), so the table enumerates every
  # REFUSED_* atom witnessed anywhere in the repo plus one synthetic member —
  # admission of the synthetic proves the class is open, not a closed list.
  @refused_class [
    :REFUSED_NO_AUTHORITY,
    :REFUSED_UNKNOWN_ACTION,
    :REFUSED_UNKNOWN_SUBJECT,
    :REFUSED_UNKNOWN_OPTION,
    :REFUSED_UNKNOWN_REVERSIBILITY,
    :REFUSED_INVALID_SUBJECT,
    :REFUSED_INVALID_OPTION,
    :REFUSED_EVIDENCE_REQUIRED,
    :REFUSED_EVIDENCE_MISSING,
    :REFUSED_GENERATOR_OWNED,
    :REFUSED_NOT_DO_BOUNDARY,
    # Synthetic: never emitted by any consumer; admitted by the prefix law.
    :REFUSED_SESSION_LAW
  ]

  @admitted_vocabulary "[:ALIVE, :PARTIAL_ALIVE, :BLOCKED, :BUILD_BROKEN, :UNSUPPORTED]"

  # Exact boundary message for :UNKNOWN — these bytes ARE the contract: the
  # refusal must name :UNKNOWN as a post-dispatch outcome (UNKNOWN_AFTER_
  # DISPATCH, a transport outcome), never let it read as a verified standing.
  @unknown_message "invalid standing :UNKNOWN; UNKNOWN is a post-dispatch outcome " <>
                     "(recorded as UNKNOWN_AFTER_DISPATCH, a transport outcome), never a " <>
                     "verified standing; admitted standings are #{@admitted_vocabulary} " <>
                     "plus the REFUSED class (every :\"REFUSED_*\" atom)"

  # Exact boundary message for every off-vocabulary offender: names the
  # offender and the admitted vocabulary, and states the name-your-reason law.
  defp off_vocabulary_message(standing) do
    "invalid standing #{inspect(standing)}; admitted standings are #{@admitted_vocabulary} " <>
      "plus the REFUSED class (every :\"REFUSED_*\" atom — a refusal must name its reason)"
  end

  defp refute_message(standing) do
    "invalid PlanningEpisode policy_standing #{inspect(standing)}; " <>
      "admitted standings are [:VALID_STRONG, :VALID_STRONG_CYCLIC, :REFUSED]"
  end

  describe "state table: base standings (all 5 valid)" do
    test "the vocabulary is exactly the five base members, in canonical order" do
      assert Standing.base_standings() == @base_standings
    end

    test "every base member is valid, not a refusal, and survives validate! unchanged" do
      for standing <- @base_standings do
        assert Standing.valid?(standing), "#{inspect(standing)} must be valid"
        refute Standing.refused?(standing), "#{inspect(standing)} is not a refusal"
        assert Standing.validate!(standing) == standing
      end
    end
  end

  describe "state table: REFUSED class" do
    test "every REFUSED_* atom (witnessed + synthetic) is valid, a refusal, and survives validate!" do
      for standing <- @refused_class do
        assert Standing.valid?(standing), "#{inspect(standing)} must be admitted"
        assert Standing.refused?(standing), "#{inspect(standing)} must classify as a refusal"
        assert Standing.validate!(standing) == standing
      end
    end

    test "bare :REFUSED is rejected — an unnamed refusal is a fabricated refusal" do
      refute Standing.valid?(:REFUSED)
      refute Standing.refused?(:REFUSED)

      error = assert_raise ArgumentError, fn -> Standing.validate!(:REFUSED) end

      assert Exception.message(error) == off_vocabulary_message(:REFUSED)
    end

    test "the prefix is exact: refused-ish atoms outside the class are not admitted" do
      for impostor <- [:REFUSEDISH, :AUTHORITY_REFUSED, :NOT_REFUSED_X] do
        refute Standing.valid?(impostor), "#{inspect(impostor)} must not be admitted"
      end

      refute Standing.refused?(:ALIVE)
    end
  end

  describe "state table: :UNKNOWN boundary" do
    test ":UNKNOWN is not a standing and is refused as a post-dispatch outcome" do
      refute Standing.valid?(:UNKNOWN)
      refute Standing.refused?(:UNKNOWN)

      error = assert_raise ArgumentError, fn -> Standing.validate!(:UNKNOWN) end

      assert Exception.message(error) == @unknown_message
    end

    test "UNKNOWN_AFTER_DISPATCH is a transport outcome, not a standing either" do
      refute Standing.valid?(:UNKNOWN_AFTER_DISPATCH)
    end
  end

  describe "state table: off-vocabulary refusals" do
    test "off-vocabulary atoms are refused with the exact boundary message" do
      for bad <- [:BOGUS, :ALIVEISH, :VALID_STRONG] do
        refute Standing.valid?(bad)

        error = assert_raise ArgumentError, fn -> Standing.validate!(bad) end

        assert Exception.message(error) == off_vocabulary_message(bad)
      end
    end

    test "non-atoms are refused, never coerced" do
      for bad <- ["ALIVE", "REFUSED_NO_AUTHORITY", 7, nil, %{}, {:ALIVE}] do
        refute Standing.valid?(bad)

        error = assert_raise ArgumentError, fn -> Standing.validate!(bad) end

        assert Exception.message(error) == off_vocabulary_message(bad)
      end
    end
  end

  describe "state table: constructor refusals fire with exact messages" do
    @subject "zoe:KingdomNeed#need_42"
    @facts %{"need_status" => "active"}

    test "Observation.create refuses :UNKNOWN with the exact post-dispatch message" do
      error =
        assert_raise ArgumentError, fn ->
          Observation.create(@subject, @facts, standing: :UNKNOWN)
        end

      assert Exception.message(error) == @unknown_message
    end

    test "Observation.create refuses bare :REFUSED with the exact unnamed-refusal message" do
      error =
        assert_raise ArgumentError, fn ->
          Observation.create(@subject, @facts, standing: :REFUSED)
        end

      assert Exception.message(error) == off_vocabulary_message(:REFUSED)
    end

    test "Observation.create refuses off-vocabulary atoms with the exact message" do
      error =
        assert_raise ArgumentError, fn ->
          Observation.create(@subject, @facts, standing: :BOGUS)
        end

      assert Exception.message(error) == off_vocabulary_message(:BOGUS)
    end

    test "Observation.create admits every base standing and a named refusal" do
      for standing <- @base_standings ++ [:REFUSED_NO_AUTHORITY] do
        obs = Observation.create(@subject, @facts, standing: standing)

        assert obs.standing == standing
        assert Observation.to_map(obs)["standing"] == to_string(standing)
      end
    end

    test "PlanningEpisode.create refuses off-vocabulary policy standings with the exact message" do
      # :ALIVE is a lawful AshSurface.Standing but NOT a policy standing — the
      # two vocabularies are distinct, and neither smuggles into the other.
      for bad <- [:DOUGH, :ALIVE] do
        error =
          assert_raise ArgumentError, fn ->
            PlanningEpisode.create("ws:1",
              planner_identity: "planner:v1",
              policy_identity: "policy:v1",
              policy_standing: bad
            )
          end

        assert Exception.message(error) == refute_message(bad)
      end
    end

    test "PlanningEpisode.create admits :REFUSED — the policy vocabulary names its own outcome" do
      ep =
        PlanningEpisode.create("ws:1",
          planner_identity: "planner:v1",
          policy_identity: "policy:v1",
          policy_standing: :REFUSED
        )

      assert ep.policy_standing == :REFUSED
    end

    test "PlanningEpisode.create refuses a :DO ceiling with the exact message" do
      error =
        assert_raise ArgumentError, fn ->
          PlanningEpisode.create("ws:1",
            planner_identity: "planner:v1",
            policy_identity: "policy:v1",
            authority_ceiling: :DO
          )
        end

      assert Exception.message(error) ==
               "PlanningEpisode authority_ceiling can never be :DO or any value outside " <>
                 "[:SELECT, :CONSTRUCT], got: :DO (Planner != DO)"
    end

    test "Event.create refuses a nil subject_ref with the exact message" do
      error = assert_raise ArgumentError, fn -> Event.create(nil, 1, "type") end

      assert Exception.message(error) ==
               "Event.create/4 requires a non-empty binary subject_ref, got: nil"
    end

    test "Event.create refuses an empty event_type with the exact message" do
      error = assert_raise ArgumentError, fn -> Event.create("s:1", 1, "") end

      assert Exception.message(error) ==
               "Event.create/4 requires a non-empty binary event_type, got: \"\""
    end

    test "Event.create refuses a non-binary event_type with the exact message" do
      error = assert_raise ArgumentError, fn -> Event.create("s:1", 1, :updated) end

      assert Exception.message(error) ==
               "Event.create/4 requires a non-empty binary event_type, got: :updated"
    end
  end
end
