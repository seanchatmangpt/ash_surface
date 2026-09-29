defmodule AshSurface.HumanProjectionCoverageTest do
  @moduledoc """
  Construction laws of the human-facing projections — DevotionalEpisode,
  Journey, OutcomeHypothesis, WhyThis — beyond the happy path pinned in
  human_surface_test.exs: default-option construction yields the documented
  defaults, string-dialect vocabulary is normalized to the same identity as the
  atom dialect, DateTime timestamps project to ISO-8601, and every malformed
  input (unknown vocabulary, missing/empty refs, non-map entries, non-string
  ref lists, duplicate identities, negative durations) is refused with an
  ArgumentError naming the violated law — never silently projected.
  """

  use ExUnit.Case, async: true

  alias AshSurface.{DevotionalEpisode, Journey, OutcomeHypothesis, WhyThis}

  describe "DevotionalEpisode" do
    @segment %{kind: :SCRIPTURE, ref: "bible:John.3.16", duration_seconds: 30}

    test "create/2 uses defaults and sums segment durations" do
      episode = DevotionalEpisode.create("Morning", [@segment, %{@segment | ref: "b:2"}])

      assert episode.status == :READY
      assert episode.duration_seconds == 60
      assert episode.hypothesis_refs == []
      assert DevotionalEpisode.to_map(episode)["doAuthority"] == false
    end

    test "string segment kinds normalize to the atom-kind identity" do
      atom_kind = DevotionalEpisode.create("M", [@segment])
      string_kind = DevotionalEpisode.create("M", [%{@segment | kind: "scripture"}])

      assert string_kind.episode_id == atom_kind.episode_id
      assert string_kind.state_digest == atom_kind.state_digest
      assert hd(string_kind.segments)["kind"] == "SCRIPTURE"
    end

    test "a string kind naming an existing but non-segment atom is refused" do
      assert_raise ArgumentError, "unknown devotional segment kind: :READY", fn ->
        DevotionalEpisode.create("M", [%{@segment | kind: "ready"}])
      end
    end

    test "a kind that is neither atom nor string is refused by position" do
      assert_raise ArgumentError, "segment 1 requires kind", fn ->
        DevotionalEpisode.create("M", [@segment, %{kind: 7, ref: "b:2"}])
      end
    end

    test "an absent kind is refused by position, not as an unknown nil kind" do
      assert_raise ArgumentError, "segment 1 requires kind", fn ->
        DevotionalEpisode.create("M", [@segment, %{ref: "b:2"}])
      end
    end

    test "a string kind naming no existing atom is an unknown kind, never a fresh atom" do
      kind = "zz_never_an_atom_#{System.unique_integer([:positive])}"

      assert_raise ArgumentError, "unknown devotional segment kind: #{inspect(kind)}", fn ->
        DevotionalEpisode.create("M", [%{@segment | kind: kind}])
      end
    end

    test "an unknown atom kind is refused" do
      assert_raise ArgumentError, "unknown devotional segment kind: :SERMON", fn ->
        DevotionalEpisode.create("M", [%{@segment | kind: :SERMON}])
      end
    end

    test "an empty ref is refused" do
      assert_raise ArgumentError, "segment 0 requires non-empty ref", fn ->
        DevotionalEpisode.create("M", [%{@segment | ref: ""}])
      end
    end

    test "a negative segment duration is refused" do
      assert_raise ArgumentError, "segment 0 duration must be non-negative integer", fn ->
        DevotionalEpisode.create("M", [%{@segment | duration_seconds: -5}])
      end
    end

    test "a non-map segment is refused by position" do
      assert_raise ArgumentError, "segment 0 must be a map", fn ->
        DevotionalEpisode.create("M", ["bible:John.3.16"])
      end
    end

    test "an explicit negative total duration is refused" do
      assert_raise ArgumentError, "duration_seconds must be a non-negative integer", fn ->
        DevotionalEpisode.create("M", [@segment], duration_seconds: -1)
      end
    end

    test "ref lists must be lists of strings" do
      assert_raise ArgumentError, "hypothesis_refs must contain only strings", fn ->
        DevotionalEpisode.create("M", [@segment], hypothesis_refs: [:hyp])
      end

      assert_raise ArgumentError, "source_refs must be a list", fn ->
        DevotionalEpisode.create("M", [@segment], source_refs: "src:1")
      end
    end
  end

  describe "Journey" do
    @entry %{
      kind: :PRACTICE,
      subject_ref: "practice:1",
      label: "Prayed",
      occurred_at: "2026-09-28T07:00:00Z"
    }

    test "create/2 uses defaults and assigns a content-addressed entry id" do
      journey = Journey.create("person:demo", [@entry])

      assert journey.standing == :PARTIAL_ALIVE
      assert [%{"entryId" => "je_" <> _, "standing" => "ALIVE"}] = journey.entries
      assert Journey.to_map(journey)["privacyScope"] == "SUBJECT_PRIVATE"
    end

    test "a DateTime occurred_at projects to the same identity as its ISO-8601 string" do
      from_string = Journey.create("person:demo", [@entry])

      from_datetime =
        Journey.create("person:demo", [%{@entry | occurred_at: ~U[2026-09-28 07:00:00Z]}])

      assert hd(from_datetime.entries)["occurredAt"] == "2026-09-28T07:00:00Z"
      assert from_datetime.journey_id == from_string.journey_id
    end

    test "string kinds normalize to the atom-kind identity" do
      assert Journey.create("s", [%{@entry | kind: "practice"}]).state_digest ==
               Journey.create("s", [@entry]).state_digest
    end

    test "duplicate entry identities are refused" do
      assert_raise ArgumentError, "journey entry ids must be unique", fn ->
        Journey.create("s", [@entry, @entry])
      end
    end

    test "an entry kind naming no existing atom is refused as an unknown journey kind" do
      kind = "zz_never_an_atom_#{System.unique_integer([:positive])}"

      assert_raise ArgumentError, "unknown journey kind: #{inspect(kind)}", fn ->
        Journey.create("s", [%{@entry | kind: kind}])
      end
    end

    test "an occurred_at that is neither DateTime nor string is a named refusal" do
      assert_raise ArgumentError,
                   "occurred_at must be a DateTime or ISO-8601 string, got: 1727000000",
                   fn -> Journey.create("s", [%{@entry | occurred_at: 1_727_000_000}]) end
    end

    test "an unknown journey standing is refused" do
      assert_raise ArgumentError, "unknown standing: :GLORIOUS", fn ->
        Journey.create("s", [@entry], standing: :GLORIOUS)
      end
    end

    test "an unknown entry standing is refused" do
      assert_raise ArgumentError, "unknown journey standing: :GLORIOUS", fn ->
        Journey.create("s", [Map.put(@entry, :standing, :GLORIOUS)])
      end
    end

    test "a non-map entry is refused" do
      assert_raise ArgumentError, "journey entry must be a map", fn ->
        Journey.create("s", [:entry])
      end
    end

    test "an entry missing a required key is refused by key" do
      assert_raise ArgumentError, "journey entry missing label", fn ->
        Journey.create("s", [Map.delete(@entry, :label)])
      end
    end

    test "ref lists must be lists of strings" do
      assert_raise ArgumentError, "evidence_refs must contain only strings", fn ->
        Journey.create("s", [Map.put(@entry, :evidence_refs, [1])])
      end

      assert_raise ArgumentError, "receipt_refs must be a list", fn ->
        Journey.create("s", [@entry], receipt_refs: "rcpt:1")
      end
    end
  end

  describe "OutcomeHypothesis" do
    test "create/3 without options is refused: a falsifier is mandatory" do
      assert_raise KeyError, fn -> OutcomeHypothesis.create("s", "p", "o") end
    end

    test "an unknown relationship is refused — CAUSES is not in the vocabulary" do
      assert_raise ArgumentError, "unknown relationship: :CAUSES", fn ->
        OutcomeHypothesis.create("s", "p", "o", falsifier: "f", relationship: :CAUSES)
      end
    end

    test "an unknown evidence_state is refused" do
      assert_raise ArgumentError, "unknown evidence_state: :PROVEN", fn ->
        OutcomeHypothesis.create("s", "p", "o", falsifier: "f", evidence_state: :PROVEN)
      end
    end

    test "an empty falsifier is refused" do
      assert_raise ArgumentError, "falsifier must be a non-empty string", fn ->
        OutcomeHypothesis.create("s", "p", "o", falsifier: "")
      end
    end

    test "ref lists must be lists of strings" do
      assert_raise ArgumentError, "evidence_refs must contain only strings", fn ->
        OutcomeHypothesis.create("s", "p", "o", falsifier: "f", evidence_refs: [:e])
      end

      assert_raise ArgumentError, "observation_refs must be a list", fn ->
        OutcomeHypothesis.create("s", "p", "o", falsifier: "f", observation_refs: "obs")
      end
    end
  end

  describe "WhyThis" do
    test "create/3 defaults to a HYPOTHESIS claim, which requires a falsifier" do
      assert_raise ArgumentError, "HYPOTHESIS explanation requires a falsifier", fn ->
        WhyThis.create("s", "Why", "Because")
      end
    end

    test "an unknown claim_kind is refused — FACT is not a claim kind" do
      assert_raise ArgumentError, "unknown claim_kind: :FACT", fn ->
        WhyThis.create("s", "Why", "Because", claim_kind: :FACT)
      end
    end

    test "an unknown evidence_state is refused" do
      assert_raise ArgumentError, "unknown evidence_state: :PROVEN", fn ->
        WhyThis.create("s", "Why", "Because", claim_kind: :OBSERVATION, evidence_state: :PROVEN)
      end
    end

    test "every ref list must be a list of strings" do
      assert_raise ArgumentError, "caveats must contain only strings", fn ->
        WhyThis.create("s", "Why", "Because", claim_kind: :USER_STATED, caveats: [:c])
      end

      assert_raise ArgumentError, "basis must be a list", fn ->
        WhyThis.create("s", "Why", "Because", claim_kind: :USER_STATED, basis: "b")
      end
    end
  end
end
