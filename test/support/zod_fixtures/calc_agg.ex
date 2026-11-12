defmodule AshSurface.ZodFixtures.CalcAgg.Domain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(AshSurface.ZodFixtures.CalcAgg.Item)
    resource(AshSurface.ZodFixtures.CalcAgg.Line)
  end
end

defmodule AshSurface.ZodFixtures.CalcAgg.Line do
  @moduledoc false
  use Ash.Resource,
    domain: AshSurface.ZodFixtures.CalcAgg.Domain,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:qty, :integer, public?: true)
    attribute(:price, :float, public?: true)
    attribute(:label, :string, public?: true)
    attribute(:active, :boolean, public?: true, default: true)
  end

  relationships do
    belongs_to(:item, AshSurface.ZodFixtures.CalcAgg.Item, public?: true)
  end

  actions do
    defaults([:read, create: [:qty, :price, :label, :active, :item_id]])
  end
end

defmodule AshSurface.ZodFixtures.CalcAgg.Item do
  @moduledoc "Expression calculations (args, constraints, zero-arg) and every aggregate kind."
  use Ash.Resource,
    domain: AshSurface.ZodFixtures.CalcAgg.Domain,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:name, :string, public?: true, allow_nil?: false)
  end

  relationships do
    has_many(:lines, AshSurface.ZodFixtures.CalcAgg.Line,
      destination_attribute: :item_id,
      public?: true
    )
  end

  calculations do
    calculate(:shout, :string, expr(string_upcase(name)), public?: true)

    calculate :padded, :string, expr(^arg(:prefix) <> name) do
      public?(true)
      argument(:prefix, :string, allow_nil?: false, constraints: [min_length: 1, max_length: 5])
    end

    calculate :scaled, :integer, expr(^arg(:factor) * 2) do
      public?(true)
      argument(:factor, :integer, allow_nil?: false, constraints: [min: 1, max: 10])
    end

    calculate :tiered, :string, expr(^arg(:tier)) do
      public?(true)
      argument(:tier, :atom, allow_nil?: false, constraints: [one_of: [:gold, :silver, :bronze]])
    end

    calculate :matched, :string, expr(^arg(:code)) do
      public?(true)
      argument(:code, :string, allow_nil?: false, constraints: [match: ~r/^[A-Z]{3}$/])
    end
  end

  aggregates do
    count(:line_count, :lines, public?: true)
    sum(:total_qty, :lines, :qty, public?: true)
    avg(:avg_price, :lines, :price, public?: true)
    min(:min_price, :lines, :price, public?: true)
    max(:max_price, :lines, :price, public?: true)
    first(:first_label, :lines, :label, public?: true)
    list(:all_labels, :lines, :label, public?: true)
    exists(:has_lines, :lines, public?: true)
  end

  actions do
    defaults([:read, create: [:name]])
  end
end
