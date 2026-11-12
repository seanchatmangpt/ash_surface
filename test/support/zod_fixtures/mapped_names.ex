defmodule AshSurface.ZodFixtures.MappedNames.Domain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(AshSurface.ZodFixtures.MappedNames.Gadget)
  end
end

defmodule AshSurface.ZodFixtures.MappedNames.Gadget do
  @moduledoc "Field names with `?` and underscore-digit segments, plus a field-name override map."
  use Ash.Resource,
    domain: AshSurface.ZodFixtures.MappedNames.Domain,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:is_active?, :boolean, public?: true, default: true)
    attribute(:address_1, :string, public?: true)
    attribute(:line_2_text, :string, public?: true)
    attribute(:plain, :string, public?: true)

    attribute(:settings, :map,
      public?: true,
      constraints: [
        fields: [
          enabled?: [type: :boolean],
          retry_3_count: [type: :integer],
          label: [type: :string]
        ]
      ]
    )
  end

  calculations do
    calculate(:ready?, :boolean, expr(is_active?), public?: true)
    calculate(:slot_1_name, :string, expr(plain), public?: true)
  end

  actions do
    defaults([:read, create: [:is_active?, :address_1, :line_2_text, :plain, :settings]])
  end

  @doc "Wire-name override map: Elixir field -> exposed field name."
  def field_overrides do
    %{
      is_active?: "isActive",
      address_1: "address1",
      line_2_text: "line2Text",
      ready?: "isReady",
      slot_1_name: "slot1Name"
    }
  end
end
