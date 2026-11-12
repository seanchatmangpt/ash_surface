defmodule AshSurface.ChannelFixtures.Endpoint do
  @moduledoc false
  def broadcast(_topic, _event, _payload), do: :ok
  def broadcast_from(_from, _topic, _event, _payload), do: :ok
end

defmodule AshSurface.ChannelFixtures.Item do
  @moduledoc "Map-returning publications (mirrors ash_typescript ChannelItem)."
  use Ash.Resource, domain: nil, notifiers: [Ash.Notifier.PubSub]

  pub_sub do
    module(AshSurface.ChannelFixtures.Endpoint)
    prefix("items")

    publish(:create, [:id],
      event: "item_created",
      public?: true,
      returns: :map,
      constraints: [
        fields: [
          id: [type: :uuid, allow_nil?: false],
          name: [type: :string, allow_nil?: true]
        ]
      ],
      transform: fn n -> %{id: n.data.id, name: n.data.name} end
    )

    publish(:update, [:id],
      event: "item_updated",
      public?: true,
      returns: :map,
      constraints: [fields: [count: [type: :integer, allow_nil?: false]]],
      transform: fn _ -> %{count: 1} end
    )
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, public?: true)
  end

  actions do
    defaults([:read, :create, :update, :destroy])
  end
end

defmodule AshSurface.ChannelFixtures.Alert do
  @moduledoc "Second resource: a datetime field, a non-public and a returns-less publication."
  use Ash.Resource, domain: nil, notifiers: [Ash.Notifier.PubSub]

  pub_sub do
    module(AshSurface.ChannelFixtures.Endpoint)
    prefix("alerts")

    publish(:create, [:id],
      event: "alert_cleared",
      public?: true,
      returns: :map,
      constraints: [fields: [cleared_at: [type: :utc_datetime, allow_nil?: false]]],
      transform: fn _ -> %{cleared_at: DateTime.utc_now()} end
    )

    publish(:update, [:id],
      event: "alert_hidden",
      returns: :map,
      constraints: [fields: [x: [type: :integer]]],
      transform: fn _ -> %{x: 1} end
    )

    publish(:destroy, [:id], event: "alert_gone", public?: true)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:message, :string, public?: true)
  end

  actions do
    defaults([:read, :create, :update, :destroy])
  end
end

defmodule AshSurface.ChannelFixtures.Scalar do
  @moduledoc "Publication whose payload is a string: not an object, refused."
  use Ash.Resource, domain: nil, notifiers: [Ash.Notifier.PubSub]

  pub_sub do
    module(AshSurface.ChannelFixtures.Endpoint)
    prefix("scalars")

    publish(:create, [:id],
      event: "scalar_made",
      public?: true,
      returns: :string,
      transform: fn _ -> "s" end
    )
  end

  attributes do
    uuid_primary_key(:id)
  end

  actions do
    defaults([:read, :create])
  end
end

defmodule AshSurface.ChannelFixtures.Dup do
  @moduledoc "Same event name as Item.item_created: duplicate within one channel."
  use Ash.Resource, domain: nil, notifiers: [Ash.Notifier.PubSub]

  pub_sub do
    module(AshSurface.ChannelFixtures.Endpoint)
    prefix("dups")

    publish(:create, [:id],
      event: "item_created",
      public?: true,
      returns: :map,
      constraints: [fields: [id: [type: :uuid, allow_nil?: false]]],
      transform: fn n -> %{id: n.data.id} end
    )
  end

  attributes do
    uuid_primary_key(:id)
  end

  actions do
    defaults([:read, :create])
  end
end
