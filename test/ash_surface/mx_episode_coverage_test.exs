defmodule AshSurface.MXEpisodeCoverageTest do
  @moduledoc """
  Refusal and defaulting laws of `AshSurface.MXEpisode` not pinned by the
  compose/closed-loop suites: non-map input is refused with a typed error by
  compose/validate/verify; typed optional inputs (atom standing, explicit
  numeric cost, string date, absent/invalid date and sequence) resolve to the
  documented episode fields; mistyped optional inputs are refused, never
  coerced; and the vendored verifier's exit code is authoritative — a VALID
  token without exit 0 is a failure, and output without a `[CODE]` line is
  unparseable, never approximated.
  """

  use ExUnit.Case, async: true

  alias AshSurface.{Event, MXEpisode, Observation, PlanningEpisode, Surface}

  @scratch Path.expand("../../_build/test/mx_episode_coverage", __DIR__)

  defp loop(overrides) do
    observation = Observation.create("sp:ticket:cov", %{"status" => "open"})

    planning =
      PlanningEpisode.create("ws:cov", planner_identity: "ash_pplan", policy_identity: "pol:1")

    event = Event.create(observation.exact_subject, 1, "state.changed")

    surface = %Surface{
      manifest: %{},
      contract: %{},
      action_ids: [],
      digest: AshSurface.contract_digest(%{})
    }

    Map.merge(
      %{
        observation: observation,
        planning_episode: planning,
        event: event,
        surface: surface,
        receipt_hash: String.duplicate("7", 64),
        subject_repo: "zoela_phx",
        subject_head: "9a1b2c",
        consequence_id: "t1"
      },
      overrides
    )
  end

  defp valid_episode do
    {:ok, episode} = MXEpisode.compose(loop(%{episode_id: "MXEpisode/2026-09-17/000001"}))
    episode
  end

  describe "non-map input is refused with a typed error" do
    test "compose/1" do
      assert MXEpisode.compose([:not, :a, :map]) ==
               {:error, {:compose_input_must_be_a_map, [:not, :a, :map]}}
    end

    test "validate/1" do
      assert MXEpisode.validate("episode") == {:error, :episode_must_be_a_map}
    end

    test "verify/1 refuses before touching the verifier" do
      assert MXEpisode.verify(42) == {:error, {:episode_must_be_a_map, 42}}
    end
  end

  describe "compose optional inputs" do
    test "an atom resulting_standing is projected to its string form" do
      assert {:ok, episode} = MXEpisode.compose(loop(%{resulting_standing: :PARTIAL_ALIVE}))
      assert episode["resulting_standing"] == "PARTIAL_ALIVE"
      assert MXEpisode.validate(episode) == :ok
    end

    test "an atom standing outside the vocabulary is refused as its string" do
      assert MXEpisode.compose(loop(%{resulting_standing: :NOT_A_STANDING})) ==
               {:error, {:invalid_standing, "NOT_A_STANDING"}}
    end

    test "an explicit numeric cost_score is carried verbatim" do
      assert {:ok, episode} = MXEpisode.compose(loop(%{cost_score: 3}))
      assert episode["cost_score"] == 3
    end

    test "a non-numeric cost_score is refused, never coerced" do
      assert MXEpisode.compose(loop(%{cost_score: "1.0"})) ==
               {:error, {:invalid_compose_input, :cost_score, {:expected_number, "1.0"}}}
    end

    test "a non-binary episode_id is refused, never defaulted" do
      assert MXEpisode.compose(loop(%{episode_id: 7})) ==
               {:error, {:invalid_compose_input, :episode_id, {:expected_binary, 7}}}
    end

    test "a non-binary required binary field is refused with its key" do
      assert MXEpisode.compose(loop(%{subject_head: :head})) ==
               {:error, {:invalid_compose_input, :subject_head, {:expected_binary, :head}}}
    end

    test "a string date is bound verbatim and a missing sequence defaults to 000001" do
      assert {:ok, episode} = MXEpisode.compose(loop(%{date: "2026-09-28"}))
      assert episode["episode_id"] == "MXEpisode/2026-09-28/000001"
    end

    test "a negative sequence falls back to the default 000001" do
      assert {:ok, episode} = MXEpisode.compose(loop(%{date: ~D[2026-09-28], sequence: -1}))
      assert episode["episode_id"] == "MXEpisode/2026-09-28/000001"
    end

    test "an untyped date falls back to the UTC date of composition" do
      before = Date.utc_today() |> Date.to_iso8601()
      assert {:ok, episode} = MXEpisode.compose(loop(%{date: 20_260_928, sequence: 42}))
      after_ = Date.utc_today() |> Date.to_iso8601()

      assert episode["episode_id"] in [
               "MXEpisode/#{before}/000042",
               "MXEpisode/#{after_}/000042"
             ]
    end
  end

  describe "validate/1 key handling" do
    test "keys that are neither strings nor atoms are ignored, not fatal" do
      assert MXEpisode.validate(Map.put(valid_episode(), 1, "extra")) == :ok
    end

    test "an atom-keyed episode satisfies presence but fails the JSON-dialect CalVer law" do
      atom_keyed = Map.new(valid_episode(), fn {k, v} -> {String.to_existing_atom(k), v} end)

      assert MXEpisode.validate(atom_keyed) ==
               {:error, {:calver_mismatch, "pattern_version", nil}}
    end
  end

  describe "verifier exit code is authoritative" do
    setup do
      File.mkdir_p!(@scratch)
      :ok
    end

    test "output with no [CODE] line is unparseable, never approximated" do
      missing = Path.join(@scratch, "absent-episode.json")
      File.rm(missing)

      assert {:error, {:verifier_unparseable, exit_code, output}} =
               MXEpisode.verify_file(missing)

      assert exit_code != 0
      assert output =~ "FileNotFoundError"
    end

    test "a VALID token without exit 0 is a verifier failure, not {:ok, :valid}" do
      # The traceback echoes the path, so the first [CODE] match is "[VALID]"
      # while the process exits non-zero.
      missing = Path.join(@scratch, "[VALID] absent.json")
      File.rm(missing)

      assert {:error, {:verifier_failed, exit_code, output}} = MXEpisode.verify_file(missing)
      assert exit_code != 0
      assert output =~ "[VALID]"
      assert output =~ "FileNotFoundError"
    end
  end
end
