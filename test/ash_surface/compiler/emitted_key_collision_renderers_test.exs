defmodule AshSurface.Compiler.EmittedKeyCollisionRenderersTest do
  @moduledoc """
  Wave-3 CZ: per-renderer collision courts for the renderers CX did not wire. Real resources
  and real renderer calls, no doubles. Where upstream already refuses, that refusal is
  asserted and cited.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.{
    CalculationSchema,
    RecordSchema,
    RelationshipSchema,
    RouteSchema,
    QuerySchema
  }

  alias AshSurface.Compiler.Section.Channel

  defmodule Colliding do
    use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Simple

    attributes do
      uuid_primary_key(:id)
      attribute(:foo_bar, :string, public?: true)
      attribute(:fooBar, :string, public?: true)
    end

    actions do
      defaults([:read])
      create(:make, accept: [:foo_bar, :fooBar])
    end
  end

  defmodule Clean do
    use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Simple

    attributes do
      uuid_primary_key(:id)
      attribute(:foo_bar, :string, public?: true)
      attribute(:baz, :string, public?: true)
    end

    actions do
      defaults([:read])
    end
  end

  @s %{"kind" => "string"}

  describe "record_schema (wired in this lane)" do
    test "foo_bar and fooBar attributes -> typed refusal, no duplicate-key object" do
      assert {:error, {:emitted_key_collision, {:record, Colliding}, "fooBar", names}} =
               RecordSchema.render(Colliding)

      assert names == ["fooBar", "foo_bar"]
    end

    test "non-colliding resource still renders its camelized keys" do
      assert {:ok, %{expression: expr}} = RecordSchema.render(Clean)
      assert expr =~ "fooBar:"
      assert expr =~ "baz:"
    end
  end

  describe "upstream already refuses (KD-09 field_name_collision)" do
    test "action inverse tables refuse the same pair with the typed collision" do
      assert {:error, {:field_name_collision, Colliding, "fooBar", [:fooBar, :foo_bar]}} =
               AshSurface.FieldName.action_inverse(Colliding, :make, [:foo_bar, :fooBar])
    end
  end

  describe "renderers fed wire names verbatim: distinct names stay distinct keys" do
    test "calculation names and argument names" do
      assert {:ok, zod} =
               CalculationSchema.render_calculation_schema([
                 %{
                   name: "fooBar",
                   arguments: [%{name: "aB", kind: "string"}, %{name: "a_b", kind: "string"}]
                 },
                 %{name: "foo_bar", arguments: []}
               ])

      for key <- ~w("fooBar" "foo_bar" "aB" "a_b"), do: assert(zod =~ key)
    end

    test "calculation: identical (already-emitted) names are refused by the renderer" do
      assert {:error, {:calc_name_duplicate, _}} =
               CalculationSchema.render_calculation_schema([
                 %{name: "fooBar", arguments: []},
                 %{name: "fooBar", arguments: []}
               ])

      assert {:error, {:arg_name_duplicate, "c", _}} =
               CalculationSchema.render_calculation_schema([
                 %{name: "c", arguments: [%{name: "aB", kind: "string"}, %{name: "aB", kind: "string"}]}
               ])
    end

    test "relationship load object: distinct kept, duplicates refused" do
      rel = fn n ->
        %{"name" => n, "cardinality" => "one", "primitive_fields" => ["id"]}
      end

      assert {:ok, zod} = RelationshipSchema.render_load_object([rel.("fooBar"), rel.("foo_bar")])
      assert zod =~ ~s("fooBar") and zod =~ ~s("foo_bar")

      assert {:error, {:duplicate_relationship, "fooBar"}} =
               RelationshipSchema.render_load_object([rel.("fooBar"), rel.("fooBar")])
    end

    test "route arguments: distinct kept, duplicates refused" do
      route = fn args ->
        RouteSchema.build([
          %{"name" => "r", "path" => "/a", "method" => "get", "arguments" => args}
        ])
      end

      arg = fn n -> %{"name" => n, "type" => @s} end

      # route arg keys are formatted once (wave3-rz): fooBar/foo_bar collide under :camel_case
      assert {:error, {:emitted_key_collision, {:route, "r"}, "fooBar", ["fooBar", "foo_bar"]}} =
               route.([arg.("fooBar"), arg.("foo_bar")])

      assert {:ok, [%{"query" => q}]} = route.([arg.("fooBar"), arg.("baz_qux")])
      assert q =~ "fooBar:" and q =~ "bazQux:"

      assert {:error, {:duplicate_argument, "r", "fooBar"}} =
               route.([arg.("fooBar"), arg.("fooBar")])
    end

    test "sort schema lists both distinct names" do
      assert {:ok, zod} = QuerySchema.render_sort_schema(["fooBar", "foo_bar"])
      assert zod =~ "fooBar|foo_bar"
    end
  end

  describe "channel" do
    test "colliding payload object fields refuse via the embedded renderer (CX wiring)" do
      payload = %{
        "type" => %{
          "kind" => "map",
          "fields" => [%{"name" => "foo_bar", "type" => @s}, %{"name" => "fooBar", "type" => @s}]
        }
      }

      discovery = %{
        "channels" => [
          %{"name" => "c", "events" => [%{"event" => "e", "payload" => payload}]}
        ]
      }

      assert {:error, {:emitted_key_collision, {:container, _}, "fooBar", _}} =
               Channel.build(discovery)
    end

    test "events whose names map to one payload identifier with different shapes are refused" do
      ev = fn name, kind ->
        %{"event" => name, "payload" => %{"type" => %{"kind" => kind}}}
      end

      discovery = %{
        "channels" => [%{"name" => "c", "events" => [ev.("foo_bar", "string"), ev.("fooBar", "integer")]}]
      }

      assert {:error, {:payload_name_conflict, "FooBarPayload", _}} = Channel.build(discovery)
    end
  end
end
