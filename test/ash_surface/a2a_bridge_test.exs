defmodule AshSurface.A2ABridgeTest do
  use ExUnit.Case, async: true

  # Chicago-style: real Ash resources, real AshA2A extension, real
  # `AshSurface.A2ABridge` calls against the pinned ash_a2a (~> 26.9,
  # locked 26.9.31) — no mocks, no doubles anywhere in this file.

  defmodule BridgeDomain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource(AshSurface.A2ABridgeTest.BridgeMilestone)
    end
  end

  defmodule BridgeMilestone do
    use Ash.Resource,
      domain: AshSurface.A2ABridgeTest.BridgeDomain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshA2A]

    attributes do
      uuid_primary_key(:id)
      attribute(:member_id, :string, public?: true, allow_nil?: false)
      attribute(:status, :string, public?: true, default: "completed")
    end

    actions do
      defaults([:read])
      create :record do
        accept([:member_id])
      end
    end
    # No `a2a` block: zero-configuration discovery — every public action
    # (read + record) is projected by the compiled capability index.
  end

  describe "agent_card_fragment/2" do
    test "builds a real %A2A.AgentCard{} from the resource's compiled index" do
      assert {:ok, %A2A.AgentCard{} = card} =
               AshSurface.A2ABridge.agent_card_fragment(BridgeMilestone)

      assert card.name == "ash_surface"
      assert card.version == AshSurface.schema_version()
      assert card.url == "http://localhost:4000"
      assert String.contains?(card.description, AshSurface.schema_version())
    end

    test "skills are the resource's real public actions, canonically id'd" do
      assert {:ok, %A2A.AgentCard{skills: skills}} =
               AshSurface.A2ABridge.agent_card_fragment(BridgeMilestone)

      skill_ids = Enum.map(skills, & &1.id)

      # The wire card's canonical skill ids carry no "Elixir." prefix
      # (`AshA2A.CapabilityIndex.AgentCardBuilder.skill_id/1`).
      assert "AshSurface.A2ABridgeTest.BridgeMilestone.read" in skill_ids
      assert "AshSurface.A2ABridgeTest.BridgeMilestone.record" in skill_ids
      assert length(skills) == 2
    end

    test "opts override identity fields on the wire card" do
      assert {:ok, %A2A.AgentCard{} = card} =
               AshSurface.A2ABridge.agent_card_fragment(BridgeMilestone,
                 name: "mx-agent",
                 url: "https://surface.example.com",
                 version: "9.9.9"
               )

      assert card.name == "mx-agent"
      assert card.url == "https://surface.example.com"
      assert card.version == "9.9.9"
    end

    test "refuses a resource without the AshA2A extension, fail-closed" do
      assert {:error, :not_compiled} =
               AshSurface.A2ABridge.agent_card_fragment(AshSurface.Fixtures.VolunteerMilestone)
    end
  end

  describe "skills/1" do
    test "returns the derived AshA2A.Skill structs" do
      assert {:ok, skills} = AshSurface.A2ABridge.skills(BridgeMilestone)
      assert Enum.all?(skills, &match?(%AshA2A.Skill{}, &1))
      assert MapSet.new(skills, & &1.action) == MapSet.new([:read, :record])
    end

    test "refuses a resource without the AshA2A extension" do
      assert {:error, :not_compiled} =
               AshSurface.A2ABridge.skills(AshSurface.Fixtures.VolunteerMilestone)
    end
  end
end
