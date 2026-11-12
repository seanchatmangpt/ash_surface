defmodule AshSurface.Ported.TypedChannel.Fixtures do
  @moduledoc false
  defmodule Endpoint do
    @moduledoc false
    def broadcast(_t, _e, _p), do: :ok
    def broadcast_from(_f, _t, _e, _p), do: :ok
  end

  defmodule Status do
    @moduledoc false
    use Ash.Type.Enum, values: [:pending, :done]
  end

  defmodule Item do
    @moduledoc false
    use Ash.Resource, domain: nil, notifiers: [Ash.Notifier.PubSub]

    pub_sub do
      module(AshSurface.Ported.TypedChannel.Fixtures.Endpoint)
      prefix("items")

      publish(:create, [:id],
        event: "item_created",
        public?: true,
        returns: :map,
        constraints: [
          fields: [id: [type: :uuid, allow_nil?: false], name: [type: :string, allow_nil?: true]]
        ],
        transform: fn n -> %{id: n.data.id, name: nil} end
      )

      publish(:update, [:id],
        event: "item_updated",
        public?: true,
        returns: :map,
        constraints: [fields: [count: [type: :integer, allow_nil?: false]]],
        transform: fn _ -> %{count: 1} end
      )

      publish(:destroy, [:id],
        event: "item_deleted",
        public?: true,
        returns: :map,
        constraints: [fields: [id: [type: :string, allow_nil?: false]]],
        transform: fn n -> %{id: to_string(n.data.id)} end
      )
    end

    attributes do
      uuid_primary_key(:id)
    end

    actions do
      defaults([:read, :create, :update, :destroy])
    end
  end

  defmodule Review do
    @moduledoc false
    use Ash.Resource, domain: nil, notifiers: [Ash.Notifier.PubSub]

    pub_sub do
      module(AshSurface.Ported.TypedChannel.Fixtures.Endpoint)
      prefix("reviews")

      publish(:create, [:id],
        event: "review_submitted",
        public?: true,
        returns: :map,
        constraints: [fields: [rating: [type: :integer, allow_nil?: false]]],
        transform: fn _ -> %{rating: 5} end
      )

      publish(:update, [:id],
        event: "review_approved",
        public?: true,
        returns: :map,
        constraints: [fields: [approved: [type: :boolean, allow_nil?: false]]],
        transform: fn _ -> %{approved: true} end
      )
    end

    attributes do
      uuid_primary_key(:id)
    end

    actions do
      defaults([:read, :create, :update])
    end
  end

  defmodule Alert do
    @moduledoc false
    use Ash.Resource, domain: nil, notifiers: [Ash.Notifier.PubSub]

    pub_sub do
      module(AshSurface.Ported.TypedChannel.Fixtures.Endpoint)
      prefix("alerts")

      publish(:create, [:id],
        event: "alert_sent",
        public?: true,
        returns: :map,
        transform: fn _ -> %{} end
      )

      publish(:update, [:id],
        event: "alert_cleared",
        public?: true,
        returns: :map,
        constraints: [fields: [cleared_at: [type: :utc_datetime, allow_nil?: false]]],
        transform: fn _ -> %{cleared_at: DateTime.utc_now()} end
      )

      publish(:destroy, [:id], event: "alert_gone", public?: true)
    end

    attributes do
      uuid_primary_key(:id)
    end

    actions do
      defaults([:read, :create, :update, :destroy])
    end
  end

  defmodule Job do
    @moduledoc false
    use Ash.Resource, domain: nil, notifiers: [Ash.Notifier.PubSub]

    pub_sub do
      module(AshSurface.Ported.TypedChannel.Fixtures.Endpoint)
      prefix("alias_jobs")

      publish(:create, [:id],
        event: "alias_job_finished",
        public?: true,
        returns: :map,
        constraints: [
          fields: [
            elapsed: [type: :duration],
            on: [type: :date],
            outcome: [
              type: :union,
              constraints: [types: [failed_at: [type: :naive_datetime], note: [type: :string]]]
            ]
          ]
        ],
        transform: fn _ -> %{} end
      )
    end

    attributes do
      uuid_primary_key(:id)
    end

    actions do
      defaults([:create])
    end
  end

  defmodule ConflictItem do
    @moduledoc false
    use Ash.Resource, domain: nil, notifiers: [Ash.Notifier.PubSub]

    pub_sub do
      module(AshSurface.Ported.TypedChannel.Fixtures.Endpoint)
      prefix("conflict")

      publish(:create, [:id],
        event: "item_created",
        public?: true,
        returns: :map,
        constraints: [fields: [totally_different: [type: :boolean, allow_nil?: false]]],
        transform: fn _ -> %{totally_different: true} end
      )
    end

    attributes do
      uuid_primary_key(:id)
    end

    actions do
      defaults([:read, :create])
    end
  end
end
