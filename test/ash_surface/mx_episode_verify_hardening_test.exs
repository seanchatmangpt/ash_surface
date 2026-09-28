defmodule AshSurface.MXEpisodeVerifyHardeningTest do
  @moduledoc """
  Boundary laws of `AshSurface.MXEpisode.verify/2` and `verify_file/2` that
  make the vendored verifier safe to call from a long-lived node:

    * an episode that cannot be JSON-encoded is a typed refusal, never a raise;
    * the verifier wait is bounded — a verifier that has not answered within
      `:timeout` is `{:error, {:verifier_timeout, ms}}`, never a pass;
    * the round trip leaves no scratch file behind in the shared tmp dir.

  State-based: the real module drives the real vendored Python verifier.
  """

  # async: false — the scratch-file census reads the shared System.tmp_dir!/0.
  use ExUnit.Case, async: false

  alias AshSurface.{Event, MXEpisode, Observation, PlanningEpisode, Surface}

  defp valid_episode do
    observation = Observation.create("sp:ticket:hardening", %{"status" => "open"})

    planning =
      PlanningEpisode.create("ws:hardening",
        planner_identity: "ash_pplan",
        policy_identity: "pol:1"
      )

    {:ok, episode} =
      MXEpisode.compose(%{
        observation: observation,
        planning_episode: planning,
        event: Event.create(observation.exact_subject, 1, "state.changed"),
        surface: %Surface{
          manifest: %{},
          contract: %{},
          action_ids: [],
          digest: AshSurface.contract_digest(%{})
        },
        receipt_hash: String.duplicate("7", 64),
        subject_repo: "zoela_phx",
        subject_head: "9a1b2c",
        consequence_id: "t1",
        episode_id: "MXEpisode/2026-09-17/000009"
      })

    episode
  end

  defp scratch_files do
    System.tmp_dir!() |> Path.join("mx_episode_verify-*.json") |> Path.wildcard()
  end

  test "a JSON-unencodable episode is a typed refusal, not a raise" do
    assert {:error, {:episode_not_json_encodable, _reason}} =
             MXEpisode.verify(%{"receipt_hash" => {:not, :json}})

    assert {:error, {:episode_not_json_encodable, _reason}} =
             MXEpisode.verify(%{"bytes" => <<0xFF, 0xFE>>})
  end

  test "a verifier that has not answered within :timeout is a timeout, never a pass" do
    assert MXEpisode.verify(valid_episode(), timeout: 0) == {:error, {:verifier_timeout, 0}}
  end

  test "the default bound admits a real verifier run" do
    assert MXEpisode.verify(valid_episode()) == {:ok, :valid}
  end

  test "verify/2 leaves no scratch file behind, on success and on timeout" do
    before = MapSet.new(scratch_files())

    assert {:ok, :valid} = MXEpisode.verify(valid_episode())
    assert {:error, {:verifier_timeout, 0}} = MXEpisode.verify(valid_episode(), timeout: 0)

    assert MapSet.new(scratch_files()) == before
  end
end
