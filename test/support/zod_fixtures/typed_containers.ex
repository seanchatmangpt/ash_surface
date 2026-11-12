defmodule AshSurface.ZodFixtures.TypedContainers.Domain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(AshSurface.ZodFixtures.TypedContainers.Holder)
  end
end

defmodule AshSurface.ZodFixtures.TypedContainers.Stats do
  @moduledoc "Typed struct (field-constrained :struct)."
  use Ash.Type.NewType,
    subtype_of: :struct,
    constraints: [
      instance_of: AshSurface.ZodFixtures.TypedContainers.StatsStruct,
      fields: [
        count: [type: :integer, allow_nil?: false],
        label: [type: :string]
      ]
    ]
end

defmodule AshSurface.ZodFixtures.TypedContainers.StatsStruct do
  @moduledoc false
  defstruct [:count, :label]
end

defmodule AshSurface.ZodFixtures.TypedContainers.Point do
  @moduledoc "Tuple type."
  use Ash.Type.NewType,
    subtype_of: :tuple,
    constraints: [
      fields: [
        x: [type: :float, allow_nil?: false],
        y: [type: :float, allow_nil?: false]
      ]
    ]
end

defmodule AshSurface.ZodFixtures.TypedContainers.Options do
  @moduledoc "Keyword type."
  use Ash.Type.NewType,
    subtype_of: :keyword,
    constraints: [
      fields: [
        verbose: [type: :boolean],
        retries: [type: :integer, constraints: [min: 0, max: 9]]
      ]
    ]
end

defmodule AshSurface.ZodFixtures.TypedContainers.NodeE do
  @moduledoc "Leaf (diamond bottom)."
  use Ash.Resource, data_layer: :embedded, domain: nil

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:value, :string, public?: true)
  end
end

defmodule AshSurface.ZodFixtures.TypedContainers.NodeD do
  @moduledoc "Depends on NodeE."
  use Ash.Resource, data_layer: :embedded, domain: nil

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:leaf, AshSurface.ZodFixtures.TypedContainers.NodeE, public?: true)
  end
end

defmodule AshSurface.ZodFixtures.TypedContainers.NodeC do
  @moduledoc "Depends on NodeD."
  use Ash.Resource, data_layer: :embedded, domain: nil

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:down, AshSurface.ZodFixtures.TypedContainers.NodeD, public?: true)
  end
end

defmodule AshSurface.ZodFixtures.TypedContainers.NodeB do
  @moduledoc "Depends on NodeD."
  use Ash.Resource, data_layer: :embedded, domain: nil

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:down, AshSurface.ZodFixtures.TypedContainers.NodeD, public?: true)
  end
end

defmodule AshSurface.ZodFixtures.TypedContainers.NodeA do
  @moduledoc "Root; depends on NodeB and NodeC (diamond top)."
  use Ash.Resource, data_layer: :embedded, domain: nil

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:left, AshSurface.ZodFixtures.TypedContainers.NodeB, public?: true)
    attribute(:right, AshSurface.ZodFixtures.TypedContainers.NodeC, public?: true)
  end
end

defmodule AshSurface.ZodFixtures.TypedContainers.Holder do
  @moduledoc false
  use Ash.Resource,
    domain: AshSurface.ZodFixtures.TypedContainers.Domain,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:stats, AshSurface.ZodFixtures.TypedContainers.Stats, public?: true)
    attribute(:point, AshSurface.ZodFixtures.TypedContainers.Point, public?: true)
    attribute(:options, AshSurface.ZodFixtures.TypedContainers.Options, public?: true)
    attribute(:root, AshSurface.ZodFixtures.TypedContainers.NodeA, public?: true)

    attribute(:mixed, {:array, :union},
      public?: true,
      constraints: [
        items: [
          types: [
            text: [type: :string],
            count: [type: :integer],
            stats: [type: AshSurface.ZodFixtures.TypedContainers.Stats]
          ]
        ]
      ]
    )

    attribute(:choice, :union,
      public?: true,
      constraints: [
        types: [
          many: [type: {:array, :string}],
          one: [type: :integer]
        ]
      ]
    )
  end

  actions do
    defaults([:read, create: [:stats, :point, :options, :root, :mixed, :choice]])
  end
end
