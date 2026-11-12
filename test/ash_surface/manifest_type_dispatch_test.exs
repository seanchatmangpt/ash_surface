defmodule AshSurface.ManifestTypeDispatchTest.Status do
  @moduledoc false
  use Ash.Type.Enum, values: [:draft, :live]
end

defmodule AshSurface.ManifestTypeDispatchTest.Slug do
  @moduledoc false
  use Ash.Type.NewType, subtype_of: :string, constraints: [min_length: 2]
end

defmodule AshSurface.ManifestTypeDispatchTest.Unplaced do
  @moduledoc false
  use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Simple

  attributes do
    uuid_primary_key(:id)
  end

  actions do
    defaults([:read])
  end
end

defmodule AshSurface.ManifestTypeDispatchTest do
  @moduledoc """
  ash_surface counterpart of ash_typescript `manifest/codegen_type_dispatch_test`,
  `decorator_test`, `persist_resource_lookups_test`, `verify_mappable_types_test`.

  Dispatch head under test: `TypeFacts.analyze_type/1` over a resolved
  `%Ash.Info.Manifest.Type{}` must equal the raw `TypeFacts.analyze/2` path, and
  every resulting definition kind must be mappable by `ZodType`.

  Divergences (pinned): ash_typescript has `TypeMapper.map_type(%Type{}, ...)` returning
  TS strings; ash_surface emits Zod fragments via `ZodType.fragment/2`. ash_typescript
  fails a verifier on unmappable custom types; ash_surface reports them through
  `ZodType.unmappable_kinds/2` and renders `z.unknown()` (no verifier raise).
  """
  use ExUnit.Case, async: true

  alias Ash.Info.Manifest.Type
  alias AshSurface.Compiler.{TypeFacts, ZodType}
  alias AshSurface.ManifestTypeDispatchTest.{Slug, Status, Unplaced}

  defp t(kind, extra \\ []), do: struct(Type, [kind: kind, constraints: []] ++ extra)

  describe "primitive %Type{} dispatch" do
    for kind <- ~w(string integer float boolean uuid date decimal utc_datetime atom map)a do
      test "#{kind} kind yields its own kind string and a mappable definition" do
        a = TypeFacts.analyze_type(t(unquote(kind)))
        assert a.kind == Atom.to_string(unquote(kind))
        assert a.subtype_of == nil
        assert ZodType.unmappable_kinds([a.definition], overrides: %{}) == []
        refute ZodType.fragment(a.definition, overrides: %{}) == "z.unknown()"
      end
    end

    test "nil and unknown kinds dispatch to the unknown kind, which is unmappable" do
      assert TypeFacts.analyze_type(nil).kind == "unknown"
      assert TypeFacts.analyze_type(t(:unknown)).kind == "unknown"
      assert TypeFacts.analyze_type(t(nil)).kind == "unknown"

      a = TypeFacts.analyze_type(nil)
      assert ZodType.unmappable_kinds([a.definition], overrides: %{}) == ["unknown"]
      assert ZodType.fragment(a.definition, overrides: %{}) == "z.unknown()"
    end
  end

  describe "%Type{} path equals raw {type, constraints} path" do
    test "raw Ash types" do
      for {raw, cons} <- [
            {Ash.Type.String, [min_length: 1, max_length: 9]},
            {Ash.Type.Integer, [min: 0, max: 5]},
            {Ash.Type.Boolean, []},
            {Ash.Type.UUID, []},
            {Ash.Type.Date, []}
          ] do
        resolved = Ash.Info.Manifest.Generator.TypeResolver.resolve(raw, cons)
        assert TypeFacts.analyze_type(resolved) == TypeFacts.analyze(raw, cons)
      end
    end

    test "enum named type expands identically through :type_ref and raw" do
      ref = t(:type_ref, module: Status)
      a = TypeFacts.analyze_type(ref)
      assert a.kind == "enum"
      assert a.definition["type"]["values"] == ["draft", "live"]
      assert a == TypeFacts.analyze(Status, [])
      assert ZodType.fragment(a.definition, overrides: %{}) == ~s|z.enum(["draft", "live"])|
    end

    test "NewType keeps the base kind as subtype_of with merged constraints" do
      a = TypeFacts.analyze(Slug, [])
      assert a.subtype_of == "string"
      assert a.subtype_constraints == %{min_length: 2, allow_empty?: false}
      assert a == TypeFacts.analyze_type(t(:type_ref, module: Slug))
    end
  end

  describe "composite dispatch" do
    test "array carries recursive items" do
      a = TypeFacts.analyze_type(t(:array, item_type: t(:integer)))
      assert a.kind == "array"
      assert a.definition["type"]["items"]["type"]["kind"] == "integer"
      assert ZodType.unmappable_kinds([a.definition], overrides: %{}) == []
    end

    test "array of unknown item surfaces the unknown kind through the walker" do
      a = TypeFacts.analyze_type(t(:array, item_type: t(:unknown)))
      assert ZodType.unmappable_kinds([a.definition], overrides: %{}) == ["unknown"]
    end

    test "array without item_type has no items key" do
      a = TypeFacts.analyze_type(t(:array))
      refute Map.has_key?(a.definition["type"], "items")
    end

    test "union members become named member definitions" do
      union =
        t(:union,
          members: [
            %{name: :a, type: t(:string)},
            %{name: :b, type: t(:integer), tag: :kind, tag_value: :bee}
          ]
        )

      a = TypeFacts.analyze_type(union)
      assert [m1, m2] = a.definition["type"]["members"]
      assert m1["name"] == "a" and m1["type"]["type"]["kind"] == "string"
      refute Map.has_key?(m1, "tag")
      assert m2["tag"] == "kind" and m2["tag_value"] == "bee"
    end

    test "struct/map fields carry allow_nil? and omittable" do
      s =
        t(:map,
          fields: [
            %{name: :x, type: t(:string), allow_nil?: false},
            %{name: :y, type: t(:string), allow_nil?: true}
          ]
        )

      [x, y] = TypeFacts.analyze_type(s).definition["type"]["fields"]
      assert x["allow_nil?"] == false and not Map.has_key?(x, "omittable")
      assert y["allow_nil?"] == true and y["omittable"] == true
    end

    test "resource and embedded kinds are carried by name" do
      r = TypeFacts.analyze_type(t(:resource, resource_module: Unplaced))
      assert r.definition["type"]["resource?"] == true
      assert r.definition["type"]["instance_of"] == inspect(Unplaced)

      e = TypeFacts.analyze_type(t(:embedded_resource, resource_module: Unplaced))
      assert e.definition["type"]["resource"] == inspect(Unplaced)
    end
  end

  describe "mappable-type verification (verify_mappable_types)" do
    test "a custom kind is reported unmappable until an override covers it" do
      a = TypeFacts.analyze_type(t(:money))
      assert ZodType.unmappable_kinds([a.definition], overrides: %{}) == ["money"]
      assert ZodType.unmappable_kinds([a.definition], overrides: %{"money" => "z.string()"}) == []
    end

    test "unmappable kind nested in an array of struct fields is found, deduplicated and sorted" do
      deep =
        t(:array,
          item_type:
            t(:map,
              fields: [
                %{name: :a, type: t(:zeta), allow_nil?: true},
                %{name: :b, type: t(:alpha), allow_nil?: true},
                %{name: :c, type: t(:zeta), allow_nil?: true}
              ]
            )
        )

      a = TypeFacts.analyze_type(deep)
      assert ZodType.unmappable_kinds([a.definition], overrides: %{}) == ["alpha", "zeta"]
    end
  end

  describe "persisted resource lookups (persist_resource_lookups)" do
    test "a resource without the extension has no compiled state" do
      refute AshSurface.Resource.Info.compiled?(Unplaced)
      assert {:error, :not_compiled} = AshSurface.Resource.Info.compiled_result(Unplaced)
      assert_raise ArgumentError, fn -> AshSurface.Resource.Info.compiled!(Unplaced) end
    end
  end

  describe "manifest decorator (decorator_test)" do
    test "covered by test/ash_surface/from_manifest_test.exs (custom.ash_surface placement)" do
      assert File.exists?(Path.expand("from_manifest_test.exs", __DIR__))
    end
  end
end
