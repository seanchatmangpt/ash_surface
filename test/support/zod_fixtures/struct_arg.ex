defmodule AshSurface.ZodFixtures.StructArg.Domain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(AshSurface.ZodFixtures.StructArg.Node)
    resource(AshSurface.ZodFixtures.StructArg.Holder)
  end
end

defmodule AshSurface.ZodFixtures.StructArg.Node do
  @moduledoc "Self-referential resource used as a struct argument (cyclic instance_of)."
  use Ash.Resource,
    domain: AshSurface.ZodFixtures.StructArg.Domain,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:label, :string, public?: true, allow_nil?: false)
    attribute(:weight, :integer, public?: true, allow_nil?: true, constraints: [min: 0])

    attribute(:child, :struct,
      public?: true,
      allow_nil?: true,
      constraints: [instance_of: AshSurface.ZodFixtures.StructArg.Node]
    )
  end

  actions do
    defaults([:read])
  end
end

defmodule AshSurface.ZodFixtures.StructArg.Holder do
  @moduledoc "Actions taking struct arguments: instance_of resource, fields constraint."
  use Ash.Resource,
    domain: AshSurface.ZodFixtures.StructArg.Domain,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key(:id, public?: true)
  end

  actions do
    defaults([:read])

    create :take do
      accept([])

      argument(:node, :struct,
        allow_nil?: false,
        constraints: [instance_of: AshSurface.ZodFixtures.StructArg.Node]
      )

      argument(:maybe_node, :struct,
        allow_nil?: true,
        constraints: [instance_of: AshSurface.ZodFixtures.StructArg.Node]
      )

      argument(:typed, :struct,
        allow_nil?: true,
        constraints: [
          fields: [
            count: [type: :integer, allow_nil?: false, constraints: [min: 0]],
            note: [type: :string, allow_nil?: true]
          ]
        ]
      )
    end
  end
end
