defmodule AshSurface.ZodFixtures.Relations.Domain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(AshSurface.ZodFixtures.Relations.Author)
    resource(AshSurface.ZodFixtures.Relations.Post)
    resource(AshSurface.ZodFixtures.Relations.Comment)
    resource(AshSurface.ZodFixtures.Relations.Profile)
  end
end

defmodule AshSurface.ZodFixtures.Relations.Author do
  @moduledoc false
  use Ash.Resource,
    domain: AshSurface.ZodFixtures.Relations.Domain,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:name, :string, public?: true, allow_nil?: false)
  end

  relationships do
    has_many(:posts, AshSurface.ZodFixtures.Relations.Post,
      destination_attribute: :author_id,
      public?: true
    )

    has_one(:profile, AshSurface.ZodFixtures.Relations.Profile,
      destination_attribute: :author_id,
      public?: true
    )
  end

  actions do
    defaults([:read, create: [:name]])
  end
end

defmodule AshSurface.ZodFixtures.Relations.Profile do
  @moduledoc false
  use Ash.Resource,
    domain: AshSurface.ZodFixtures.Relations.Domain,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:bio, :string, public?: true)
  end

  relationships do
    belongs_to(:author, AshSurface.ZodFixtures.Relations.Author, public?: true)
  end

  actions do
    defaults([:read, create: [:bio, :author_id]])
  end
end

defmodule AshSurface.ZodFixtures.Relations.Post do
  @moduledoc false
  use Ash.Resource,
    domain: AshSurface.ZodFixtures.Relations.Domain,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:title, :string, public?: true, allow_nil?: false)
  end

  relationships do
    belongs_to(:author, AshSurface.ZodFixtures.Relations.Author, public?: true)

    has_many(:comments, AshSurface.ZodFixtures.Relations.Comment,
      destination_attribute: :post_id,
      public?: true
    )
  end

  actions do
    defaults([:read, create: [:title, :author_id]])
  end
end

defmodule AshSurface.ZodFixtures.Relations.Comment do
  @moduledoc false
  use Ash.Resource,
    domain: AshSurface.ZodFixtures.Relations.Domain,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:body, :string, public?: true, allow_nil?: false)
  end

  relationships do
    belongs_to(:post, AshSurface.ZodFixtures.Relations.Post, public?: true)
  end

  actions do
    defaults([:read, create: [:body, :post_id]])
  end
end
