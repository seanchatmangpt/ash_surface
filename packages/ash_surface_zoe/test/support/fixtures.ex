defmodule AshSurfaceZoe.Fixtures.Domain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(AshSurfaceZoe.Fixtures.VolunteerMilestone)
  end
end

defmodule AshSurfaceZoe.Fixtures.VolunteerMilestone do
  @moduledoc """
  Minimal Ash resource fixture for the human-runtime projector test.

  Deliberately duplicated from core's `AshSurface.Fixtures.VolunteerMilestone`
  (core `test/support` is not shared across the package boundary).
  """
  use Ash.Resource,
    domain: AshSurfaceZoe.Fixtures.Domain,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key(:id)
    attribute(:member_id, :string, public?: true, allow_nil?: false)
    attribute(:milestone_id, :string, public?: true, allow_nil?: false)
    attribute(:status, :string, public?: true, default: "completed")
  end

  actions do
    defaults([:read])

    create :record do
      accept([:member_id, :milestone_id])
    end
  end
end
