defmodule AshSurface.AgentCardArtifactTest do
  use ExUnit.Case, async: false

  @moduledoc """
  Chicago court for the persisted agent card: regenerates the card from the
  real runtime path (compiled AshA2A capability index through
  `AshSurface.A2ABridge.agent_card_fragment/2`) and byte-compares against
  the on-disk `priv/generated/agent_card.json` artifact. No mocks.
  """

  # The fixture module name is load-bearing: skill ids embed it, so the test
  # must compile the byte-identical fixture source inlined in
  # scripts/agent_card_regen.exs (same module name AgentCardRegen.Fixture.*)
  # for the byte-compare to be admissible.
  @fixture_source ~s'''
  defmodule AgentCardRegen.Fixture.Domain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource(AgentCardRegen.Fixture.VolunteerMilestone)
    end
  end

  defmodule AgentCardRegen.Fixture.VolunteerMilestone do
    use Ash.Resource,
      domain: AgentCardRegen.Fixture.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshA2A]

    attributes do
      uuid_primary_key(:id)
      attribute(:member_id, :string, public?: true, allow_nil?: false)
      attribute(:milestone_id, :string, public?: true, allow_nil?: false)
      attribute(:cost_physical, :integer, public?: true, allow_nil?: false)
      attribute(:reward_spiritual, :integer, public?: true, allow_nil?: false)
      attribute(:status, :string, public?: true, default: "completed")
    end

    actions do
      defaults([:read])

      create :record do
        accept([:member_id, :milestone_id, :cost_physical, :reward_spiritual])
      end
    end
  end
  '''

  setup_all do
    Code.compile_string(@fixture_source)
    :ok
  end

  test "on-disk artifact matches a fresh regeneration, byte for byte" do
    {:ok, card} =
      AshSurface.A2ABridge.agent_card_fragment(AgentCardRegen.Fixture.VolunteerMilestone)

    tmp = "priv/generated/agent_card.json.tmp"

    assert :ok = AshSurface.AgentCardArtifact.persist(card, tmp)

    assert File.read!(tmp) == File.read!(AshSurface.AgentCardArtifact.default_path()),
           "priv/generated/agent_card.json is stale -- regenerate with " <>
             "`mix run scripts/agent_card_regen.exs`"
  after
    File.rm("priv/generated/agent_card.json.tmp")
  end

  test "artifact parses as JSON and carries the bridge's identity defaults" do
    assert {:ok, map} = Jason.decode(File.read!(AshSurface.AgentCardArtifact.default_path()))
    assert map["name"] == "ash_surface"
    assert map["version"] == AshSurface.schema_version()
    assert map["capabilities"]["streaming"] == true
    assert length(map["skills"]) == 2
  end
end
