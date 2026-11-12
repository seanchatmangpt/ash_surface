defmodule AshSurface.Ported.Manifest.CodegenTypeDispatchSurfaceTest.CalcResource do
  @moduledoc false
  use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Simple

  attributes do
    uuid_primary_key(:id)
    attribute(:title, :string, public?: true)
  end

  calculations do
    calculate(:simple_calc, :string, expr("x"), public?: true)

    calculate :complex_calc, :string, expr(^arg(:arg1)) do
      public?(true)
      argument(:arg1, :string, allow_nil?: false)
    end
  end

  actions do
    defaults([:read])
  end
end

defmodule AshSurface.Ported.Manifest.CodegenTypeDispatchSurfaceTest do
  @moduledoc """
  ash_surface counterpart of ash_typescript `manifest/codegen_type_dispatch_test`
  (real `Ash.Info.Manifest.Type` structs through the real compiler).

  Changes (per describe):

    * `TypeMapper.map_type/3` TS strings -> `ZodType.fragment/2` Zod fragments (Zod has one
      schema for input and output, so the `:input`/`:output` direction cases collapse to a
      single resource-by-name definition assertion).
    * `TypeMapper.is_primitive_union_member?/1` and `ResourceSchemas.classify_*` -> the facts
      that drive ash_surface routing: `TypeFacts.analyze_type/1` definitions and
      `EmbeddedSchema.container?/1`. `map` without fields is a container kind in ash_surface
      but carries no `fields` table and renders the record fragment (the TS "primitive").
    * `classify_field/1` of a `%Manifest.Field{}` calculation -> `ResourceFacts` calculation
      facts (arguments list) over a real resource.
  """
  use ExUnit.Case, async: true

  alias Ash.Info.Manifest.Type
  alias AshSurface.Compiler.{EmbeddedSchema, ResourceFacts, TypeFacts, ZodType}
  alias AshSurface.Ported.Manifest.CodegenTypeDispatchSurfaceTest.CalcResource

  @meta AshSurface.Ported.TodoMetadata

  defp ty(kind, extra \\ []), do: struct(Type, [kind: kind, constraints: []] ++ extra)
  defp frag(type), do: ZodType.fragment(TypeFacts.analyze_type(type).definition, overrides: %{})
  defp defn(type), do: TypeFacts.analyze_type(type).definition

  defp embedded,
    do: ty(:embedded_resource, module: @meta, resource_module: @meta, name: "TodoMetadata")

  describe "map_type with %Type{} - primitives" do
    for {kind, mod, expected} <- [
          {:string, Ash.Type.String, "z.string()"},
          {:integer, Ash.Type.Integer, "z.number().int()"},
          {:float, Ash.Type.Float, "z.number()"},
          {:decimal, Ash.Type.Decimal, "z.string()"},
          {:boolean, Ash.Type.Boolean, "z.boolean()"},
          {:uuid, Ash.Type.UUID, "z.guid()"},
          {:uuid, Ash.Type.UUIDv7, "z.guid()"},
          {:date, Ash.Type.Date, "z.iso.date()"},
          {:utc_datetime, Ash.Type.UtcDatetime, "z.iso.datetime()"},
          {:utc_datetime_usec, Ash.Type.UtcDatetimeUsec, "z.iso.datetime()"},
          {:duration, Ash.Type.Duration, "z.iso.duration()"},
          {:binary, Ash.Type.Binary, "z.string()"},
          {:term, Ash.Type.Term, "z.any()"}
        ] do
      test "#{kind} kind (#{inspect(mod)}) maps to #{expected}" do
        assert frag(ty(unquote(kind), module: unquote(mod))) == unquote(expected)
      end
    end
  end

  describe "map_type with %Type{} - NewType primitives (kind fallback)" do
    test "string kind with unknown module falls back to the kind fragment" do
      assert frag(ty(:string, name: "MyString", module: MyApp.Types.CustomString)) == "z.string()"
    end

    test "integer kind with unknown module falls back to the kind fragment" do
      assert frag(ty(:integer, name: "MyInt", module: MyApp.Types.CustomInt)) ==
               "z.number().int()"
    end

    test "uuid kind with unknown module falls back to the uuid fragment" do
      assert frag(ty(:uuid, name: "MyUUID", module: MyApp.Types.CustomUUID)) == "z.guid()"
    end
  end

  describe "map_type with %Type{} - complex types" do
    test "array kind wraps inner type" do
      assert frag(ty(:array, item_type: ty(:string))) == "z.array(z.string())"
    end

    test "array of numbers" do
      assert frag(ty(:array, item_type: ty(:integer))) == "z.array(z.number().int())"
    end

    test "enum kind with values (sorted, like the reference)" do
      assert frag(ty(:enum, values: [:active, :inactive, :archived])) ==
               ~s|z.enum(["active", "archived", "inactive"])|
    end

    test "enum kind without values returns string" do
      assert frag(ty(:enum, values: [])) == "z.string()"
    end

    test "embedded_resource kind is carried by resource name and routed to the container renderer" do
      d = defn(embedded())
      assert d["type"]["resource"] == inspect(@meta)
      assert EmbeddedSchema.container?(d)
    end

    test "embedded_resource kind has one schema for the input direction too" do
      # ash_typescript emits distinct ResourceSchema / InputSchema aliases; Zod validates
      # both directions with the same container, so the same definition serves :input.
      assert {:ok, program} = EmbeddedSchema.render(defn(embedded()))
      assert is_binary(program)
      assert program =~ "z."
    end
  end

  describe "map_type with %Type{} matches existing behavior" do
    test "string type matches both paths" do
      resolved = Ash.Info.Manifest.Generator.TypeResolver.resolve(Ash.Type.String, [])
      assert TypeFacts.analyze_type(resolved) == TypeFacts.analyze(Ash.Type.String, [])
    end

    test "UUID type matches both paths" do
      resolved = Ash.Info.Manifest.Generator.TypeResolver.resolve(Ash.Type.UUID, [])
      assert TypeFacts.analyze_type(resolved) == TypeFacts.analyze(Ash.Type.UUID, [])
    end

    test "array of strings matches both paths" do
      resolved = Ash.Info.Manifest.Generator.TypeResolver.resolve({:array, Ash.Type.String}, [])
      assert TypeFacts.analyze_type(resolved) == TypeFacts.analyze({:array, Ash.Type.String}, [])
    end

    test "embedded resource matches both paths" do
      resolved = Ash.Info.Manifest.Generator.TypeResolver.resolve(@meta, [])
      assert TypeFacts.analyze_type(resolved) == TypeFacts.analyze(@meta, [])
    end
  end

  describe "primitive union member (is_primitive_union_member?)" do
    test "string is primitive" do
      refute EmbeddedSchema.container?(defn(ty(:string)))
    end

    test "integer is primitive" do
      refute EmbeddedSchema.container?(defn(ty(:integer)))
    end

    test "embedded_resource is not primitive" do
      assert EmbeddedSchema.container?(defn(embedded()))
    end

    test "resource is not primitive" do
      assert EmbeddedSchema.container?(
               defn(ty(:resource, resource_module: AshSurface.Ported.Todo))
             )
    end

    test "union is not primitive" do
      d = defn(ty(:union, members: []))
      assert EmbeddedSchema.container?(d)
      assert d["type"]["kind"] == "union"
    end

    test "struct with instance_of is not primitive" do
      d = defn(ty(:struct, instance_of: SomeModule))
      assert EmbeddedSchema.container?(d)
      assert d["type"]["instance_of"] == "SomeModule"
    end

    test "map without fields is primitive (no field table, record fragment)" do
      d = defn(ty(:map))
      refute Map.has_key?(d["type"], "fields")
      assert frag(ty(:map)) == "z.record(z.string(), z.unknown())"
    end

    test "map with fields is not primitive (carries a field table)" do
      type = ty(:map, fields: [%{name: :name, type: ty(:string), allow_nil?: true}])
      assert [%{"name" => "name"}] = defn(type)["type"]["fields"]
    end
  end

  describe "classify_by_type with %Type{}" do
    test "string type is primitive" do
      refute EmbeddedSchema.container?(defn(ty(:string)))
    end

    test "integer type is primitive" do
      refute EmbeddedSchema.container?(defn(ty(:integer)))
    end

    test "embedded_resource type is embedded" do
      assert defn(embedded())["type"]["kind"] == "embedded_resource"
      assert EmbeddedSchema.container?(defn(embedded()))
    end

    test "resource type is embedded" do
      d =
        defn(
          ty(:resource, resource_module: AshSurface.Ported.Todo, module: AshSurface.Ported.Todo)
        )

      assert d["type"]["kind"] == "resource"
      assert EmbeddedSchema.container?(d)
    end

    test "union type is union" do
      assert defn(ty(:union, members: []))["type"]["kind"] == "union"
    end

    test "map with fields is typed_map (field table from constraints)" do
      type = ty(:map, constraints: [fields: [name: [type: :string]]])
      raw = TypeFacts.analyze(Ash.Type.Map, fields: [name: [type: :string]])
      assert [%{"name" => "name"}] = raw.definition["type"]["fields"]
      assert EmbeddedSchema.container?(raw.definition)
      assert TypeFacts.analyze_type(type).kind == "map"
    end

    test "map without fields is primitive" do
      refute Map.has_key?(defn(ty(:map))["type"], "fields")
    end

    test "array of strings is primitive" do
      refute EmbeddedSchema.container?(defn(ty(:array, item_type: ty(:string))))
    end

    test "array of embedded resources is embedded" do
      d = defn(ty(:array, item_type: embedded()))
      assert EmbeddedSchema.container?(d)
      assert d["type"]["items"]["type"]["kind"] == "embedded_resource"
    end

    test "array of unions is union" do
      d = defn(ty(:array, item_type: ty(:union, members: [])))
      assert EmbeddedSchema.container?(d)
      assert d["type"]["items"]["type"]["kind"] == "union"
    end
  end

  describe "classify_field with real resource fields" do
    defp calc(name) do
      facts =
        AshSurface.Ported.AshNames.facts(
          CalcResource,
          Ash.Resource.Info.action(CalcResource, :read)
        )

      Enum.find(facts.calculations, &(&1.name == name))
    end

    test "attribute with string type is primitive" do
      attr = Ash.Resource.Info.attribute(CalcResource, :title)
      a = TypeFacts.analyze(attr.type, attr.constraints)
      refute EmbeddedSchema.container?(a.definition)
    end

    test "attribute with embedded resource type is embedded" do
      attr = Ash.Resource.Info.attribute(AshSurface.Ported.Todo, :metadata)
      a = TypeFacts.analyze(attr.type, attr.constraints)
      assert EmbeddedSchema.container?(a.definition)
    end

    test "calculation with arguments carries its argument list" do
      assert [%{} = arg] = calc("complex_calc").arguments
      assert arg[:name] == "arg1" or arg["name"] == "arg1"
    end

    test "calculation without arguments is classified by its return type" do
      c = calc("simple_calc")
      assert c.arguments == []
      assert c.return_kind == "string"
    end
  end
end
