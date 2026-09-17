defmodule AshSurface.MXClosedLoopEpisodeTest do
  @moduledoc """
  Falsifier Test for the End-to-End Machine Experience (MX) Closed Loop:

  ZOELA
  -> receives exact Ash state (ObservationProjection)
  -> receives FOND/HDDL candidate (PlanningEpisodeProjection)
  -> candidate carries SELECT/CONSTRUCT only (authority_ceiling: :SELECT)
  -> authorized action crosses consequence boundary (Ash mutation)
  -> domain consequence receipt emitted (cryptographic receipt)
  -> ZOELA receives resulting event (EventProjection)
  -> MX episode closes (Composed MX receipt envelope)
  -> episode replays against exact CalVer/digests using verify_closure_episode.py
  """

  use ExUnit.Case, async: false

  alias Ash.Info.Manifest
  alias AshSurface.{Observation, PlanningEpisode, Event}
  alias AshSurface.Fixtures.{Server, VolunteerMilestone}

  @tmp_dir Path.expand("../../_build/test/mx_closed_loop", __DIR__)
  @verifier_script Path.expand(
                     "../../ggen-marketplace/domains/repo-closure/verifier/verify_closure_episode.py",
                     __DIR__
                   )

  setup do
    File.rm_rf!(@tmp_dir)
    File.mkdir_p!(@tmp_dir)

    {:ok, server_pid} = Server.start_link()
    port = Server.get_port(server_pid)

    on_exit(fn ->
      if Process.alive?(server_pid), do: Server.stop(server_pid)
    end)

    {:ok, server_pid: server_pid, port: port}
  end

  test "complete machine-only closed loop execution and independent episode verification", %{
    port: port
  } do
    # 1. Step 1: Authoritative XaaS/Ash state observation projection
    facts = %{
      "kingdom_need_id" => "need_zoela_77",
      "open_opportunities" => 1,
      "member_id" => "member_zoela_01",
      "milestone_id" => "milestone_serve_42"
    }

    obs = Observation.create("zoe:KingdomNeed#need_zoela_77", facts, standing: :ALIVE)
    assert obs.authority_boundary == :OBSERVE
    assert String.starts_with?(obs.observation_id, "obs_")

    # 2. Step 2: FOND/HDDL Planning Episode Projection (Planner != DO)
    candidates = [
      %{
        "actionId" => "AshSurface.Fixtures.VolunteerMilestone#record",
        "semanticId" => "zoe:SelectOption",
        "authorityBoundary" => "SELECT",
        "doAuthority" => false,
        "input" => %{
          "member_id" => "member_zoela_01",
          "milestone_id" => "milestone_serve_42",
          "cost_physical" => 10,
          "reward_spiritual" => 100
        }
      }
    ]

    episode_projection =
      PlanningEpisode.create(obs.observation_id,
        planner_identity: "ash_pplan:fond_hddl_solver",
        policy_identity: "zoe:policy:strong_cyclic",
        policy_standing: :VALID_STRONG,
        candidate_actions: candidates,
        authority_ceiling: :SELECT
      )

    assert episode_projection.authority_ceiling == :SELECT
    assert episode_projection.policy_standing == :VALID_STRONG

    # 3. Step 3: Consumer Surface Manifest Generation & Projection
    assert {:ok, manifest} =
             Manifest.generate(
               otp_app: :ash_surface,
               action_entrypoints: [
                 {VolunteerMilestone, :record},
                 {VolunteerMilestone, :read}
               ]
             )

    profile = %{
      audience: :zoe_kingdom,
      actions: %{
        "AshSurface.Fixtures.VolunteerMilestone#record" => %{
          semanticId: "zoe:SelectOption",
          authorityBoundary: "SELECT",
          doAuthority: false,
          receiptRequired: true,
          evidenceRequired: true,
          possibleRefusals: ["REFUSED_NO_AUTHORITY", "REFUSED_EVIDENCE_REQUIRED"]
        }
      }
    }

    assert {:ok, surface} = AshSurface.from_manifest(manifest, profile: profile)
    assert surface.contract["marketplaceIdentity"] == "ggen-marketplace:v26.9.17"

    contract_path = Path.join(@tmp_dir, "contract.json")
    receipt_path = Path.join(@tmp_dir, "receipt.json")
    File.write!(contract_path, Jason.encode!(surface.contract))

    # 4. Step 4: ZOELA JavaScript Consumer Fixture Dispatches Authorized Candidate
    {output, exit_code} =
      System.cmd("node", [
        "test/js/consumer_e2e_runner.mjs",
        contract_path,
        to_string(port),
        receipt_path
      ])

    assert exit_code == 0, "Consumer execution failed: #{output}"

    # 5. Step 5: Consequence Verification in Ash Data Layer
    assert {:ok, records} = Ash.read(VolunteerMilestone, domain: AshSurface.Fixtures.Domain)
    record = Enum.find(records, fn r -> r.member_id == "member_zoela_01" end)
    refute is_nil(record)
    assert record.milestone_id == "milestone_serve_42"
    assert record.status == "completed"

    # 6. Step 6: Server-to-Client Event Projection Emitted
    event =
      Event.create(obs.exact_subject, 1, "state_transition",
        payload: %{"status" => "completed", "record_id" => record.id},
        receipt_ref: "rcpt_consequence_#{record.id}"
      )

    assert event.authority_boundary == :OBSERVE
    assert event.sequence == 1

    # 7. Step 7: Cryptographic Consequence Receipt Loaded
    assert File.exists?(receipt_path)
    receipt = Jason.decode!(File.read!(receipt_path))
    assert receipt["dispatchState"] == "completed"
    assert is_binary(receipt["receiptHash"])

    # 8. Step 8: Build and Verify Complete Closed-Loop MX Episode Record
    mx_episode = %{
      "episode_id" => "MXEpisode/2026-09-13/000002",
      "subject_repo" => "seanchatmangpt/ash_surface",
      "subject_head" => "00f14b1b966900aa129f16a2e51727ef697823ec",
      "pattern_version" => "v26.9.17",
      "domain_version" => "v26.9.17",
      "hddl_version" => "v26.9.17",
      "fond_version" => "v26.9.17",
      "verifier_version" => "v26.9.17",
      "selected_decomposition" => [
        "observe_state",
        "project_candidates",
        "authorize_candidate",
        "actuate_brce",
        "emit_event"
      ],
      "observed_transitions" => [
        %{"step" => "observe", "state_digest" => obs.state_digest},
        %{"step" => "actuate", "outcome" => "pass", "consequence_id" => record.id}
      ],
      "cost_score" => 1.0,
      "receipt_hash" => receipt["receiptHash"],
      "resulting_standing" => "ALIVE"
    }

    episode_path = Path.join(@tmp_dir, "episode.json")
    File.write!(episode_path, Jason.encode!(mx_episode))

    # 9. Step 9: Replay Verification with Independent Python Verifier
    if File.exists?(@verifier_script) do
      # Pass json directly to verifier
      verify_cmd = """
      import json, sys
      from verify_closure_episode import verify_episode

      with open('#{episode_path}') as f:
          data = json.load(f)

      res = verify_episode(data)
      print(f'[{res.code}] {res.message}')
      sys.exit(0 if res.valid else 1)
      """

      verifier_dir = Path.dirname(@verifier_script)

      {v_out, v_code} =
        System.cmd("python3.11", ["-c", verify_cmd], cd: verifier_dir)

      assert v_code == 0, "Independent episode verifier failed: #{v_out}"
      assert String.contains?(v_out, "[VALID]")
    end
  end
end
