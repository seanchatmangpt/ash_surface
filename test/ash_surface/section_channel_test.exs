defmodule AshSurface.Section.ChannelTest do
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.Section.Channel
  alias AshSurface.Projectors.JS.ZodGuard

  defp map_def, do: %{"type" => %{"kind" => "map"}}
  defp int_def, do: %{"type" => %{"kind" => "integer"}}

  test "builds channels with admitted Zod payloads, deterministically" do
    d = %{
      "channels" => [
        %{
          "name" => "B",
          "topic" => "b:*",
          "events" => [%{"event" => "x_y", "payload" => map_def()}]
        },
        %{
          "name" => "A",
          "topic" => "a:*",
          "events" => [%{"event" => "z", "payload" => int_def()}, %{"event" => "n"}]
        }
      ]
    }

    assert {:ok, [a, b]} = Channel.build(d, [])
    assert {:ok, [^a, ^b]} = Channel.build(d, [])
    assert [%{event: "n", zod: "z.unknown()"}, %{event: "z"}] = a.events
    assert [%{payload_name: "XYPayload"}] = b.events
    for ev <- a.events ++ b.events, do: assert(:ok = ZodGuard.expression(ev.zod))
  end

  test "refuses non-map payloads" do
    d = %{
      "channels" => [%{"name" => "A", "events" => [%{"event" => "e", "payload" => "string"}]}]
    }

    assert {:error, {:non_map_payload, "A", "e", "string"}} = Channel.build(d, [])
  end

  test "rejects same payload name with differing schemas, accepts identical" do
    ev = fn p -> %{"event" => "e", "payload" => p} end

    bad = %{
      "channels" => [
        %{"name" => "A", "events" => [ev.(map_def())]},
        %{"name" => "B", "events" => [ev.(int_def())]}
      ]
    }

    assert {:ok, [a, b]} = Channel.build(bad, [])
    assert [%{payload_name: "AEPayload"}] = a.events
    assert [%{payload_name: "BEPayload"}] = b.events

    same_scope = %{
      "channels" => [
        %{
          "name" => "A",
          "events" => [
            %{"event" => "a-b", "payload" => map_def()},
            %{"event" => "a_b", "payload" => int_def()}
          ]
        }
      ]
    }

    assert {:error, {:payload_name_conflict, "ABPayload", [_, _]}} = Channel.build(same_scope, [])

    ok = %{
      "channels" => [
        %{"name" => "A", "events" => [ev.(map_def())]},
        %{"name" => "B", "events" => [ev.(map_def())]}
      ]
    }

    assert {:ok, [_, _]} = Channel.build(ok, [])
  end

  test "duplicate event inside one channel is refused" do
    d = %{
      "channels" => [
        %{
          "name" => "A",
          "events" => [%{"event" => "e"}, %{"event" => "e", "payload" => map_def()}]
        }
      ]
    }

    assert {:error, {:duplicate_event, "A", "e"}} = Channel.build(d, [])
  end

  test "returns_kind: non-object refused, object and unknown kinds admitted" do
    ev = fn k -> %{"event" => "e", "payload" => int_def(), "returns_kind" => k} end
    mk = fn k -> %{"channels" => [%{"name" => "A", "events" => [ev.(k)]}]} end

    assert {:error, {:non_object_payload, "A", "e", "integer"}} =
             Channel.build(mk.("integer"), [])

    assert {:ok, [_]} = Channel.build(mk.("map"), [])
    assert {:ok, [_]} = Channel.build(mk.("term"), [])
  end

  test "build_with_warnings carries missing_returns and discovery warnings" do
    d = %{
      "warnings" => [{:custom, 1}],
      "channels" => [%{"name" => "A", "events" => [%{"event" => "n"}]}]
    }

    assert {:ok, [_], [{:custom, 1}, {:missing_returns, "A", "n"}]} =
             Channel.build_with_warnings(d)
  end

  test "typed-map payload with fields renders an object schema" do
    p = %{
      "type" => %{
        "kind" => "map",
        "fields" => [
          %{"name" => "id", "type" => %{"kind" => "uuid"}, "allow_nil?" => false}
        ]
      }
    }

    d = %{"channels" => [%{"name" => "A", "events" => [%{"event" => "e", "payload" => p}]}]}
    assert {:ok, [%{events: [%{zod: zod}]}]} = Channel.build(d, [])
    assert zod =~ "z.object"
    assert :ok = ZodGuard.expression(zod)
  end

  test "payload names are valid JS identifiers" do
    d = %{
      "channels" => [
        %{
          "name" => "A",
          "events" => [
            %{"event" => "user-created", "payload" => map_def()},
            %{"event" => "9.x:y", "payload" => map_def()}
          ]
        }
      ]
    }

    assert {:ok, [c]} = Channel.build(d)
    assert ["_9XYPayload", "UserCreatedPayload"] = Enum.map(c.events, & &1.payload_name)
    assert Enum.all?(c.events, &Regex.match?(~r/^[A-Za-z_][A-Za-z0-9_]*$/, &1.payload_name))
  end

  test "EmbeddedSchema render error is returned, not swallowed" do
    bad = %{"type" => %{"kind" => "union", "members" => [%{"bogus" => 1}]}}
    d = %{"channels" => [%{"name" => "A", "events" => [%{"event" => "e", "payload" => bad}]}]}
    assert {:error, {:invalid_union_member, %{"bogus" => 1}, 0}} = Channel.build(d)
  end
end
