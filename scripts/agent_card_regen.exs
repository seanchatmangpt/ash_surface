# Regenerates priv/generated/agent_card.json from the real runtime path:
# an Ash resource's compiled AshA2A capability index through
# AshSurface.A2ABridge.agent_card_fragment/2, serialized deterministically
# by AshSurface.AgentCardArtifact. Run:
#
#   mix run scripts/agent_card_regen.exs
#
# The fixture mirrors test/support/fixtures.ex plus the AshA2A extension the
# bridge requires (the test-support resource carries no extension, by
# design -- the bridge refuses it, fail-closed).

fixture_source = ~s'''
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

Code.compile_string(fixture_source)

{:ok, card} =
  AshSurface.A2ABridge.agent_card_fragment(AgentCardRegen.Fixture.VolunteerMilestone)

:ok = AshSurface.AgentCardArtifact.persist(card, AshSurface.AgentCardArtifact.default_path())
IO.puts("wrote #{AshSurface.AgentCardArtifact.default_path()}")
