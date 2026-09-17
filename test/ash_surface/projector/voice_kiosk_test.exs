defmodule AshSurface.Projector.VoiceKioskTest do
  @moduledoc """
  State-based Chicago tests for `AshSurface.Projector.VoiceKiosk`.

  Covers the three claims of the extensibility proof: per-action voice prompts
  from `presentation.label` (with humanized fallback), slot grammar hints from
  schema inputs, and capability gating — `authority_required` actions are
  phrased as confirmations and are never auto-executions. Hand-built
  `AshSurface.Surface` state; no mocks, no env, no db, no network.

  The flow-state table pins the authority-admitted vs not-admitted frontier
  (10 rows) as data: CONFIRM always required for admitted plans, autoExecute
  false in every emitted plan except the ungated OBSERVE answer, and ANSWER
  phrasing within the DO family only for never-delegated DO.
  """

  use ExUnit.Case, async: false

  alias AshSurface.Fixtures.VolunteerMilestone
  alias AshSurface.Projector.VoiceKiosk

  @resource "Volunteer.Milestone"

  defp surface(actions, resources \\ %{}) do
    %AshSurface.Surface{
      manifest: nil,
      contract: %{
        "surface" => %{"actions" => actions},
        "manifest" => %{"resources" => resources}
      },
      digest: "digest-test",
      action_ids: Enum.map(actions, & &1["id"])
    }
  end

  defp read_action(overides \\ %{}) do
    Map.merge(
      %{
        "id" => "Volunteer.Milestone#read",
        "resource" => @resource,
        "action" => "read",
        "authorityBoundary" => "OBSERVE",
        "doAuthority" => false,
        "profile" => %{}
      },
      overides
    )
  end

  defp fields_resource do
    %{
      "res" => %{
        "name" => @resource,
        "fields" => %{
          "id" => %{"type" => %{"kind" => "uuid"}, "allow_nil?" => false},
          "member_id" => %{"type" => %{"kind" => "string"}, "allow_nil?" => false},
          "cost_physical" => %{"type" => %{"kind" => "integer"}, "allow_nil?" => false},
          "mood_note" => %{"type" => %{"kind" => "string"}, "allow_nil?" => true},
          "payload" => %{"type" => %{"kind" => "map"}, "allow_nil?" => true}
        }
      }
    }
  end

  describe "voice prompts" do
    test "an action's prompt comes from presentation.label" do
      action =
        read_action(%{
          "profile" => %{"presentation" => %{"label" => "Hear today's milestones"}}
        })

      assert [%{"prompt" => "Hear today's milestones"}] =
               VoiceKiosk.project_ir(surface([action]))["intents"]
    end

    test "an action without a presentation.label falls back to a humanized action name" do
      assert [%{"prompt" => "read"}] = VoiceKiosk.project_ir(surface([read_action()]))["intents"]

      gated = %{
        "id" => "Volunteer.Milestone#record",
        "resource" => @resource,
        "action" => "record_milestone",
        "authorityBoundary" => "DO",
        "doAuthority" => true,
        "profile" => %{}
      }

      assert [%{"prompt" => "Please confirm: record milestone"}] =
               VoiceKiosk.project_ir(surface([gated]))["intents"]
    end
  end

  describe "slot grammar hints from schema inputs" do
    test "every schema input field becomes a slot with a grammar hint and required flag" do
      intent =
        surface([read_action()], fields_resource()) |> VoiceKiosk.project_ir() |> fetch_intent()

      assert intent["slots"] ==
               [
                 %{"name" => "cost_physical", "grammar" => "a whole number", "required" => true},
                 %{"name" => "id", "grammar" => "an identifier", "required" => true},
                 %{"name" => "member_id", "grammar" => "free text", "required" => true},
                 %{"name" => "mood_note", "grammar" => "free text", "required" => false},
                 %{"name" => "payload", "grammar" => "any value", "required" => false}
               ]
    end

    test "an action whose resource has no schema yields no slots" do
      intent =
        surface([%{"id" => "Orphan#read", "resource" => "Unknown", "action" => "read"}])
        |> VoiceKiosk.project_ir()
        |> fetch_intent()

      assert intent["slots"] == []
    end
  end

  describe "capability gating" do
    test "a doAuthority action is a confirmation and never an auto-execution" do
      gated = %{
        "id" => "Volunteer.Milestone#record",
        "resource" => @resource,
        "action" => "record",
        "authorityBoundary" => "DO",
        "doAuthority" => true,
        "profile" => %{"presentation" => %{"label" => "Record a milestone"}}
      }

      intent = surface([gated]) |> VoiceKiosk.project_ir() |> fetch_intent()

      assert intent["mode"] == "CONFIRM"
      assert intent["autoExecute"] == false
      assert intent["prompt"] == "Please confirm: Record a milestone"
    end

    test "the authority_required capability forces confirmation even on an OBSERVE action" do
      action = read_action(%{"profile" => %{"capabilities" => ["authority_required"]}})

      intent = surface([action]) |> VoiceKiosk.project_ir() |> fetch_intent()

      assert intent["mode"] == "CONFIRM"
      assert intent["autoExecute"] == false
    end

    test "an ungated OBSERVE action answers directly and may auto-execute" do
      intent = surface([read_action()]) |> VoiceKiosk.project_ir() |> fetch_intent()

      assert intent["mode"] == "ANSWER"
      assert intent["autoExecute"] == true
    end

    test "unrelated capabilities do not gate" do
      action = read_action(%{"profile" => %{"capabilities" => ["offline_cache"]}})

      intent = surface([action]) |> VoiceKiosk.project_ir() |> fetch_intent()

      assert intent["mode"] == "ANSWER"
      assert intent["autoExecute"] == true
    end
  end

  # Slot data of fields_resource() asserted as literal data: every flow-state
  # row's expected intent embeds this exact list, so each row pins the whole
  # dialogue structure (actionId, prompt, slots, mode, autoExecute), not just
  # the gating bits.
  @slot_data [
    %{"name" => "cost_physical", "grammar" => "a whole number", "required" => true},
    %{"name" => "id", "grammar" => "an identifier", "required" => true},
    %{"name" => "member_id", "grammar" => "free text", "required" => true},
    %{"name" => "mood_note", "grammar" => "free text", "required" => false},
    %{"name" => "payload", "grammar" => "any value", "required" => false}
  ]

  # Documented nuance (flow states): ANSWER phrasing is a dialogue mode, not
  # an execution grant. A DO action whose authority was never delegated
  # (doAuthority=false, no admitted "authority_required" capability) is still
  # phrased as an ANSWER, yet its plans carry autoExecute=false — the only
  # auto-executable state in the whole table is an ungated OBSERVE answer.
  # Delegated authority always confirms: CONFIRM is required and no
  # authority-admitted plan ever auto-executes.
  @flow_state_table [
    %{
      name: "delegated DO via the doAuthority flag",
      boundary: "DO",
      do_authority: true,
      capabilities: [],
      expect: %{mode: "CONFIRM", prompt: "Please confirm: record milestone", auto: false}
    },
    %{
      name: "delegated DO via an admitted authority_required capability",
      boundary: "DO",
      do_authority: false,
      capabilities: ["authority_required"],
      expect: %{mode: "CONFIRM", prompt: "Please confirm: record milestone", auto: false}
    },
    %{
      name: "doAuthority dominates an OBSERVE boundary",
      boundary: "OBSERVE",
      do_authority: true,
      capabilities: [],
      expect: %{mode: "CONFIRM", prompt: "Please confirm: record milestone", auto: false}
    },
    %{
      name: "authority_required gates an OBSERVE action",
      boundary: "OBSERVE",
      do_authority: false,
      capabilities: ["authority_required"],
      expect: %{mode: "CONFIRM", prompt: "Please confirm: record milestone", auto: false}
    },
    %{
      name: "both delegation signals present on a DO action",
      boundary: "DO",
      do_authority: true,
      capabilities: ["authority_required"],
      expect: %{mode: "CONFIRM", prompt: "Please confirm: record milestone", auto: false}
    },
    %{
      name: "authority_required gates even among unrelated capabilities",
      boundary: "OBSERVE",
      do_authority: false,
      capabilities: ["authority_required", "offline_cache"],
      expect: %{mode: "CONFIRM", prompt: "Please confirm: record milestone", auto: false}
    },
    %{
      name: "ungated OBSERVE answers and may auto-execute",
      boundary: "OBSERVE",
      do_authority: false,
      capabilities: [],
      expect: %{mode: "ANSWER", prompt: "record milestone", auto: true}
    },
    %{
      name: "ungated OBSERVE with unrelated capabilities answers and may auto-execute",
      boundary: "OBSERVE",
      do_authority: false,
      capabilities: ["offline_cache"],
      expect: %{mode: "ANSWER", prompt: "record milestone", auto: true}
    },
    %{
      name: "never-delegated DO: ANSWER phrasing, never auto-execute",
      boundary: "DO",
      do_authority: false,
      capabilities: [],
      expect: %{mode: "ANSWER", prompt: "record milestone", auto: false}
    },
    %{
      name: "never-delegated DO with unrelated capabilities: ANSWER phrasing, never auto-execute",
      boundary: "DO",
      do_authority: false,
      capabilities: ["offline_cache"],
      expect: %{mode: "ANSWER", prompt: "record milestone", auto: false}
    }
  ]

  describe "flow state table (authority-admitted vs not)" do
    @describetag flow_states: true

    for {row, i} <- Enum.with_index(@flow_state_table, 1) do
      @tag row: row, row_no: i
      test "row #{i}: #{row.name}", %{row: row, row_no: i} do
        assert flow_intent(row, i) == %{
                 "actionId" => "Volunteer.Milestone#flow-row-#{i}",
                 "prompt" => row.expect.prompt,
                 "slots" => @slot_data,
                 "mode" => row.expect.mode,
                 "autoExecute" => row.expect.auto
               }
      end
    end

    test "CONFIRM is always required: every authority-admitted row confirms and no admitted plan auto-executes" do
      for {row, i} <- Enum.with_index(@flow_state_table, 1), row.expect.mode == "CONFIRM" do
        intent = flow_intent(row, i)

        assert intent["mode"] == "CONFIRM"
        assert intent["prompt"] == "Please confirm: record milestone"
        assert intent["autoExecute"] == false
      end
    end

    test "autoExecute is false in every emitted plan except the ungated OBSERVE answer" do
      for {row, i} <- Enum.with_index(@flow_state_table, 1) do
        intent = flow_intent(row, i)
        auto_executable? = row.expect.mode == "ANSWER" and row.boundary == "OBSERVE"

        assert intent["autoExecute"] == auto_executable?
      end
    end

    test "within the DO family, ANSWER phrasing belongs only to never-delegated DO and never auto-executes" do
      for {row, i} <- Enum.with_index(@flow_state_table, 1), row.boundary == "DO" do
        intent = flow_intent(row, i)
        delegated? = row.expect.mode == "CONFIRM"

        assert intent["mode"] == if(delegated?, do: "CONFIRM", else: "ANSWER")

        assert intent["prompt"] ==
                 if(delegated?, do: "Please confirm: record milestone", else: "record milestone")

        assert intent["autoExecute"] == false
      end
    end
  end

  describe "determinism" do
    test "intents are sorted by actionId regardless of contract order, and projection is pure" do
      actions = [
        %{"id" => "C#read", "resource" => @resource, "action" => "read"},
        %{"id" => "A#read", "resource" => @resource, "action" => "read"},
        %{"id" => "B#read", "resource" => @resource, "action" => "read"}
      ]

      ir = VoiceKiosk.project_ir(surface(actions))
      assert Enum.map(ir["intents"], & &1["actionId"]) == ["A#read", "B#read", "C#read"]
      assert ir == VoiceKiosk.project_ir(surface(Enum.reverse(actions)))
      assert ir == VoiceKiosk.project_ir(surface(actions), [])
    end

    test "the IR carries the surface digest and is JSON-serializable" do
      ir = surface([read_action()]) |> VoiceKiosk.project_ir()

      assert ir["kind"] == "voice_kiosk"
      assert ir["surfaceDigest"] == "digest-test"
      assert {:ok, decoded} = Jason.decode(Jason.encode!(ir))
      assert decoded == ir
    end
  end

  describe "as a fifth projector through AshSurface.project/3" do
    test "a real manifest surface projects into one gated voice artifact" do
      assert {:ok, manifest} =
               Ash.Info.Manifest.generate(
                 otp_app: :ash_surface,
                 action_entrypoints: [
                   {VolunteerMilestone, :record},
                   {VolunteerMilestone, :read}
                 ]
               )

      assert {:ok, surface} = AshSurface.from_manifest(manifest, profile: delegated_authority())

      assert {:ok, artifacts, meta} = AshSurface.project(surface, VoiceKiosk, prefix: "kiosk")

      assert meta == %{prefix: "kiosk", intent_count: 2}
      assert {:ok, ir} = Jason.decode(artifacts["kiosk.voice.json"])

      assert [
               %{"mode" => "ANSWER", "autoExecute" => true} = read,
               %{"mode" => "CONFIRM", "autoExecute" => false} = record
             ] =
               ir["intents"]

      assert record["actionId"] == "AshSurface.Fixtures.VolunteerMilestone#record"
      assert read["actionId"] == "AshSurface.Fixtures.VolunteerMilestone#read"

      # Schema inputs of the real resource become slot grammar hints.
      assert Enum.map(read["slots"], & &1["name"]) ==
               Enum.sort([
                 "cost_physical",
                 "id",
                 "member_id",
                 "milestone_id",
                 "reward_spiritual",
                 "status"
               ])
    end
  end

  # v26.9.16 delegation law (v10): authorityBoundary/doAuthority are delegated
  # facts, never derived from action type. The intents this test pins (read =
  # auto-executable ANSWER, record = gated CONFIRM) are delegated explicitly
  # through the action profile instead of relying on the pre-v10 local
  # derivation this projector was originally authored against.
  defp delegated_authority do
    %{
      "actions" => %{
        "AshSurface.Fixtures.VolunteerMilestone#read" => %{
          "authorityBoundary" => "OBSERVE",
          "doAuthority" => false
        },
        "AshSurface.Fixtures.VolunteerMilestone#record" => %{
          "authorityBoundary" => "DO",
          "doAuthority" => true
        }
      }
    }
  end

  defp fetch_intent(ir), do: Enum.at(ir["intents"], 0)

  # Builds one flow-state table row's action state: delegated-authority facts
  # (boundary/doAuthority/capabilities) set explicitly per row, per the v10
  # delegation law — never derived from the action type.
  defp flow_action(row, i) do
    %{
      "id" => "Volunteer.Milestone#flow-row-#{i}",
      "resource" => @resource,
      "action" => "record_milestone",
      "authorityBoundary" => row.boundary,
      "doAuthority" => row.do_authority,
      "profile" => %{"capabilities" => row.capabilities}
    }
  end

  defp flow_intent(row, i) do
    surface([flow_action(row, i)], fields_resource()) |> VoiceKiosk.project_ir() |> fetch_intent()
  end
end
