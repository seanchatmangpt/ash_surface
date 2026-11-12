defmodule AshSurface.ZodFixtures.Constraints.Domain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(AshSurface.ZodFixtures.Constraints.Form)
  end
end

defmodule AshSurface.ZodFixtures.Constraints.Kind do
  @moduledoc false
  use Ash.Type.Enum, values: [:basic, :premium]
end

defmodule AshSurface.ZodFixtures.Constraints.Stats do
  @moduledoc false
  defstruct [:count, :label]
end

defmodule AshSurface.ZodFixtures.Constraints.Form do
  @moduledoc """
  Real ETS resource for the section-schema constraint court (lane b1a): a
  `match` regex containing `\\d`, `allow_empty?: false`, an array with item
  constraints, an enum, a defaulted attribute, a typed struct and a union.
  """
  use Ash.Resource,
    domain: AshSurface.ZodFixtures.Constraints.Domain,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key(:id, public?: true)

    attribute(:name, :string,
      public?: true,
      allow_nil?: false,
      constraints: [match: ~r/^[a-z\d]+$/, allow_empty?: false, max_length: 80]
    )

    attribute(:tags, {:array, :string},
      public?: true,
      constraints: [items: [min_length: 2, max_length: 5]]
    )

    attribute(:kind, AshSurface.ZodFixtures.Constraints.Kind, public?: true, allow_nil?: false)
    attribute(:level, :integer, public?: true, default: 1, constraints: [min: 1, max: 9])

    attribute(:stats, :struct,
      public?: true,
      constraints: [
        instance_of: AshSurface.ZodFixtures.Constraints.Stats,
        fields: [
          count: [type: :integer, allow_nil?: false, constraints: [min: 0]],
          label: [type: :string]
        ]
      ]
    )

    attribute(:ref, :union,
      public?: true,
      constraints: [types: [text: [type: :string], number: [type: :integer]]]
    )
  end

  actions do
    defaults([:read])

    create :create do
      primary?(true)
      accept([:name, :tags, :kind, :level, :stats, :ref])

      argument(:code, :string,
        allow_nil?: false,
        constraints: [match: ~r/^\d{3}$/, max_length: 3]
      )
    end
  end
end
