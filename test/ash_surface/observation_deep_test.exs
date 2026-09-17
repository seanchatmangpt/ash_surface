defmodule AshSurface.ObservationDeepTest do
  @moduledoc """
  Deep invariants of AshSurface.Observation beyond the construction smoke test:

    * observed-state vs domain-state separation (an observation never carries authority),
    * digest/subject reference consistency (content addressing is deterministic, bound,
      and non-injectable),
    * projection into consumer-visible shapes (exact key set, pure read),
    * rejection of malformed inputs,
    * golden serialization vectors pinning the wire format byte-for-byte.
  """

  use ExUnit.Case, async: true
  alias AshSurface.Observation

  @subject "zoe:KingdomNeed#need_42"

  @facts %{
    "need_status" => "active",
    "open_opportunities" => 3,
    "unassigned_roles" => ["care_driver", "intercessor"]
  }

  @vector_time ~U[2026-01-15 12:00:00Z]

  # sha256("zoe:KingdomNeed#need_42:" <> Jason.encode!(@facts)), hex-lower — recorded 2026-09-15.
  @golden_digest "efbe29ff13c210909d01033247ba6bf04fc47ea616cccd4c32460210d3adb94a"
  @golden_id "obs_efbe29ff13c21090"

  @golden_json """
  {"authorityBoundary":"OBSERVE","evidenceRefs":["ev_1","ev_2"],"exactSubject":"zoe:KingdomNeed#need_42","facts":{"need_status":"active","open_opportunities":3,"unassigned_roles":["care_driver","intercessor"]},"observationId":"obs_efbe29ff13c21090","observedAt":"2026-01-15T12:00:00Z","projectionPurpose":"vector_check","standing":"PARTIAL_ALIVE","stateDigest":"efbe29ff13c210909d01033247ba6bf04fc47ea616cccd4c32460210d3adb94a"}\
  """

  describe "observed-state vs domain-state separation" do
    test "authority boundary is pinned to :OBSERVE and cannot be widened through opts" do
      obs =
        Observation.create(@subject, @facts,
          authority_boundary: :ACTUATE,
          standing: :ALIVE
        )

      assert obs.authority_boundary == :OBSERVE
      assert Observation.to_map(obs)["authorityBoundary"] == "OBSERVE"
    end

    test "the struct carries no actuation or credential-bearing fields" do
      obs = Observation.create(@subject, @facts)

      forbidden = [:do, :command, :intent, :authority, :credentials, :token, :actor]

      assert Map.keys(Map.from_struct(obs)) |> Enum.sort() == [
               :authority_boundary,
               :evidence_refs,
               :exact_subject,
               :facts,
               :observation_id,
               :observed_at,
               :projection_purpose,
               :standing,
               :state_digest
             ]

      refute Enum.any?(forbidden, &Map.has_key?(obs, &1))
    end

    test "observed-state keys are enforced: no observation exists without its factual core" do
      assert_raise ArgumentError,
                   ~r/the following keys must also be given when building struct/,
                   fn ->
                     Code.compile_string("%AshSurface.Observation{}")
                   end
    end

    test "projection keeps the boundary at OBSERVE for every standing" do
      for standing <- [:ALIVE, :PARTIAL_ALIVE, :REFUSED, :BLOCKED] do
        obs = Observation.create(@subject, @facts, standing: standing)
        assert Observation.to_map(obs)["authorityBoundary"] == "OBSERVE"
      end
    end
  end

  describe "standing vocabulary admission (F3: one canonical owner)" do
    test "the full canonical vocabulary constructs, including the ledger and refusal classes" do
      for standing <- [
            :ALIVE,
            :PARTIAL_ALIVE,
            :BLOCKED,
            :BUILD_BROKEN,
            :UNSUPPORTED,
            :REFUSED,
            :REFUSED_UNKNOWN_SUBJECT
          ] do
        obs = Observation.create(@subject, @facts, standing: standing)
        assert obs.standing == standing
        assert Observation.to_map(obs)["standing"] == to_string(standing)
      end
    end

    test "an unvalidated standing claim is refused, never silently carried" do
      for bad <- [:BOGUS, :UNKNOWN, "ALIVE", 7, nil] do
        assert_raise ArgumentError, ~r/invalid standing/, fn ->
          Observation.create(@subject, @facts, standing: bad)
        end
      end
    end
  end

  describe "digest and subject reference consistency" do
    test "digest is deterministic across map ordering and independently recomputable" do
      a = Observation.create(@subject, @facts)
      b = Observation.create(@subject, Map.new(Enum.reverse(Map.to_list(@facts))))

      assert a.state_digest == b.state_digest
      assert a.observation_id == b.observation_id

      recomputed =
        :crypto.hash(:sha256, "#{@subject}:#{Jason.encode!(@facts)}")
        |> Base.encode16(case: :lower)

      assert a.state_digest == recomputed
    end

    test "digest binds subject and facts: changing either changes identity" do
      base = Observation.create(@subject, @facts)
      other_subject = Observation.create("zoe:KingdomNeed#need_43", @facts)
      other_facts = Observation.create(@subject, Map.put(@facts, "open_opportunities", 4))

      assert base.state_digest != other_subject.state_digest
      assert base.state_digest != other_facts.state_digest
      assert base.observation_id != other_facts.observation_id
    end

    test "observation_id is the content-addressed prefix of the state digest" do
      obs = Observation.create(@subject, @facts)

      assert obs.observation_id == "obs_" <> binary_part(obs.state_digest, 0, 16)

      assert String.starts_with?(
               obs.state_digest,
               String.trim_leading(obs.observation_id, "obs_")
             )
    end

    test "identity is content, not clock or provenance: observed_at, evidence and standing never enter the digest" do
      base = Observation.create(@subject, @facts)

      shifted =
        Observation.create(@subject, @facts,
          observed_at: ~U[2030-06-01 00:00:00Z],
          evidence_refs: ["ev_99"],
          standing: :BLOCKED
        )

      assert base.state_digest == shifted.state_digest
      assert base.observation_id == shifted.observation_id
    end

    test "digest and observation_id are not injectable through opts" do
      forged =
        Observation.create(@subject, @facts,
          state_digest: "0",
          observation_id: "obs_forged"
        )

      assert forged.state_digest == @golden_digest
      assert forged.observation_id == @golden_id
    end

    test "empty facts are legal and still content-addressed (golden)" do
      obs = Observation.create("zoe:KingdomNeed#empty", %{})

      assert obs.state_digest ==
               "1316d6c6ce295e22bf264ab955d1e885ead289d5cfa94ac491fe4c0434b7d4cd"

      assert obs.observation_id == "obs_1316d6c6ce295e22"
      assert obs.facts == %{}
    end
  end

  describe "projection into consumer-visible shapes" do
    test "to_map projects exactly the consumer-visible camelCase key set" do
      map = Observation.create(@subject, @facts) |> Observation.to_map()

      assert Map.keys(map) |> Enum.sort() == [
               "authorityBoundary",
               "evidenceRefs",
               "exactSubject",
               "facts",
               "observationId",
               "observedAt",
               "projectionPurpose",
               "standing",
               "stateDigest"
             ]
    end

    test "observedAt survives an ISO 8601 round trip" do
      obs = Observation.create(@subject, @facts, observed_at: @vector_time)

      assert {:ok, parsed, 0} = DateTime.from_iso8601(Observation.to_map(obs)["observedAt"])
      assert parsed == @vector_time
    end

    test "every standing renders as its string form in the projection" do
      for standing <- [:ALIVE, :PARTIAL_ALIVE, :REFUSED, :BLOCKED] do
        map = Observation.create(@subject, @facts, standing: standing) |> Observation.to_map()
        assert map["standing"] == to_string(standing)
      end
    end

    test "defaults and opt overrides for evidence, purpose and time" do
      default = Observation.create(@subject, @facts)

      assert default.evidence_refs == []
      assert default.standing == :ALIVE
      assert default.projection_purpose == "consumer_state_observation"
      assert %DateTime{} = default.observed_at

      overridden =
        Observation.create(@subject, @facts,
          observed_at: @vector_time,
          evidence_refs: ["ev_1"],
          projection_purpose: "vector_check"
        )

      assert overridden.observed_at == @vector_time
      assert overridden.evidence_refs == ["ev_1"]
      assert overridden.projection_purpose == "vector_check"
    end

    test "to_map is a pure read: the observation is untouched and shares facts by reference" do
      obs = Observation.create(@subject, @facts)
      map = Observation.to_map(obs)

      assert map["facts"] == @facts
      assert map["facts"] == obs.facts

      # Projection exposes a plain consumer map, never the struct itself.
      refute is_struct(map)
      assert obs.facts == @facts
      assert obs.standing == :ALIVE
    end
  end

  describe "rejection of malformed inputs" do
    test "facts that are not JSON-encodable are rejected, not silently lossy" do
      assert_raise Protocol.UndefinedError, fn ->
        Observation.create(@subject, %{bad: {:tuple, 1}})
      end
    end

    test "to_map rejects non-observation input" do
      assert_raise FunctionClauseError, fn ->
        Observation.to_map(%{not: "an observation"})
      end
    end

    test "create requires subject and facts; there is no zero-arity projection" do
      assert_raise UndefinedFunctionError, fn ->
        Observation.create(@subject)
      end
    end
  end

  describe "golden serialization vectors" do
    test "fixed subject, facts and clock serialize to the recorded byte string" do
      obs =
        Observation.create(@subject, @facts,
          observed_at: @vector_time,
          evidence_refs: ["ev_1", "ev_2"],
          standing: :PARTIAL_ALIVE,
          projection_purpose: "vector_check"
        )

      assert obs.state_digest == @golden_digest
      assert obs.observation_id == @golden_id
      assert Jason.encode!(Observation.to_map(obs)) == @golden_json
    end
  end
end
