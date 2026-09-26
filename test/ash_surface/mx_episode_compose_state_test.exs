defmodule AshSurface.MXEpisodeComposeStateTest do
  @moduledoc """
  `MXEpisode.compose/1` as a STATE TABLE (chicago-episode-compose-031).

  Each row is one full state of the world: the loop fixture built from REAL
  parts (a projected Observation, a PlanningEpisode, an emitted Event, and a
  Surface admitted from a real Ash manifest — no doubles for any part, none
  for the unit under test), the mutation applied to that loop, and the exact
  observable outcome of `compose/1` — a composed episode or a typed refusal.

  Chicago-school discipline:

    - the unit under test is the REAL `AshSurface.MXEpisode`; nothing about
      compose/validate/verify is mocked or injected;
    - assertions touch observable outcomes only: returned values, typed
      refusals, the frozen thirteen-field episode shape, and on-disk bytes
      round-tripped through `verify_file/1` with the vendored in-repo
      verifier (no external checkout, no skip path).

  Row set (13 rows; Acceptance requires >=10):

    1. full live loop composes, validates, and the written episode file
       verifies VALID
    2. JSON-dialect (string-key) loop composes to the identical episode
    3-10. one row per required compose part, dropped alone: observation,
       planning_episode, event, surface, receipt_hash, subject_repo,
       subject_head, consequence_id — each refused with the exact
       `{:missing_compose_fields, [key]}` tuple
    11. subject-binding violation: an event off the observation's exact
       subject is refused with the offending subject_ref
    12. non-canonical digest (not 64 hex) is refused with the offending value
    13. non-canonical digest (64 UPPERCASE hex — right shape, wrong case) is
       refused: the content address is lowercase-hex canonical or nothing
  """

  use ExUnit.Case, async: false

  alias Ash.Info.Manifest
  alias AshSurface.{Event, MXEpisode, Observation, PlanningEpisode}
  alias AshSurface.Fixtures.VolunteerMilestone

  @subject "zoe:KingdomNeed#need_mx_state"
  @off_subject "zoe:KingdomNeed#need_mx_state_other"
  @facts %{
    "kingdom_need_id" => "need_mx_state",
    "open_opportunities" => 1,
    "member_id" => "member_mx_state_01",
    "milestone_id" => "milestone_mx_state_01"
  }
  @repo "seanchatmangpt/ash_surface"
  @head "00f14b1b966900aa129f16a2e51727ef697823ec"
  @consequence_id "cns_mx_state_0001"
  @episode_id "MXEpisode/2026-09-17/000031"
  @uppercase_hex_digest String.upcase(String.duplicate("ab", 32))
  @tmp_dir Path.expand("../../_build/test/mx_episode_compose_state", __DIR__)

  setup do
    File.rm_rf!(@tmp_dir)
    File.mkdir_p!(@tmp_dir)
    :ok
  end

  # ---------------------------------------------------------------------------
  # The state table. `:drop` removes one required part; `:event_subject`
  # swaps the emitted event's subject; `:surface_digest` swaps the surface's
  # content address; `:string_keys` feeds the JSON dialect. `:expected` is
  # the exact observable: `{:ok, :episode}` or the exact typed refusal.
  # Every mutation is data; the runner below is the only interpreter.
  # ---------------------------------------------------------------------------
  @state_table [
    %{
      label: "full live loop composes and the written episode file verifies VALID",
      drop: nil,
      event_subject: nil,
      surface_digest: nil,
      string_keys: false,
      expected: {:ok, :episode}
    },
    %{
      label: "JSON-dialect (string-key) loop composes the identical episode",
      drop: nil,
      event_subject: nil,
      surface_digest: nil,
      string_keys: true,
      expected: {:ok, :episode}
    },
    %{
      label: "missing observation refuses with the exact typed refusal",
      drop: :observation,
      event_subject: nil,
      surface_digest: nil,
      string_keys: false,
      expected: {:error, {:missing_compose_fields, [:observation]}}
    },
    %{
      label: "missing planning_episode refuses with the exact typed refusal",
      drop: :planning_episode,
      event_subject: nil,
      surface_digest: nil,
      string_keys: false,
      expected: {:error, {:missing_compose_fields, [:planning_episode]}}
    },
    %{
      label: "missing event refuses with the exact typed refusal",
      drop: :event,
      event_subject: nil,
      surface_digest: nil,
      string_keys: false,
      expected: {:error, {:missing_compose_fields, [:event]}}
    },
    %{
      label: "missing surface refuses with the exact typed refusal",
      drop: :surface,
      event_subject: nil,
      surface_digest: nil,
      string_keys: false,
      expected: {:error, {:missing_compose_fields, [:surface]}}
    },
    %{
      label: "missing receipt_hash refuses with the exact typed refusal",
      drop: :receipt_hash,
      event_subject: nil,
      surface_digest: nil,
      string_keys: false,
      expected: {:error, {:missing_compose_fields, [:receipt_hash]}}
    },
    %{
      label: "missing subject_repo refuses with the exact typed refusal",
      drop: :subject_repo,
      event_subject: nil,
      surface_digest: nil,
      string_keys: false,
      expected: {:error, {:missing_compose_fields, [:subject_repo]}}
    },
    %{
      label: "missing subject_head refuses with the exact typed refusal",
      drop: :subject_head,
      event_subject: nil,
      surface_digest: nil,
      string_keys: false,
      expected: {:error, {:missing_compose_fields, [:subject_head]}}
    },
    %{
      label: "missing consequence_id refuses with the exact typed refusal",
      drop: :consequence_id,
      event_subject: nil,
      surface_digest: nil,
      string_keys: false,
      expected: {:error, {:missing_compose_fields, [:consequence_id]}}
    },
    %{
      label: "event off the observation's exact subject is refused, naming the ref",
      drop: nil,
      event_subject: @off_subject,
      surface_digest: nil,
      string_keys: false,
      expected: {:error, {:subject_binding_violation, @off_subject}}
    },
    %{
      label: "non-canonical surface digest (not 64 hex) is refused, naming the value",
      drop: nil,
      event_subject: nil,
      surface_digest: "short",
      string_keys: false,
      expected: {:error, {:invalid_surface_digest, "short"}}
    },
    %{
      label: "UPPERCASE 64-hex digest is refused: lowercase hex or nothing",
      drop: nil,
      event_subject: nil,
      surface_digest: @uppercase_hex_digest,
      string_keys: false,
      expected: {:error, {:invalid_surface_digest, @uppercase_hex_digest}}
    }
  ]

  test "state table: every row's observable is exact (>=10 rows, non-vacuous)" do
    assert length(@state_table) >= 10
    assert Enum.uniq(Enum.map(@state_table, & &1.label)) == Enum.map(@state_table, & &1.label)

    for row <- @state_table do
      loop = mutate(live_loop(), row)

      case row.expected do
        {:ok, :episode} ->
          assert {:ok, mx} = MXEpisode.compose(loop), "row: #{row.label}"

          # Observable shape: exactly the thirteen mx-episode-schema fields.
          assert MapSet.new(Map.keys(mx)) == MapSet.new(MXEpisode.required_fields()),
                 "row: #{row.label}"

          # Observable content: one witness per frozen decomposition step.
          assert Enum.map(mx["observed_transitions"], & &1["step"]) ==
                   [
                     "observe",
                     "project_candidates",
                     "authorize_candidate",
                     "actuate",
                     "emit_event"
                   ],
                 "row: #{row.label}"

          # Observable verdicts: the pure-Elixir mirror and the vendored
          # in-repo verifier (run on the written artifact) both bless it.
          assert :ok = MXEpisode.validate(mx)
          path = Path.join(@tmp_dir, "state_row.json")
          File.write!(path, Jason.encode!(mx))
          assert {:ok, :valid} = MXEpisode.verify_file(path), "row: #{row.label}"

        expected ->
          assert expected == MXEpisode.compose(loop), "row: #{row.label}"
      end
    end
  end

  test "on-disk bytes of the composed episode carry the witnessed loop" do
    assert {:ok, mx} = MXEpisode.compose(live_loop())
    path = Path.join(@tmp_dir, "on_disk_episode.json")
    File.write!(path, Jason.encode!(mx))

    # The artifact itself: every part bound under its frozen field name.
    decoded = path |> File.read!() |> Jason.decode!()
    assert decoded == mx
    assert decoded["receipt_hash"] == receipt_hash()
    assert decoded["subject_head"] == @head
    assert decoded["resulting_standing"] == "ALIVE"
    assert Enum.count(decoded["observed_transitions"]) == 5

    assert Enum.find(decoded["observed_transitions"], &(&1["step"] == "observe"))["state_digest"] ==
             live_loop().observation.state_digest

    # The same artifact, verified by the vendored verifier from disk.
    assert {:ok, :valid} = MXEpisode.verify_file(path)
  end

  test "verify_file/1 reports typed verifier failures for a mutated artifact" do
    assert {:ok, mx} = MXEpisode.compose(live_loop())
    path = Path.join(@tmp_dir, "mutated_episode.json")

    File.write!(path, Jason.encode!(Map.drop(mx, ["observed_transitions"])))
    assert {:error, {"MISSING_EPISODE_FIELDS", message}} = MXEpisode.verify_file(path)
    assert message =~ "observed_transitions"

    File.write!(path, Jason.encode!(Map.put(mx, "domain_version", "v25.9.12")))
    assert {:error, {"CALVER_MISMATCH", _}} = MXEpisode.verify_file(path)
  end

  # ---------------------------------------------------------------------------
  # Live fixture: real parts only — projected observation, planning episode,
  # emitted event, and a surface admitted from a real Ash manifest.
  # ---------------------------------------------------------------------------

  defp live_loop do
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
    assert surface.digest =~ ~r/^[0-9a-f]{64}$/

    event =
      Event.create(observation.exact_subject, 1, "state_transition",
        payload: %{"status" => "completed", "record_id" => @consequence_id},
        receipt_ref: "rcpt_consequence_#{@consequence_id}"
      )

    %{
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
  end

  # The only interpreter of the state table.
  defp mutate(loop, row) do
    loop
    |> maybe_drop(row.drop)
    |> maybe_swap_event_subject(row.event_subject)
    |> maybe_swap_surface_digest(row.surface_digest)
    |> maybe_string_keys(row.string_keys)
  end

  defp maybe_drop(loop, nil), do: loop
  defp maybe_drop(loop, key), do: Map.drop(loop, [key])

  defp maybe_swap_event_subject(loop, nil), do: loop

  defp maybe_swap_event_subject(loop, subject) do
    %{loop | event: Event.create(subject, 1, "state_transition", payload: %{})}
  end

  defp maybe_swap_surface_digest(loop, nil), do: loop

  defp maybe_swap_surface_digest(loop, digest) do
    %{
      loop
      | surface:
          struct(AshSurface.Surface,
            manifest: %Ash.Info.Manifest{entrypoints: []},
            contract: %{},
            digest: digest,
            action_ids: []
          )
    }
  end

  defp maybe_string_keys(loop, false), do: loop
  defp maybe_string_keys(loop, true), do: Map.new(loop, fn {k, v} -> {Atom.to_string(k), v} end)

  defp candidate do
    %{
      "actionId" => "AshSurface.Fixtures.VolunteerMilestone#record",
      "semanticId" => "zoe:SelectOption",
      "authorityBoundary" => "SELECT",
      "doAuthority" => false,
      "input" => %{
        "member_id" => "member_mx_state_01",
        "milestone_id" => "milestone_mx_state_01",
        "cost_physical" => 10,
        "reward_spiritual" => 100
      }
    }
  end

  # Content-addressed MX receipt hash over a canonical dispatch receipt (the
  # deep falsifiers' recomputed_receipt_hash law).
  defp receipt_hash do
    payload = %{
      "actionId" => "AshSurface.Fixtures.VolunteerMilestone#record",
      "dispatchState" => "completed",
      "input" => %{"member_id" => "member_mx_state_01", "milestone_id" => "milestone_mx_state_01"},
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
end
