defmodule AshSurface.Compiler.ChannelDiscoveryTest do
  use ExUnit.Case, async: true
  alias AshSurface.Compiler.{ChannelDiscovery, Section.Channel}
  alias AshSurface.Projectors.JS.ZodGuard
  alias AshSurface.ChannelFixtures.{Alert, Dup, Item, Scalar}
  alias AshSurface.ZodFixtures.Harness

  defp org(resources), do: [%{name: "Org", topic: "org:*", resources: resources}]

  test "discovers string-keyed map that Channel.build admits (ZodGuard on every string)" do
    assert {:ok, %{"channels" => [c]} = d} = ChannelDiscovery.discover(org([Item, Alert]))
    assert c["name"] == "Org" and c["topic"] == "org:*"

    assert Enum.sort(Enum.map(c["events"], & &1["event"])) ==
             ~w(alert_cleared alert_gone alert_hidden item_created item_updated)

    assert {:ok, [ch], warnings} = Channel.build_with_warnings(d)
    for ev <- ch.events, do: assert({:ok, :expression, _} = ZodGuard.admit(ev.zod))
    created = Enum.find(ch.events, &(&1.event == "item_created"))
    assert created.zod =~ "id:" and created.zod =~ "name:" and created.zod =~ "nullable"
    assert {:missing_returns, "Org", "alert_gone"} in warnings
    assert {:non_public_publication, Alert, "alert_hidden"} in d["warnings"]
  end

  test "event subset selection and event_not_found" do
    assert {:ok, %{"channels" => [%{"events" => [%{"event" => "item_updated"}]}]}} =
             ChannelDiscovery.discover(org([{Item, [:item_updated]}]))

    assert {:error, {:event_not_found, Item, "nope"}} =
             ChannelDiscovery.discover(org([{Item, ["nope"]}]))
  end

  test "duplicate event within one channel is refused; across channels is fine" do
    assert {:error, {:duplicate_event, "Org", "item_created"}} =
             ChannelDiscovery.discover(org([Item, Dup]))

    two = [%{name: "A", resources: [Item]}, %{name: "B", resources: [Dup]}]
    assert {:ok, %{"channels" => [_, _]}} = ChannelDiscovery.discover(two)
  end

  test "non-object payload refused by discovery and by Channel.build via returns_kind" do
    assert {:error, {:non_object_payload, "Org", "scalar_made", "string"}} =
             ChannelDiscovery.discover(org([Scalar]))

    d = %{
      "channels" => [
        %{
          "name" => "Org",
          "events" => [
            %{
              "event" => "e",
              "payload" => %{"type" => %{"kind" => "string"}},
              "returns_kind" => "string"
            }
          ]
        }
      ]
    }

    assert {:error, {:non_object_payload, "Org", "e", "string"}} = Channel.build(d)
    assert {:error, {:non_object_payload, "Org", "e", "string"}} = ChannelDiscovery.verify(d)
  end

  test "verify/1 is pure and reports missing_returns warnings" do
    d = %{"channels" => [%{"name" => "A", "events" => [%{"event" => "x", "payload" => nil}]}]}
    assert {:ok, [{:missing_returns, "A", "x"}]} = ChannelDiscovery.verify(d)
    assert {:error, {:invalid_discovery, :x}} = ChannelDiscovery.verify(:x)
  end

  test "Channel.build refuses duplicate events and keeps the frozen key contract" do
    d = %{"channels" => [%{"name" => "A", "events" => [%{"event" => "x"}, %{"event" => "x"}]}]}
    assert {:error, {:duplicate_event, "A", "x"}} = Channel.build(d)

    assert {:ok, [%{name: "A"}]} =
             Channel.build(%{"channels" => [%{"name" => "A", "events" => []}]})
  end

  test "generated payload schema parses real payloads under node" do
    {:ok, d} = ChannelDiscovery.discover(org([{Item, ["item_created"]}]))
    {:ok, [ch]} = Channel.build(d)
    [ev] = ch.events

    dir = Path.join(System.tmp_dir!(), "rc_chan_#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(dir)
    Harness.zod!()
    File.ln_s!(Path.join(Harness.repo_root(), "node_modules"), Path.join(dir, "node_modules"))
    uuid = "123e4567-e89b-42d3-a456-426614174000"

    cases = [
      %{id: uuid, name: "x"},
      %{id: uuid, name: nil},
      %{id: "nope", name: "x"},
      %{name: "x"}
    ]

    File.write!(Path.join(dir, "run.mjs"), """
    import { z } from "zod";
    const s = #{ev.zod};
    process.stdout.write(JSON.stringify(#{Jason.encode!(cases)}.map((c) => s.safeParse(c).success)));
    """)

    {out, 0} = Harness.run(Harness.tool!("node"), ["run.mjs"], dir)
    File.rm_rf!(dir)
    assert Jason.decode!(out) == [true, true, false, false]
  end

  test "match regex constraint is carried as source and flags" do
    defn = %Ash.Info.Manifest.Type{kind: :string, constraints: [match: ~r/^a+$/i, max_length: 5]}

    assert %{"constraints" => %{"match" => "^a+$", "match_flags" => "i", "max_length" => 5}} =
             ChannelDiscovery.definition(defn, 0)
  end

  test "type_ref at the depth cap is a typed refusal, not z.unknown" do
    ref = %Ash.Info.Manifest.Type{kind: :type_ref, module: Ash.Type.String, constraints: []}

    assert catch_throw(ChannelDiscovery.definition(ref, 8)) ==
             {:depth_exceeded, Ash.Type.String, 8}
  end
end
