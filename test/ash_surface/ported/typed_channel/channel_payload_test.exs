defmodule AshSurface.Ported.TypedChannel.KindFixtures do
  @moduledoc false
  alias AshSurface.Ported.TypedChannel.Fixtures.Endpoint

  defmodule Summary do
    @moduledoc false
    use Ash.Type.NewType,
      subtype_of: :map,
      constraints: [fields: [total: [type: :integer, allow_nil?: false]]]
  end

  defmodule Report do
    @moduledoc false
    use Ash.Resource, domain: nil, notifiers: [Ash.Notifier.PubSub]

    pub_sub do
      module(Endpoint)
      prefix("kind_reports")

      publish(:create, [:id],
        event: "summary_ready",
        public?: true,
        returns: AshSurface.Ported.TypedChannel.KindFixtures.Summary,
        transform: fn _ -> %{total: 1} end
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

defmodule AshSurface.Ported.TypedChannel.ChannelPayloadTest do
  @moduledoc """
  Port of ash_typescript typed_channel/{codegen,multi_resource_codegen,payload_type_aliases}.
  ash_surface generates no .ts: TS-text assertions become assertions on the discovery map,
  the built `Channel` structs (Zod payload strings) and real Zod parsing under node.
  Per-test notes for reference tests with no counterpart are in the parity ledger `changes`.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.{ChannelDiscovery, Section.Channel}
  alias AshSurface.Ported.TypedChannel.Fixtures.{Alert, ConflictItem, Item, Job, Review}
  alias AshSurface.Projectors.JS.ZodGuard
  alias AshSurface.ZodFixtures.Harness

  defp spec(name, topic, resources), do: %{name: name, topic: topic, resources: resources}

  defp build!(specs) do
    {:ok, d} = ChannelDiscovery.discover(specs)
    {:ok, chans, warns} = Channel.build_with_warnings(d)
    {chans, warns}
  end

  defp events(ch), do: Enum.map(ch.events, & &1.event)
  defp ev(ch, name), do: Enum.find(ch.events, &(&1.event == name))

  defp node_parse(zod, cases) do
    dir = Path.join(System.tmp_dir!(), "t13_chan_#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(dir)
    Harness.zod!()
    File.ln_s!(Path.join(Harness.repo_root(), "node_modules"), Path.join(dir, "node_modules"))

    File.write!(Path.join(dir, "run.mjs"), """
    import { z } from "zod";
    const s = #{zod};
    process.stdout.write(JSON.stringify(#{Jason.encode!(cases)}.map((c) => s.safeParse(c).success)));
    """)

    {out, 0} = Harness.run(Harness.tool!("node"), ["run.mjs"], dir)
    File.rm_rf!(dir)
    Jason.decode!(out)
  end

  @uuid "123e4567-e89b-42d3-a456-426614174000"

  describe "single channel with topic (codegen_test: generate_channel_types with topic)" do
    setup do
      {[ch], _} = build!([spec("Org", "org:*", [Item])])
      %{ch: ch}
    end

    test "channel name and topic are carried", %{ch: ch} do
      assert ch.name == "Org" and ch.topic == "org:*"
    end

    test "events map includes all declared events with identifier payload names", %{ch: ch} do
      assert events(ch) == ~w(item_created item_deleted item_updated)

      assert Enum.map(ch.events, & &1.payload_name) ==
               ~w(ItemCreatedPayload ItemDeletedPayload ItemUpdatedPayload)
    end

    test "item_created payload: uuid + nullable string (map payload)", %{ch: ch} do
      assert [true, true, false, false, false] ==
               node_parse(ev(ch, "item_created").zod, [
                 %{id: @uuid, name: "x"},
                 %{id: @uuid, name: nil},
                 %{id: "nope", name: "x"},
                 %{name: "x"},
                 %{id: @uuid}
               ])
    end

    test "item_updated payload: integer count field", %{ch: ch} do
      assert [true, false, false] ==
               node_parse(ev(ch, "item_updated").zod, [%{count: 3}, %{count: "3"}, %{}])
    end

    test "item_deleted payload: string id field", %{ch: ch} do
      assert [true, false] ==
               node_parse(ev(ch, "item_deleted").zod, [%{id: "a"}, %{id: 1}])
    end

    test "every payload schema is admitted by ZodGuard", %{ch: ch} do
      for e <- ch.events, do: assert({:ok, :expression, _} = ZodGuard.admit(e.zod))
    end
  end

  describe "unknown payload (codegen_test: unknown payload type)" do
    test "publication without returns yields z.unknown() and a missing_returns warning" do
      {[ch], warns} = build!([spec("Things", "things:*", [{Alert, ["alert_gone"]}])])
      assert [%{event: "alert_gone", zod: "z.unknown()"}] = ch.events
      assert {:missing_returns, "Things", "alert_gone"} in warns
      assert [true, true] == node_parse("z.unknown()", [%{a: 1}, "anything"])
    end
  end

  describe "channel without topic / static topic" do
    test "topic is nil when not declared; events still built" do
      {[ch], _} = build!([%{name: "NoTopic", resources: [Item]}])
      assert ch.topic == nil
      assert length(ch.events) == 3
    end

    test "static topic without wildcard is carried verbatim" do
      {[ch], _} = build!([spec("Static", "notifications", [{Item, ["item_created"]}])])
      assert ch.topic == "notifications"
      assert events(ch) == ["item_created"]
    end
  end

  describe "multi-resource channels (multi_resource_codegen_test)" do
    setup do
      {chans, warns} =
        build!([
          spec("ContentFeed", "content_feed:*", [
            {Item, ["item_created", "item_updated"]},
            {Review, ["review_submitted"]}
          ]),
          spec("Moderation", "moderation:*", [
            {Item, ["item_deleted"]},
            {Review, ["review_approved"]},
            {Alert, ["alert_sent"]}
          ]),
          spec("FullActivity", "activity:*", [Item, Review, Alert])
        ])

      %{by: Map.new(chans, &{&1.name, &1}), warns: warns}
    end

    test "each channel contains exactly its declared events (isolation)", %{by: by} do
      assert events(by["ContentFeed"]) == ~w(item_created item_updated review_submitted)
      assert events(by["Moderation"]) == ~w(alert_sent item_deleted review_approved)

      assert events(by["FullActivity"]) ==
               ~w(alert_cleared alert_gone alert_sent item_created item_deleted item_updated
                  review_approved review_submitted)
    end

    test "events from undeclared resources are absent", %{by: by} do
      refute "review_approved" in events(by["ContentFeed"])
      refute "item_created" in events(by["Moderation"])
    end

    test "per-type payload mapping: boolean, integer, utc_datetime, map", %{by: by} do
      full = by["FullActivity"]

      assert [true, false] ==
               node_parse(ev(full, "review_approved").zod, [%{approved: true}, %{approved: 1}])

      assert [true, false] ==
               node_parse(ev(full, "review_submitted").zod, [%{rating: 5}, %{rating: "5"}])

      assert [true, false] ==
               node_parse(ev(full, "alert_cleared").zod, [
                 %{clearedAt: "2026-01-01T00:00:00Z"},
                 %{clearedAt: "not a date"}
               ])

      assert [true] == node_parse(ev(full, "alert_sent").zod, [%{}])
    end

    test "channels sharing an event over identical schemas keep the same payload name", %{by: by} do
      a = ev(by["ContentFeed"], "item_created")
      b = ev(by["FullActivity"], "item_created")
      assert a.payload_name == b.payload_name and a.zod == b.zod
    end

    test "all schemas admitted; only the missing-returns event warns", %{by: by, warns: warns} do
      for c <- Map.values(by),
          e <- c.events,
          do: assert({:ok, :expression, _} = ZodGuard.admit(e.zod))

      assert {:missing_returns, "FullActivity", "alert_gone"} in warns
      assert warns |> Enum.count(&match?({:missing_returns, _, _}, &1)) == 1
    end
  end

  describe "payload name conflicts (generate_all_channel_types conflict tests)" do
    test "same event name with different schemas across channels is namespaced, not merged" do
      {chans, _} =
        build!([
          spec("A", "a:*", [{Item, ["item_created"]}]),
          spec("B", "b:*", [{ConflictItem, ["item_created"]}])
        ])

      [a, b] = chans
      [ea] = a.events
      [eb] = b.events
      assert ea.payload_name == "AItemCreatedPayload"
      assert eb.payload_name == "BItemCreatedPayload"
      assert ea.zod != eb.zod
    end

    test "same event name over an identical schema across channels does not conflict" do
      {[a, b], _} =
        build!([
          spec("A", "a:*", [{Item, ["item_created"]}]),
          spec("B", "b:*", [{Item, ["item_created"]}])
        ])

      assert [%{payload_name: "ItemCreatedPayload"}] = a.events
      assert [%{payload_name: "ItemCreatedPayload"}] = b.events
    end

    test "same event name with different schemas inside one channel is refused" do
      assert {:error, {:duplicate_event, "X", "item_created"}} =
               ChannelDiscovery.discover([spec("X", "x:*", [Item, ConflictItem])])
    end
  end

  describe "payload type aliases (payload_type_aliases_test)" do
    setup do
      {[ch], _} = build!([spec("Jobs", "alias_jobs:*", [Job])])
      %{zod: ev(ch, "alias_job_finished").zod}
    end

    test "duration, date and union(naive_datetime|string) fields render and parse under node",
         %{zod: zod} do
      assert {:ok, :expression, _} = ZodGuard.admit(zod)

      ok = %{elapsed: "PT1S", on: "2026-01-01", outcome: %{note: "n"}}

      assert [true, false, false] == node_parse(zod, [ok, %{ok | on: 5}, %{ok | elapsed: 5}])
    end

    test "payload references no TS alias identifiers (no ts alias layer in Zod)", %{zod: zod} do
      refute zod =~ ~r/\b(AshDate|NaiveDateTime|Duration)\b/
    end
  end

  describe "returns_kind resolution (channel_discovery resolved_kind)" do
    test "inline map payloads report their resolved kind, never unknown" do
      {:ok, %{"channels" => [%{"events" => evs}]}} =
        ChannelDiscovery.discover([spec("K", "k:*", [Item])])

      assert Enum.map(evs, & &1["returns_kind"]) == ["map", "map", "map"]
    end

    test "a named type reference resolves through its definition to the underlying kind" do
      alias AshSurface.Ported.TypedChannel.KindFixtures.Report

      {:ok, %{"channels" => [%{"events" => [e]}]}} =
        ChannelDiscovery.discover([spec("R", "r:*", [Report])])

      assert e["event"] == "summary_ready"
      assert e["returns_kind"] == "map"
      assert e["payload"]["type"]["kind"] == "map"
    end

    test "publication without returns has a nil returns_kind" do
      {:ok, %{"channels" => [%{"events" => [e]}]}} =
        ChannelDiscovery.discover([spec("G", "g:*", [{Alert, ["alert_gone"]}])])

      assert e["returns_kind"] == nil
    end
  end
end
