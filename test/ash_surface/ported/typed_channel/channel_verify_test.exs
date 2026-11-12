defmodule AshSurface.Ported.TypedChannel.VerifyFixtures do
  @moduledoc false
  alias AshSurface.Ported.TypedChannel.Fixtures.Endpoint

  defmodule Level do
    @moduledoc false
    use Ash.Type.Enum, values: [:low, :high]
  end

  defmodule NonMap do
    @moduledoc false
    use Ash.Resource, domain: nil, notifiers: [Ash.Notifier.PubSub]

    pub_sub do
      module(Endpoint)
      prefix("non_map_payload")

      publish(:create, [:id],
        event: "tags_changed",
        public?: true,
        returns: {:array, :string},
        transform: fn _ -> [] end
      )

      publish(:destroy, [:id],
        event: "status_changed",
        public?: true,
        returns: AshSurface.Ported.TypedChannel.VerifyFixtures.Level,
        transform: fn _ -> :low end
      )

      publish(:update, [:id],
        event: "title_changed",
        public?: true,
        returns: :string,
        transform: fn _ -> "t" end
      )
    end

    attributes do
      uuid_primary_key(:id)
    end

    actions do
      defaults([:read, :create, :update, :destroy])
    end
  end

  defmodule Obj do
    @moduledoc false
    use Ash.Resource, domain: nil, notifiers: [Ash.Notifier.PubSub]

    pub_sub do
      module(Endpoint)
      prefix("object_payload")

      publish(:create, [:id],
        event: "as_map",
        public?: true,
        returns: :map,
        constraints: [fields: [id: [type: :uuid]]],
        transform: fn n -> %{id: n.data.id} end
      )

      publish(:create, [:id],
        event: "as_typed_struct",
        public?: true,
        returns: :struct,
        constraints: [fields: [id: [type: :uuid]]],
        transform: fn _ -> nil end
      )

      publish(:create, [:id],
        event: "as_union",
        public?: true,
        returns: :union,
        constraints: [types: [note: [type: :string], count: [type: :integer]]],
        transform: fn _ -> nil end
      )

      publish(:create, [:id],
        event: "as_keyword",
        public?: true,
        returns: :keyword,
        constraints: [fields: [id: [type: :uuid]]],
        transform: fn _ -> nil end
      )

      publish(:create, [:id],
        event: "as_tuple",
        public?: true,
        returns: :tuple,
        constraints: [fields: [id: [type: :uuid]]],
        transform: fn _ -> nil end
      )

      publish(:create, [:id],
        event: "as_term",
        public?: true,
        returns: :term,
        transform: fn _ -> nil end
      )
    end

    attributes do
      uuid_primary_key(:id)
    end

    actions do
      defaults([:read, :create])
    end
  end

  defmodule Quiet do
    @moduledoc false
    use Ash.Resource, domain: nil, notifiers: [Ash.Notifier.PubSub]

    pub_sub do
      module(Endpoint)
      prefix("quiet")

      publish(:destroy, [:id], event: "thing_gone", public?: true)

      publish(:create, [:id],
        event: "hidden_thing",
        returns: :map,
        constraints: [fields: [x: [type: :integer]]],
        transform: fn _ -> %{x: 1} end
      )
    end

    attributes do
      uuid_primary_key(:id)
    end

    actions do
      defaults([:read, :create, :destroy])
    end
  end
end

defmodule AshSurface.Ported.TypedChannel.ChannelVerifyTest do
  @moduledoc """
  Port of ash_typescript typed_channel/verify_typed_channel_test.exs onto
  `ChannelDiscovery.discover/1` + `verify/1` (typed refusals, not Spark DslErrors; there is no
  `typed_channel` Spark DSL in ash_surface, so the message-text assertions become tuple matches).
  """
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.ChannelDiscovery
  alias AshSurface.Ported.TypedChannel.Fixtures.{Alert, Item, Review}
  alias AshSurface.Ported.TypedChannel.VerifyFixtures.{NonMap, Obj, Quiet}

  defp ch(name, resources), do: [%{name: name, topic: name <> ":*", resources: resources}]

  describe "valid typed channel" do
    test "single-resource channel passes verification" do
      assert {:ok, %{"warnings" => []} = d} = ChannelDiscovery.discover(ch("Org", [Item]))
      assert {:ok, []} = ChannelDiscovery.verify(d)
    end

    test "multi-resource channel passes verification" do
      assert {:ok, d} =
               ChannelDiscovery.discover(
                 ch("ContentFeed", [{Item, ["item_created"]}, {Review, ["review_submitted"]}])
               )

      assert {:ok, _} = ChannelDiscovery.verify(d)
    end
  end

  describe "verify_events_exist" do
    test "rejects event that does not match any publication" do
      assert {:error, {:event_not_found, Item, "nonexistent_event"}} =
               ChannelDiscovery.discover(
                 ch("Missing", [{Item, ["item_created", "nonexistent_event"]}])
               )
    end
  end

  describe "verify_unique_event_names" do
    test "rejects duplicate event names across resources in the same channel" do
      assert {:error, {:duplicate_event, "Dup", "item_created"}} =
               ChannelDiscovery.discover(
                 ch("Dup", [
                   {Item, ["item_created"]},
                   {AshSurface.ChannelFixtures.Dup, ["item_created"]}
                 ])
               )
    end
  end

  describe "verify_object_payloads" do
    test "rejects a publication whose returns type is a string" do
      assert {:error, {:non_object_payload, "S", "title_changed", "string"}} =
               ChannelDiscovery.discover(ch("S", [{NonMap, ["title_changed"]}]))
    end

    test "rejects a publication whose returns type is an array" do
      assert {:error, {:non_object_payload, "A", "tags_changed", "array"}} =
               ChannelDiscovery.discover(ch("A", [{NonMap, ["tags_changed"]}]))
    end

    test "rejects a publication whose returns type is an enum" do
      assert {:error, {:non_object_payload, "E", "status_changed", kind}} =
               ChannelDiscovery.discover(ch("E", [{NonMap, ["status_changed"]}]))

      assert kind in ["enum", "atom"]
    end

    test "accepts map, struct, union, keyword, tuple and unknown-shape payloads" do
      assert {:ok, %{"channels" => [%{"events" => evs}]}} =
               ChannelDiscovery.discover(ch("Objects", [Obj]))

      assert Enum.sort(Enum.map(evs, & &1["event"])) ==
               ~w(as_keyword as_map as_term as_tuple as_typed_struct as_union)
    end
  end

  describe "warn_missing_returns" do
    test "warns when publication has no returns type" do
      assert {:ok, %{"warnings" => warns}} =
               ChannelDiscovery.discover(ch("Things", [{Quiet, ["thing_gone"]}]))

      assert {:missing_returns, "Things", "thing_gone"} in warns
    end

    test "warns when publication is not marked public?" do
      assert {:ok, %{"warnings" => warns}} =
               ChannelDiscovery.discover(ch("Hidden", [{Quiet, ["hidden_thing"]}]))

      assert {:non_public_publication, Quiet, "hidden_thing"} in warns
    end

    test "public publication with returns produces no warnings" do
      assert {:ok, %{"warnings" => []}} =
               ChannelDiscovery.discover(ch("Clean", [{Alert, ["alert_cleared"]}]))
    end
  end
end
