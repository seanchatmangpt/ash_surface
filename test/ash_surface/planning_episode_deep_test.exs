defmodule AshSurface.PlanningEpisodeDeepTest do
  @moduledoc """
  Deep invariants for AshSurface.PlanningEpisode beyond the projection smoke test.

  Covers: episode lifecycle standings, admission boundaries (planning != DO),
  zod schema parity with the JS `planningEpisodeSchema`, rejection of malformed
  episodes, and serialization stability (golden frozen fields).
  """
  use ExUnit.Case, async: true
  alias AshSurface.PlanningEpisode

  # Golden parity: mirrors the zod `planningEpisodeSchema` in
  # priv/static/ash_surface_runtime.mjs. Changing any of these on either
  # surface is a contract break and must be a deliberate cross-repo change.
  @golden_fields ~w(
    episodeId
    worldStateRef
    taskNetworkRef
    plannerIdentity
    policyIdentity
    policyStanding
    candidateActions
    authorityCeiling
  )

  @golden_standings ~w(VALID_STRONG VALID_STRONG_CYCLIC REFUSED)
  @golden_ceilings ~w(SELECT CONSTRUCT)
  @episode_id_format ~r/\Aep_[0-9a-f]{16}\z/

  defp base_opts do
    [
      planner_identity: "ash_pplan:fond_hddl_solver",
      policy_identity: "zoe:policy:strong_cyclic"
    ]
  end

  describe "zod schema parity (golden frozen fields)" do
    test "to_map emits exactly the planningEpisodeSchema field set, no more, no less" do
      ep = PlanningEpisode.create("obs_parity", base_opts())
      map = PlanningEpisode.to_map(ep)

      assert Map.keys(map) |> MapSet.new() == MapSet.new(@golden_fields)
      assert length(@golden_fields) == 8
    end

    test "serialized enums stay inside the frozen zod enums (no DO can leak through)" do
      for ceiling <- [:SELECT, :CONSTRUCT] do
        ep =
          PlanningEpisode.create(
            "obs_enum",
            Keyword.put(base_opts(), :authority_ceiling, ceiling)
          )

        map = PlanningEpisode.to_map(ep)

        assert map["authorityCeiling"] in @golden_ceilings
        assert map["authorityCeiling"] == to_string(ceiling)
      end

      for standing <- [:VALID_STRONG, :VALID_STRONG_CYCLIC, :REFUSED] do
        ep =
          PlanningEpisode.create("obs_enum", Keyword.put(base_opts(), :policy_standing, standing))

        map = PlanningEpisode.to_map(ep)

        assert map["policyStanding"] in @golden_standings
        assert map["policyStanding"] == to_string(standing)
      end
    end

    test "required-identity fields serialize as non-empty strings (zod min(1))" do
      ep =
        PlanningEpisode.create(
          "obs_ws",
          Keyword.merge(base_opts(), task_network_ref: "tn_77", candidate_actions: [%{"a" => 1}])
        )

      map = PlanningEpisode.to_map(ep)

      for field <- ~w(episodeId worldStateRef plannerIdentity policyIdentity) do
        assert is_binary(map[field]) and map[field] != ""
      end

      assert map["taskNetworkRef"] == "tn_77"
      assert map["candidateActions"] == [%{"a" => 1}]
    end
  end

  describe "episode lifecycle standings" do
    test "defaults mirror the zod schema defaults exactly" do
      ep = PlanningEpisode.create("obs_default", base_opts())

      assert ep.policy_standing == :VALID_STRONG
      assert ep.candidate_actions == []
      assert ep.authority_ceiling == :SELECT
      assert ep.task_network_ref == nil

      map = PlanningEpisode.to_map(ep)

      assert map["policyStanding"] == "VALID_STRONG"
      assert map["candidateActions"] == []
      assert map["authorityCeiling"] == "SELECT"
      assert map["taskNetworkRef"] == nil
    end

    test "every admissible standing completes the lifecycle to a serializable projection" do
      for {standing, expected} <- [
            {:VALID_STRONG, "VALID_STRONG"},
            {:VALID_STRONG_CYCLIC, "VALID_STRONG_CYCLIC"},
            {:REFUSED, "REFUSED"}
          ] do
        ep =
          PlanningEpisode.create(
            "obs_lifecycle",
            Keyword.merge(base_opts(), policy_standing: standing)
          )

        assert %PlanningEpisode{} = ep
        assert ep.policy_standing == standing
        assert PlanningEpisode.to_map(ep)["policyStanding"] == expected
      end
    end

    test "a REFUSED standing does not escalate authority (refusal is not execution)" do
      ep =
        PlanningEpisode.create(
          "obs_refused",
          Keyword.merge(base_opts(),
            policy_standing: :REFUSED,
            candidate_actions: [],
            authority_ceiling: :CONSTRUCT
          )
        )

      assert ep.policy_standing == :REFUSED
      assert ep.authority_ceiling == :CONSTRUCT
      assert PlanningEpisode.to_map(ep)["authorityCeiling"] in @golden_ceilings
    end
  end

  describe "admission boundary: planning != DO" do
    test ":DO is refused regardless of how legitimate the rest of the episode is" do
      for opts <- [
            base_opts(),
            Keyword.merge(base_opts(), policy_standing: :REFUSED, candidate_actions: []),
            Keyword.merge(base_opts(), policy_standing: :VALID_STRONG_CYCLIC)
          ] do
        assert_raise ArgumentError, ~r/can never be :DO/, fn ->
          PlanningEpisode.create("obs_do_guard", Keyword.put(opts, :authority_ceiling, :DO))
        end
      end
    end

    test "SELECT and CONSTRUCT are the only admitted ceilings and both round-trip" do
      for ceiling <- [:SELECT, :CONSTRUCT] do
        ep =
          PlanningEpisode.create(
            "obs_ceiling",
            Keyword.merge(base_opts(), authority_ceiling: ceiling)
          )

        assert ep.authority_ceiling == ceiling
        assert PlanningEpisode.to_map(ep)["authorityCeiling"] == to_string(ceiling)
      end
    end
  end

  describe "rejection of malformed episodes" do
    test "missing planner_identity is rejected (KeyError from fetch!)" do
      assert_raise KeyError, ~r/planner_identity/, fn ->
        PlanningEpisode.create("obs_malformed", policy_identity: "zoe:policy:x")
      end
    end

    test "missing policy_identity is rejected (KeyError from fetch!)" do
      assert_raise KeyError, ~r/policy_identity/, fn ->
        PlanningEpisode.create("obs_malformed", planner_identity: "ash_pplan:solver")
      end
    end

    test "to_map rejects forged foreign shapes (no struct impersonation)" do
      # Routed through apply/3 so the intentional spec-violating call is a
      # runtime rejection under test, not a compile-time dialyzer warning.
      forged = %{"episodeId" => "ep_forged", "authorityCeiling" => "SELECT"}

      assert_raise FunctionClauseError, fn ->
        apply(PlanningEpisode, :to_map, [forged])
      end
    end
  end

  describe "episode identity" do
    test "episode_id is content-addressed: identical inputs yield the identical id" do
      candidates = [%{"action" => "select_driver", "candidate" => "person_02"}]

      a =
        PlanningEpisode.create("obs_id", Keyword.put(base_opts(), :candidate_actions, candidates))

      b =
        PlanningEpisode.create("obs_id", Keyword.put(base_opts(), :candidate_actions, candidates))

      assert a.episode_id == b.episode_id
      assert a.episode_id =~ @episode_id_format
    end

    test "episode_id distinguishes every hashing input dimension" do
      candidates = [%{"action" => "select_intercessor"}]
      opts = Keyword.put(base_opts(), :candidate_actions, candidates)
      baseline = PlanningEpisode.create("obs_dim", opts).episode_id

      perturbations = [
        {"world_state_ref", PlanningEpisode.create("obs_other", opts)},
        {"planner_identity",
         PlanningEpisode.create(
           "obs_dim",
           Keyword.merge(opts, planner_identity: "beam4pm:fond")
         )},
        {"policy_identity",
         PlanningEpisode.create(
           "obs_dim",
           Keyword.merge(opts, policy_identity: "zoe:policy:strong")
         )},
        {"candidate_actions",
         PlanningEpisode.create(
           "obs_dim",
           Keyword.put(opts, :candidate_actions, [%{"action" => "select_driver"}])
         )}
      ]

      for {dimension, episode} <- perturbations do
        assert episode.episode_id != baseline, "episode_id must distinguish #{dimension}"
      end
    end

    test "episode_id shape is a stable 16-hex-char lowercase digest" do
      ep = PlanningEpisode.create("obs_shape", base_opts())
      assert ep.episode_id =~ @episode_id_format
    end
  end

  describe "serialization stability" do
    test "repeated to_map calls are byte-stable and JSON-encodable" do
      ep =
        PlanningEpisode.create(
          "obs_stable",
          Keyword.merge(base_opts(),
            task_network_ref: "tn_stable",
            candidate_actions: [%{"action" => "select_intercessor", "candidate" => "person_01"}]
          )
        )

      m1 = PlanningEpisode.to_map(ep)
      m2 = PlanningEpisode.to_map(ep)

      assert m1 == m2
      assert m1 == m2
      # Jason.encode! stability: the projection must survive a JSON round trip
      # unchanged (this is the exact payload the JS surface validates).
      assert Jason.decode!(Jason.encode!(m1)) == m1
    end

    test "candidate payloads pass through untransformed" do
      candidates = [
        %{"action" => "select_intercessor", "candidate" => "person_01", "score" => 0.75},
        %{"action" => "select_driver", "candidate" => "person_02", "meta" => %{"k" => [1, 2]}}
      ]

      ep =
        PlanningEpisode.create(
          "obs_passthrough",
          Keyword.put(base_opts(), :candidate_actions, candidates)
        )

      assert ep.candidate_actions == candidates
      assert PlanningEpisode.to_map(ep)["candidateActions"] == candidates
    end
  end
end
