defmodule AshSurface.MXEpisodeComposeTest do
  @moduledoc """
  Round-trip falsifiers for the lib-level MX episode composer (F4,
  finish-experience-023): compose/1 must bind every content-addressed part of
  one closed loop — observation digest, PlanningEpisode, MX receipt hash,
  Event, surface.digest, repo/head + CalVer — into the mx-episode-schema shape
  frozen at mx_closed_loop_episode_test.exs step 8, and the composed episode
  must round-trip through the vendored in-repo verifier unconditionally (no
  external checkout, no fail-open skip).
  """

  use ExUnit.Case, async: false

  alias Ash.Info.Manifest
  alias AshSurface.{Event, MXEpisode, Observation, PlanningEpisode}
  alias AshSurface.Fixtures.VolunteerMilestone

  @subject "zoe:KingdomNeed#need_mx_compose"
  @facts %{
    "kingdom_need_id" => "need_mx_compose",
    "open_opportunities" => 1,
    "member_id" => "member_mx_compose_01",
    "milestone_id" => "milestone_mx_compose_01"
  }
  @repo "seanchatmangpt/ash_surface"
  @head "00f14b1b966900aa129f16a2e51727ef697823ec"
  @consequence_id "cns_mx_compose_0001"
  @episode_id "MXEpisode/2026-09-17/000001"
  @tmp_dir Path.expand("../../_build/test/mx_episode_compose", __DIR__)

  setup do
    File.rm_rf!(@tmp_dir)
    File.mkdir_p!(@tmp_dir)

    observation = Observation.create(@subject, @facts, standing: :ALIVE)

    planning_episode =
      PlanningEpisode.create(observation.observation_id,
        planner_identity: "ash_pplan:fond_hddl_solver",
        policy_identity: "zoe:policy:strong_cyclic",
        policy_standing: :VALID_STRONG,
        candidate_actions: [candidate()],
        authority_ceiling: :SELECT
      )

    assert {:ok, manifest} =
             Manifest.generate(
               otp_app: :ash_surface,
               action_entrypoints: [
                 {VolunteerMilestone, :record},
                 {VolunteerMilestone, :read}
               ]
             )

    assert {:ok, surface} = AshSurface.from_manifest(manifest, profile: %{})

    event =
      Event.create(observation.exact_subject, 1, "state_transition",
        payload: %{"status" => "completed", "record_id" => @consequence_id},
        receipt_ref: "rcpt_consequence_#{@consequence_id}"
      )

    loop = %{
      observation: observation,
      planning_episode: planning_episode,
      event: event,
      surface: surface,
      receipt_hash: receipt_hash(),
      subject_repo: @repo,
      subject_head: @head,
      consequence_id: @consequence_id,
      episode_id: @episode_id
    }

    %{loop: loop}
  end

  test "compose binds every content-addressed part into the frozen episode shape", %{
    loop: loop
  } do
    assert {:ok, mx} = MXEpisode.compose(loop)

    # Shape freeze: exactly the thirteen mx-episode-schema top-level fields.
    assert MapSet.new(Map.keys(mx)) == MapSet.new(MXEpisode.required_fields())

    assert mx["episode_id"] == @episode_id
    assert mx["subject_repo"] == @repo
    assert mx["subject_head"] == @head

    for field <- ~w(pattern_version domain_version hddl_version fond_version verifier_version) do
      assert mx[field] == "v26.9.17"
      assert mx[field] == MXEpisode.calver()
    end

    assert mx["selected_decomposition"] == MXEpisode.selected_decomposition()

    transitions = mx["observed_transitions"]

    # One content-addressed witness per decomposition step, in frozen order
    # (observe_state, project_candidates, authorize_candidate, actuate_brce,
    # emit_event); the observe/actuate step names are the frozen literal's.
    assert Enum.map(transitions, & &1["step"]) == [
             "observe",
             "project_candidates",
             "authorize_candidate",
             "actuate",
             "emit_event"
           ]

    observe = Enum.find(transitions, &(&1["step"] == "observe"))
    assert observe["state_digest"] == loop.observation.state_digest

    projected = Enum.find(transitions, &(&1["step"] == "project_candidates"))
    assert projected["planning_episode_id"] == loop.planning_episode.episode_id
    assert projected["authority_ceiling"] == "SELECT"

    authorized = Enum.find(transitions, &(&1["step"] == "authorize_candidate"))
    assert authorized["surface_digest"] == loop.surface.digest
    assert authorized["marketplace_identity"] == "ggen-marketplace:v26.9.17"

    actuate = Enum.find(transitions, &(&1["step"] == "actuate"))

    assert actuate == %{
             "step" => "actuate",
             "outcome" => "pass",
             "consequence_id" => @consequence_id
           }

    emit = Enum.find(transitions, &(&1["step"] == "emit_event"))
    assert emit["event_id"] == loop.event.event_id
    assert emit["subject_ref"] == @subject
    assert emit["state_digest"] == loop.event.state_digest

    assert mx["receipt_hash"] == receipt_hash()
    assert mx["resulting_standing"] == "ALIVE"
    assert mx["cost_score"] == 1.0
  end

  test "composed episode round-trips: validate, encode, vendored in-repo verifier", %{
    loop: loop
  } do
    assert {:ok, mx} = MXEpisode.compose(loop)
    assert :ok = MXEpisode.validate(mx)

    # The verifier ships inside the application tree — no marketplace checkout,
    # no skip path.
    assert File.exists?(MXEpisode.verifier_path())
    assert MXEpisode.verifier_path() =~ ~r{/priv/verifier/verify_closure_episode\.py$}
    refute MXEpisode.verifier_path() =~ "ggen-marketplace"

    path = Path.join(@tmp_dir, "compose_round_trip.json")
    File.write!(path, Jason.encode!(mx))
    assert {:ok, :valid} = MXEpisode.verify_file(path)

    assert {:ok, :valid} = MXEpisode.verify(mx)
  end

  test "compose is deterministic on identical loop inputs", %{loop: loop} do
    assert {:ok, mx} = MXEpisode.compose(loop)
    assert {:ok, replay} = MXEpisode.compose(loop)
    assert replay == mx
  end

  test "compose composes the default episode identity from date and sequence", %{loop: loop} do
    assert {:ok, mx} =
             loop
             |> Map.drop([:episode_id])
             |> Map.merge(%{date: ~D[2026-09-17], sequence: 2})
             |> MXEpisode.compose()

    assert mx["episode_id"] == "MXEpisode/2026-09-17/000002"
    assert :ok = MXEpisode.validate(mx)
  end

  test "compose refuses incomplete or unbound loops", %{loop: loop} do
    assert {:error, {:missing_compose_fields, [:receipt_hash, :subject_head]}} =
             MXEpisode.compose(Map.drop(loop, [:receipt_hash, :subject_head]))

    wrong_subject =
      Event.create("zoe:KingdomNeed#need_wrong_subject", 1, "state_transition", payload: %{})

    assert {:error, {:subject_binding_violation, "zoe:KingdomNeed#need_wrong_subject"}} =
             MXEpisode.compose(%{loop | event: wrong_subject})

    assert {:error, {:invalid_standing, "PROBABLY_FINE"}} =
             MXEpisode.compose(Map.put(loop, :resulting_standing, "PROBABLY_FINE"))

    assert {:error, {:invalid_compose_input, :observation, AshSurface.Observation}} =
             MXEpisode.compose(Map.put(loop, :observation, %{"not" => "an observation"}))

    assert {:error, {:invalid_surface_digest, "short"}} =
             MXEpisode.compose(Map.put(loop, :surface, fake_surface("short")))
  end

  test "vendored verifier rejects schema violations unconditionally (no fail-open skip)", %{
    loop: loop
  } do
    assert {:ok, mx} = MXEpisode.compose(loop)

    dropped = Map.drop(mx, ["receipt_hash"])
    assert {:error, {"MISSING_EPISODE_FIELDS", _}} = MXEpisode.verify(dropped)
    assert {:error, {:missing_fields, ["receipt_hash"]}} = MXEpisode.validate(dropped)

    drifted = Map.put(mx, "pattern_version", "v25.9.12")
    assert {:error, {"CALVER_MISMATCH", _}} = MXEpisode.verify(drifted)

    assert {:error, {:calver_mismatch, "pattern_version", "v25.9.12"}} =
             MXEpisode.validate(drifted)

    bad_standing = Map.put(mx, "resulting_standing", "PROBABLY_FINE")
    assert {:error, {"INVALID_STANDING", _}} = MXEpisode.verify(bad_standing)
    assert {:error, {:invalid_standing, "PROBABLY_FINE"}} = MXEpisode.validate(bad_standing)
  end

  # ---------------------------------------------------------------------------

  defp candidate do
    %{
      "actionId" => "AshSurface.Fixtures.VolunteerMilestone#record",
      "semanticId" => "zoe:SelectOption",
      "authorityBoundary" => "SELECT",
      "doAuthority" => false,
      "input" => %{
        "member_id" => "member_mx_compose_01",
        "milestone_id" => "milestone_mx_compose_01",
        "cost_physical" => 10,
        "reward_spiritual" => 100
      }
    }
  end

  # Content-addressed MX receipt hash over a canonical dispatch receipt, the
  # same law the deep falsifiers pin (recomputed_receipt_hash).
  defp receipt_hash do
    payload = %{
      "actionId" => "AshSurface.Fixtures.VolunteerMilestone#record",
      "dispatchState" => "completed",
      "input" => %{
        "member_id" => "member_mx_compose_01",
        "milestone_id" => "milestone_mx_compose_01"
      },
      "outcome" => "SUCCESS",
      "consequence" => %{"id" => @consequence_id, "status" => "completed"}
    }

    :crypto.hash(:sha256, canonical_json(payload)) |> Base.encode16(case: :lower)
  end

  defp canonical_json(val) when is_map(val) do
    inner =
      val
      |> Enum.sort_by(fn {k, _} -> to_string(k) end)
      |> Enum.map(fn {k, v} -> "#{Jason.encode!(to_string(k))}:#{canonical_json(v)}" end)
      |> Enum.join(",")

    "{" <> inner <> "}"
  end

  defp canonical_json(val) when is_list(val) do
    "[" <> Enum.map_join(val, ",", &canonical_json/1) <> "]"
  end

  defp canonical_json(val), do: Jason.encode!(val)

  # Minimal Surface-shaped stand-in solely to drive the digest law refusal.
  defp fake_surface(digest) do
    struct(AshSurface.Surface,
      manifest: %Ash.Info.Manifest{entrypoints: []},
      contract: %{},
      digest: digest,
      action_ids: []
    )
  end
end
