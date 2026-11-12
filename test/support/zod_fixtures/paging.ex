defmodule AshSurface.ZodFixtures.Paging.Domain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(AshSurface.ZodFixtures.Paging.Row)
  end
end

defmodule AshSurface.ZodFixtures.Paging.Row do
  @moduledoc "One read action per pagination shape."
  use Ash.Resource,
    domain: AshSurface.ZodFixtures.Paging.Domain,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:name, :string, public?: true, allow_nil?: false)
    attribute(:rank, :integer, public?: true)
    attribute(:secret, :string, public?: true, filterable?: false, sortable?: false)
    attribute(:only_filter, :string, public?: true, sortable?: false)
    attribute(:only_sort, :string, public?: true, filterable?: false)
  end

  actions do
    create :create do
      primary?(true)
      accept([:name, :rank, :secret, :only_filter, :only_sort])
    end

    read :read do
      primary?(true)
    end

    read(:list_all)

    read :offset_only do
      pagination do
        offset?(true)
        keyset?(false)
        default_limit(10)
        countable(true)
        required?(false)
      end
    end

    read :keyset_only do
      pagination do
        offset?(false)
        keyset?(true)
        default_limit(10)
        required?(false)
      end
    end

    read :mixed do
      pagination do
        offset?(true)
        keyset?(true)
        default_limit(25)
        max_page_size(100)
        countable(true)
        required?(false)
      end
    end

    read :required_paged do
      pagination do
        offset?(true)
        keyset?(true)
        default_limit(5)
        required?(true)
      end
    end

    read :optional_paged do
      pagination do
        offset?(true)
        required?(false)
      end
    end
  end
end
