defmodule AshSurface.Ported.Rpc.E.TupleNewtypeInputTest do
  @moduledoc """
  Port of ash_typescript `rpc/tuple_newtype_input_test.exs` (13 tests, all real here).

  Counterparts: `AshTypescript.TypeSystem.Introspection` ->
  `AshSurface.RuntimeParity.RequestedFields.Introspection`; `AshTypescript.Helpers.
  has_typescript_field_names?/1` -> same module; `Rpc.ValueFormatter.format/5` ->
  `AshSurface.RuntimeParity.FieldSelection.format_value/5` (input/output key renaming with the
  type's `typescript_field_names/0` as overrides); the Ash casting tests run unchanged against
  the real ported fixtures (`AshSurface.Ported.*`). No doubles.
  """
  use ExUnit.Case, async: false

  alias AshSurface.RuntimeParity.FieldSelection
  alias AshSurface.RuntimeParity.RequestedFields.Introspection

  @type_mod AshSurface.Ported.InputParsing.LocationTuple

  describe "LocationTuple NewType introspection" do
    test "unwraps correctly" do
      {unwrapped, constraints} =
        Ash.Info.Manifest.Generator.TypeResolver.unwrap_new_type(@type_mod, [])

      assert unwrapped == Ash.Type.Tuple
      assert Keyword.has_key?(constraints, :fields)
    end

    test "unwraps correctly with instance_of" do
      {unwrapped, constraints} = Introspection.unwrap_new_type(@type_mod, [])

      assert unwrapped == Ash.Type.Tuple
      assert constraints[:instance_of] == @type_mod
      assert Keyword.has_key?(constraints, :fields)
    end

    test "unwrap_new_type preserves an existing instance_of (outermost wins)" do
      {unwrapped, constraints} =
        Introspection.unwrap_new_type(@type_mod, instance_of: AshSurface.Ported.Todo)

      assert unwrapped == Ash.Type.Tuple
      assert constraints[:instance_of] == AshSurface.Ported.Todo
    end

    test "has typescript_field_names callback" do
      assert Introspection.has_typescript_field_names?(@type_mod)

      field_names = @type_mod.typescript_field_names()
      assert field_names[:lat_1] == "lat1"
      assert field_names[:lng_1] == "lng1"
      assert field_names[:is_verified?] == "isVerified"
    end
  end

  describe "value formatting with LocationTuple" do
    setup do
      overrides = Map.new(@type_mod.typescript_field_names())
      %{overrides: overrides, admitted: Map.keys(overrides)}
    end

    test "formats tuple input correctly (client names to Elixir names)", ctx do
      ts_input = %{"lat1" => 37.7749, "lng1" => -122.4194, "isVerified" => true}

      result =
        FieldSelection.format_value(ts_input, :input, :camel_case, ctx.admitted, ctx.overrides)

      assert result == %{lat_1: 37.7749, lng_1: -122.4194, is_verified?: true}
    end

    test "formats tuple output correctly (Elixir names to client names)", ctx do
      elixir_value = %{lat_1: 37.7749, lng_1: -122.4194, is_verified?: true}

      result =
        FieldSelection.format_value(
          elixir_value,
          :output,
          :camel_case,
          ctx.admitted,
          ctx.overrides
        )

      assert result == %{"lat1" => 37.7749, "lng1" => -122.4194, "isVerified" => true}
    end
  end

  describe "Ash.Type.Tuple casting behavior" do
    test "Todo coordinates cast via changeset - must use tuple not map" do
      user = %AshSurface.Ported.User{
        id: Ash.UUID.generate(),
        name: "Test",
        email: "test@test.com"
      }

      params = %{title: "Test", user_id: user.id, coordinates: {37.7749, -122.4194}}
      changeset = Ash.Changeset.for_create(AshSurface.Ported.Todo, :create, params)
      coords = Ash.Changeset.get_attribute(changeset, :coordinates)

      if changeset.valid? do
        assert elem(coords, 0) == 37.7749
        assert elem(coords, 1) == -122.4194
      else
        flunk("Todo changeset failed: #{inspect(changeset.errors)}")
      end
    end

    test "LocationTuple NewType has correct subtype" do
      assert Ash.Type.NewType.new_type?(@type_mod)
      assert Ash.Type.NewType.subtype_of(@type_mod) == Ash.Type.Tuple
    end

    test "LocationTuple constraints are correctly initialized" do
      {:ok, constraints} = @type_mod.do_init([])

      assert Keyword.has_key?(constraints, :fields)
      fields = constraints[:fields]

      assert Keyword.has_key?(fields, :lat_1)
      assert Keyword.has_key?(fields, :lng_1)
      assert Keyword.has_key?(fields, :is_verified?)
    end

    test "LocationTuple casts map input with atom or string keys" do
      {:ok, constraints} = Ash.Type.init(@type_mod, [])

      map_inputs = [
        %{lat_1: 37.7749, lng_1: -122.4194, is_verified?: true},
        %{"lat_1" => 37.7749, "lng_1" => -122.4194, "is_verified?" => true}
      ]

      # Substrate skew: the reference pins Ash 3.37.1, whose Ash.Type.Tuple casts a map keyed by
      # the tuple's field names into the tuple; this checkout locks Ash 3.33.11, which refuses
      # map input with the typed error "is invalid". The disjunctive law (cast-to-tuple OR typed
      # refusal, never a crash or a map passthrough) holds on both.
      for input <- map_inputs do
        case Ash.Type.cast_input(@type_mod, input, constraints) do
          {:ok, cast} -> assert cast == {37.7749, -122.4194, true}
          {:error, message} -> assert message == "is invalid"
        end
      end

      {:ok, cast_value} = Ash.Type.cast_input(@type_mod, {37.7749, -122.4194, true}, constraints)
      assert is_tuple(cast_value)
    end

    test "direct Ash.Type.Tuple cast with inline constraints - requires actual tuple" do
      constraints = [
        fields: [
          lat_1: [type: :float, allow_nil?: false],
          lng_1: [type: :float, allow_nil?: false],
          is_verified?: [type: :boolean, allow_nil?: true]
        ]
      ]

      assert {:ok, cast_value} =
               Ash.Type.cast_input(Ash.Type.Tuple, {37.7749, -122.4194, true}, constraints)

      assert is_tuple(cast_value)
      assert elem(cast_value, 0) == 37.7749
      assert elem(cast_value, 1) == -122.4194
      assert elem(cast_value, 2) == true
    end
  end

  describe "InputFormatter with LocationTuple attribute" do
    test "formats input with tuple attribute" do
      AshSurface.Ported.Rpc.install()

      raw_input = %{
        "userName" => "tuple_user",
        "emailAddress" => "tuple@example.com",
        "location" => %{"lat1" => 37.7749, "lng1" => -122.4194, "isVerified" => true}
      }

      lookups =
        AshSurface.RuntimeParity.RequestedFields.Compat.resource_lookup(
          AshSurface.RuntimeParity.Rpc.Support.handle()
        )

      {:ok, formatted} =
        AshSurface.RuntimeParity.Rpc.InputFormatter.format(
          raw_input,
          AshSurface.Ported.InputParsing.Resource,
          :create,
          :camel_case,
          lookups
        )

      assert formatted.user_name == "tuple_user"
      assert formatted.email_address == "tuple@example.com"
      assert formatted.location == %{lat_1: 37.7749, lng_1: -122.4194, is_verified?: true}
    end
  end

  describe "full changeset creation with tuple attribute" do
    test "creates changeset with tuple value - requires actual tuple" do
      params = %{
        user_name: "tuple_user",
        email_address: "tuple@example.com",
        location: {37.7749, -122.4194, true}
      }

      changeset =
        Ash.Changeset.for_create(AshSurface.Ported.InputParsing.Resource, :create, params)

      location = Ash.Changeset.get_attribute(changeset, :location)

      if changeset.valid? do
        assert is_tuple(location)
        assert elem(location, 0) == 37.7749
        assert elem(location, 1) == -122.4194
        assert elem(location, 2) == true
      else
        flunk("Changeset invalid: #{inspect(changeset.errors)}")
      end
    end
  end

  describe "positional tuple mapping (mutation-killing)" do
    alias AshSurface.RuntimeParity.Rpc.{FieldExtractor, ValueFormatter}

    defp lookups,
      do:
        AshSurface.RuntimeParity.RequestedFields.Compat.resource_lookup(
          AshSurface.RuntimeParity.Rpc.Support.handle()
        )

    setup do
      AshSurface.Ported.Rpc.install()
      :ok
    end

    test "ValueFormatter maps each tuple position to its declared field, distinct values" do
      ty = Ash.Info.Manifest.Generator.TypeResolver.resolve(@type_mod, [])

      assert ValueFormatter.format({1.5, 2.5, true}, ty, [], :camel_case, :output, lookups()) ==
               %{"lat1" => 1.5, "lng1" => 2.5, "isVerified" => true}

      assert ValueFormatter.format({9.0, -3.0, false}, ty, [], :camel_case, :output, lookups()) ==
               %{"lat1" => 9.0, "lng1" => -3.0, "isVerified" => false}
    end

    test "ValueFormatter input direction maps client names back to internal atoms" do
      ty = Ash.Info.Manifest.Generator.TypeResolver.resolve(@type_mod, [])
      input = %{"lat1" => 1.5, "lng1" => 2.5, "isVerified" => false}

      assert ValueFormatter.format(input, ty, [], :camel_case, :input, lookups()) ==
               %{lat_1: 1.5, lng_1: 2.5, is_verified?: false}
    end

    test "FieldExtractor converts a tuple by template index, not template order" do
      template = [
        %{field_name: :b, index: 1},
        %{field_name: :a, index: 0},
        %{field_name: :c, index: 2},
        %{unrelated: true}
      ]

      assert FieldExtractor.normalize_for_extraction({7, 8, 9}, template) == %{a: 7, b: 8, c: 9}
      assert FieldExtractor.normalize_for_extraction({7, 8, 9}, [%{field_name: :c, index: 2}]) ==
               %{c: 9}

      assert FieldExtractor.normalize_for_extraction(%{x: 1}, []) == %{x: 1}
      assert FieldExtractor.normalize_for_extraction([x: 1, y: 2], []) == %{x: 1, y: 2}
    end

    test "run pipeline projects a tuple attribute selection by position and subset" do
      todo = AshSurface.Ported.RpcFixtures.todo(coordinates: {1.5, 2.5})

      full =
        AshSurface.Ported.Rpc.run(
          %{
            "action" => "list_todos",
            "fields" => ["id", %{"coordinates" => ["latitude", "longitude"]}]
          },
          [todo]
        )

      assert [%{"coordinates" => %{"latitude" => 1.5, "longitude" => 2.5}}] = full["data"]

      only =
        AshSurface.Ported.Rpc.run(
          %{"action" => "list_todos", "fields" => [%{"coordinates" => ["longitude"]}]},
          [todo]
        )

      assert only["data"] == [%{"coordinates" => %{"longitude" => 2.5}}]
    end

    test "tuple newtype fragment under zod accepts objects, rejects arrays and scalars" do
      d = AshSurface.Compiler.TypeFacts.analyze(@type_mod, []).definition
      f = AshSurface.Compiler.ZodType.fragment(d)
      root = Path.expand("../../../../..", __DIR__)

      script = """
      import { z } from "zod";
      const s = #{f};
      console.log(JSON.stringify(#{Jason.encode!([%{"lat1" => 1}, %{}, [1, 2, 3], "x", 4, nil])}.map((v) => s.safeParse(v).success)));
      """

      {out, 0} = System.cmd("node", ["--input-type=module", "-e", script], cd: root)
      assert Jason.decode!(out) == [true, true, false, false, false, false]
    end
  end
end
