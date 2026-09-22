defmodule AshSurface.ZoeDemoTest do
  use ExUnit.Case, async: true

  alias AshSurface.ZoeDemo

  test "Wednesday demo fixture closes every local human-surface acceptance edge" do
    assert ZoeDemo.acceptance() == %{
             "continuousDevotional" => true,
             "pluralDfcmFrontier" => true,
             "whyThisPresent" => true,
             "outcomeHypothesisNonCausal" => true,
             "commitmentStopsBeforeDo" => true,
             "journeyPrivate" => true,
             "humanAreas" => true,
             "syntheticOnly" => true
           }
  end

  test "demo presents four lawful options rather than a single recommendation" do
    map = ZoeDemo.map()
    [frontier] = map["possibilitySets"]

    assert frontier["mode"] == "MAXIMAL_REVERSIBLE_FRONTIER"
    assert frontier["standing"] == "ALIVE"
    assert length(frontier["possibilities"]) == 4

    assert Enum.map(frontier["possibilities"], & &1["label"]) == [
             "Listen to today's devotional",
             "Read instead",
             "Explore serving this week",
             "Keep my current rhythm"
           ]

    assert Enum.all?(frontier["possibilities"], &(&1["doAuthority"] == false))
  end

  test "demo devotional is one ordered straight-through episode" do
    map = ZoeDemo.map()
    [episode] = map["devotionalEpisodes"]

    assert episode["continuousPlay"] == true
    assert episode["playbackPolicy"] == "STRAIGHT_THROUGH"
    assert episode["durationSeconds"] == 445

    assert Enum.map(episode["segments"], & &1["kind"]) == [
             "SCRIPTURE",
             "TRANSITION",
             "SCRIPTURE",
             "REFLECTION"
           ]
  end

  test "demo Life surface makes uncertainty explicit" do
    map = ZoeDemo.map()
    [hypothesis] = map["outcomeHypotheses"]
    [explanation] = map["explanations"]

    assert map["life"]["causalClaimsAdmitted"] == false
    assert hypothesis["evidenceState"] == "UNKNOWN"
    assert hypothesis["causalClaim"] == false
    assert is_binary(hypothesis["falsifier"])
    assert explanation["claimKind"] == "HYPOTHESIS"
    assert explanation["evidenceState"] == "UNKNOWN"
    assert is_binary(explanation["falsifier"])
  end

  test "demo commitment cannot bypass BRCE even after a human chooses" do
    map = ZoeDemo.map()
    [boundary] = map["commitmentBoundaries"]

    assert boundary["confirmationRequired"] == true
    assert boundary["confirmationState"] == "UNCONFIRMED"
    assert boundary["authorityCeiling"] == "CONSTRUCT"
    assert boundary["nextHandoff"] == "BRCE"
    assert boundary["doAuthority"] == false
  end

  test "demo Journey keeps personal replay subject-private" do
    map = ZoeDemo.map()
    [journey] = map["journeys"]

    assert journey["privacyScope"] == "SUBJECT_PRIVATE"
    assert journey["authorityBoundary"] == "OBSERVE"
    assert journey["doAuthority"] == false
    assert length(journey["entries"]) == 3
  end

  test "demo top-level surface exposes exact human grammar and areas" do
    map = ZoeDemo.map()

    assert map["grammar"] == ["SEE", "UNDERSTAND", "EXPLORE", "CHOOSE", "ACT", "LEARN"]
    assert map["areas"] == ["TODAY", "BIBLE", "LIFE", "ZOE", "YOU"]
    assert map["authorityBoundary"] == "OBSERVE"
    assert map["doAuthority"] == false
    assert map["zoe"]["liveProviderReads"] == false
  end
end
