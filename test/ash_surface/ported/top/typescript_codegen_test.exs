Code.require_file("support/t2.exs", __DIR__)

defmodule AshSurface.Ported.Top.TypescriptCodegenTest do
  @moduledoc """
  Adaptation of ash_typescript `typescript_codegen_test.exs`. The reference asserts the TypeScript
  text of `get_ts_type/2`, `build_map_type/2` and `generate_unified_resource_schema/2`; ash_surface
  generates no `.ts`, so each case asserts the Zod expression the real compiler pieces produce for
  the same Ash type (`TypeFacts` -> `ZodType` / `EmbeddedSchema`), and executes the structured
  ones under real node + zod. Per-test dispositions:

    * `get_ts_type` basic/constrained/array/union/struct/enum cases: Zod fragment + node.
    * `build_map_type/2` field-list cases: `EmbeddedSchema.render/1` of a typed-map definition.
      "selected fields only" is `EmbeddedSchema.render(def, select: names)` and the primitive-field
      set is `EmbeddedSchema.primitive_fields/2` (both executed below).
    * `generate_unified_resource_schema/2`: `RecordSchema.render/2` (Zod, wire names = Ash names
      unless the resource maps them) executed under node + zod: per-key accept/reject and
      nullability instead of TS text. The Todo/TodoComment/embedded-reference cases are real.
    * `untyped_map_type`: a TS-only key; the Zod analogue is the `zod_mapping_overrides` kind table.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Compiler.{EmbeddedSchema, TypeFacts, ZodType}
  alias AshSurface.Ported.{T2, Todo, TodoMetadata}
  alias AshSurface.ZodFixtures.CalcAgg

  defp accepts(zod, payloads) do
    assert {:ok, oks} = T2.node_eval(zod, payloads)
    oks
  end

  @status ~s|z.enum(["cancelled", "finished", "ongoing", "pending"])|

  describe "type fragments - basic types (was: get_ts_type/2)" do
    test "converts nil type" do
      assert TypeFacts.kind(nil) == "unknown"
      assert T2.zod(nil) == "z.unknown()"
    end

    test "converts aggregate types (count/sum) through the real aggregate facts" do
      kinds =
        T2.read_facts(CalcAgg.Item).filter_entries
        |> Map.new(&{&1["name"], {&1["type"]["kind"], &1["allow_nil?"]}})

      assert kinds["line_count"] == {"integer", false}
      assert kinds["total_qty"] == {"integer", true}
      assert kinds["avg_price"] == {"float", true}
    end

    test "converts string types" do
      assert T2.zod(Ash.Type.String) == "z.string()"
      assert T2.zod(Ash.Type.CiString) == "z.string()"
      assert T2.kind(Ash.Type.CiString) == "ci_string"
    end

    test "converts number types" do
      assert T2.zod(Ash.Type.Integer) == "z.number().int()"
      assert T2.zod(Ash.Type.Float) == "z.number()"
      assert T2.zod(Ash.Type.Decimal) == "z.string()"
    end

    test "converts boolean type" do
      assert T2.zod(Ash.Type.Boolean) == "z.boolean()"
    end

    test "converts UUID types" do
      assert T2.zod(Ash.Type.UUID) == "z.guid()"
      assert T2.zod(Ash.Type.UUIDv7) == "z.guid()"
      assert [true, false] = accepts(T2.zod(Ash.Type.UUID), [Ash.UUID.generate(), "nope"])
    end

    test "converts date/time types" do
      assert T2.zod(Ash.Type.Date) == "z.iso.date()"
      assert T2.zod(Ash.Type.Time) == "z.iso.time()"
      assert T2.zod(Ash.Type.DateTime) == "z.iso.datetime()"
      assert T2.zod(Ash.Type.UtcDatetime) == "z.iso.datetime()"
      assert T2.zod(Ash.Type.UtcDatetimeUsec) == "z.iso.datetime()"
      assert T2.zod(Ash.Type.NaiveDatetime) == "z.iso.datetime({local: true})"

      assert [true, false] =
               accepts(T2.zod(Ash.Type.UtcDatetime), ["2024-01-01T00:00:00Z", "2024-01-01"])
    end

    test "converts other basic types" do
      assert T2.zod(Ash.Type.Binary) == "z.string()"
      assert T2.zod(Ash.Type.UrlEncodedBinary) == "z.string()"
      assert T2.zod(Ash.Type.Term) == "z.any()"
      assert T2.zod(Ash.Type.Vector) == "z.array(z.number())"
      assert [true, false] = accepts(T2.zod(Ash.Type.Vector), [[0.5, 1], ["x"]])
      assert T2.zod(Ash.Type.Module) == "z.string()"
    end
  end

  describe "type fragments - constrained types" do
    test "converts unconstrained atom to string" do
      assert T2.zod(Ash.Type.Atom) == "z.string()"
    end

    test "converts constrained atom with one_of to an enum" do
      zod = T2.zod(Ash.Type.Atom, one_of: [:pending, :completed])
      assert zod == ~s|z.enum(["completed", "pending"])|
      assert [true, false] = accepts(zod, ["pending", "other"])
    end

    test "converts Ash.Type.Enum to an enum" do
      assert T2.zod(Todo.Status) == @status
    end

    test "converts unconstrained map to a generic record" do
      assert T2.zod(Ash.Type.Map) == "z.record(z.string(), z.unknown())"
    end

    test "converts constrained map with fields to a typed object" do
      constraints = [
        fields: [
          name: [type: :string, allow_nil?: false],
          age: [type: :integer, allow_nil?: true]
        ]
      ]

      zod = T2.zod_full(Ash.Type.Map, constraints)

      assert zod ==
               "z.object({ name: z.string(), age: z.number().int().nullable().optional() }).strict()"

      assert [true, true, true, false, false, false] =
               accepts(zod, [
                 %{"name" => "a"},
                 %{"name" => "a", "age" => 3},
                 %{"name" => "a", "age" => nil},
                 %{},
                 %{"name" => 1},
                 %{"name" => "a", "extra" => true}
               ])
    end

    test "converts keyword type with fields" do
      constraints = [
        fields: [
          key1: [type: :string, allow_nil?: false],
          key2: [type: :boolean, allow_nil?: true]
        ]
      ]

      zod = T2.zod_full(Ash.Type.Keyword, constraints)

      assert zod ==
               "z.object({ key1: z.string(), key2: z.boolean().nullable().optional() }).strict()"

      assert [true, false] = accepts(zod, [%{"key1" => "x"}, %{"key2" => true}])
    end

    test "converts tuple type with fields" do
      constraints = [
        fields: [
          first: [type: :string, allow_nil?: false],
          second: [type: :integer, allow_nil?: false]
        ]
      ]

      zod = T2.zod_full(Ash.Type.Tuple, constraints)
      assert zod == "z.object({ first: z.string(), second: z.number().int() }).strict()"
      assert [true, false] = accepts(zod, [%{"first" => "a", "second" => 1}, %{"first" => "a"}])
    end
  end

  describe "type fragments - array types" do
    test "converts array of basic types" do
      assert T2.zod({:array, Ash.Type.String}) == "z.array(z.string())"
    end

    test "converts array with item constraints" do
      assert T2.zod({:array, Ash.Type.Integer}) == "z.array(z.number().int())"
      assert [true, false] = accepts(T2.zod({:array, Ash.Type.Integer}), [[1, 2], [1, "x"]])
    end
  end

  describe "type fragments - union types" do
    test "converts empty union to any" do
      assert T2.zod_full(Ash.Type.Union, types: []) == "z.any()"
    end

    test "converts union with multiple types" do
      zod =
        T2.zod_full(Ash.Type.Union,
          types: [
            string: [type: :string, constraints: []],
            integer: [type: :integer, constraints: []]
          ]
        )

      assert zod ==
               "z.union([z.object({string: z.string()}).strict(), z.object({integer: z.number().int()}).strict()])"

      assert [true, true, false, false] =
               accepts(zod, [
                 %{"string" => "a"},
                 %{"integer" => 1},
                 %{"string" => 1},
                 %{"other" => 1}
               ])
    end

    test "keeps every member of a union, including members of the same underlying type" do
      zod =
        T2.zod_full(Ash.Type.Union,
          types: [
            string1: [type: :string, constraints: []],
            string2: [type: :string, constraints: []],
            integer: [type: :integer, constraints: []]
          ]
        )

      assert zod =~ "string1: z.string()"
      assert zod =~ "string2: z.string()"
      assert zod =~ "integer: z.number().int()"

      assert [true, true, true] =
               accepts(zod, [%{"string1" => "a"}, %{"string2" => "b"}, %{"integer" => 1}])
    end
  end

  describe "type fragments - struct types" do
    test "converts struct with fields to a typed object" do
      constraints = [
        fields: [
          name: [type: :string, allow_nil?: false],
          active: [type: :boolean, allow_nil?: true]
        ]
      ]

      zod = T2.zod_full(Ash.Type.Struct, constraints)

      assert zod ==
               "z.object({ name: z.string(), active: z.boolean().nullable().optional() }).strict()"
    end

    test "converts struct with instance_of to a resource reference" do
      definition = TypeFacts.analyze(Ash.Type.Struct, instance_of: Todo).definition
      assert definition["type"]["kind"] == "resource"
      assert definition["type"]["instance_of"] == inspect(Todo)

      assert T2.zod_full(Ash.Type.Struct, instance_of: Todo) ==
               "z.record(z.string(), z.unknown())"
    end

    test "converts unconstrained struct to a generic record" do
      assert T2.zod(Ash.Type.Struct) == "z.record(z.string(), z.unknown())"
    end
  end

  describe "type fragments - enum types" do
    test "converts Ash.Type.Enum to an enum via the behaviour" do
      assert T2.zod(Todo.Status) == @status
    end

    test "converts enum in array to array of enums" do
      assert T2.zod({:array, Todo.Status}) == "z.array(#{@status})"
    end

    test "handles enum in map field constraints" do
      zod = T2.zod_full(Ash.Type.Map, fields: [status: [type: Todo.Status, allow_nil?: false]])
      assert zod == "z.object({ status: #{@status} }).strict()"
      assert [true, false] = accepts(zod, [%{"status" => "pending"}, %{"status" => "bogus"}])
    end

    test "handles enum in union type" do
      zod =
        T2.zod_full(Ash.Type.Union,
          types: [
            status: [type: Todo.Status, constraints: []],
            string: [type: :string, constraints: []]
          ]
        )

      assert zod =~ "pending"
      assert zod =~ "string: z.string()"
    end

    test "handles enum in struct fields" do
      zod =
        T2.zod_full(Ash.Type.Struct,
          fields: [
            status: [type: Todo.Status, allow_nil?: false],
            name: [type: :string, allow_nil?: false]
          ]
        )

      assert zod =~ "pending"
      assert zod =~ "name: z.string()"
    end
  end

  describe "typed map definitions (was: build_map_type/2)" do
    defp typed_map(fields), do: %{"type" => %{"kind" => "map", "fields" => fields}}

    test "builds map type with all fields" do
      def_ =
        typed_map([T2.field(:name, Ash.Type.String, [], false), T2.field(:age, Ash.Type.Integer)])

      assert {:ok, zod} = EmbeddedSchema.render(def_)

      assert zod ==
               "z.object({ name: z.string(), age: z.number().int().nullable().optional() }).strict()"
    end

    test "handles empty field list" do
      # No declared subfields: an open record (the reference's `never` primitive union).
      assert {:ok, "z.record(z.string(), z.unknown())"} = EmbeddedSchema.render(typed_map([]))
    end

    test "map field with no declared subfields is a plain record field" do
      def_ =
        typed_map([
          T2.field(:name, Ash.Type.String, [], false),
          T2.field(:metadata, Ash.Type.Map)
        ])

      assert {:ok, zod} = EmbeddedSchema.render(def_)
      assert zod =~ "name: z.string()"
      assert zod =~ "metadata: z.record(z.string(), z.unknown()).nullable().optional()"

      assert [true, true] =
               accepts(zod, [%{"name" => "a", "metadata" => %{"x" => 1}}, %{"name" => "a"}])
    end

    test "typed map whose only field is a plain map keeps that field" do
      def_ = typed_map([T2.field(:metadata, Ash.Type.Map, [], false)])
      assert {:ok, zod} = EmbeddedSchema.render(def_)
      assert zod =~ "metadata: z.record(z.string(), z.unknown())"
      refute zod =~ "z.never"
      assert [true, false] = accepts(zod, [%{"metadata" => %{}}, %{}])
    end

    test "array of plain maps is a field" do
      def_ = typed_map([T2.field(:entries, {:array, Ash.Type.Map}, [], false)])
      assert {:ok, zod} = EmbeddedSchema.render(def_)
      assert zod =~ "entries: z.array(z.record(z.string(), z.unknown()))"
      assert [true, false] = accepts(zod, [%{"entries" => [%{"a" => 1}]}, %{"entries" => [1]}])
    end

    test "map field with declared subfields renders as a nested object" do
      nested =
        T2.field(
          :details,
          Ash.Type.Map,
          [fields: [count: [type: :integer, allow_nil?: false]]],
          false
        )

      def_ = typed_map([T2.field(:name, Ash.Type.String, [], false), nested])
      assert {:ok, zod} = EmbeddedSchema.render(def_)
      assert zod =~ "details: z.object({ count: z.number().int() }).strict()"

      assert [true, false] =
               accepts(zod, [
                 %{"name" => "a", "details" => %{"count" => 1}},
                 %{"name" => "a", "details" => %{}}
               ])
    end
  end

  describe "error handling" do
    test "an unsupported type is an unmappable kind (typed), not a silent fragment" do
      definition = TypeFacts.analyze(MyApp.CustomUnsupportedType).definition
      assert definition["type"]["kind"] == "unknown"
      assert ZodType.unmappable_kinds([definition]) == ["unknown"]
    end
  end

  describe "integration tests with real resources (field facts)" do
    @entries Todo |> T2.read_facts() |> Map.fetch!(:filter_entries)
    @facts Map.new(@entries, &{&1["name"], {&1["type"]["kind"], &1["allow_nil?"]}})

    test "Todo resource field types and nullability" do
      assert @facts["id"] == {"uuid", false}
      assert @facts["title"] == {"string", false}
      assert @facts["description"] == {"string", true}
      assert @facts["completed"] == {"boolean", true}
      assert @facts["status"] == {"enum", true}
      assert @facts["priority"] == {"enum", true}
      assert @facts["due_date"] == {"date", true}
      assert @facts["tags"] == {"array", true}
      assert @facts["user_id"] == {"uuid", false}

      # Count aggregates are never nullable; calculations keep their declared type, nullable
      assert @facts["comment_count"] == {"integer", false}
      assert @facts["is_overdue"] == {"boolean", true}
      assert @facts["days_until_due"] == {"integer", true}
    end

    test "embedded resource references are carried by name and expanded by the compiler closure" do
      assert @facts["metadata"] == {"embedded_resource", true}
      assert @facts["metadata_history"] == {"array", true}

      defs =
        for attr <- Ash.Resource.Info.public_attributes(Todo),
            attr.name in [:metadata, :metadata_history],
            do: TypeFacts.analyze(attr.type, attr.constraints).definition

      assert Map.has_key?(TypeFacts.embedded_resources(defs), inspect(TodoMetadata))
    end

    test "Todo status attribute: enum values are carried into the Zod enum" do
      attr = Ash.Resource.Info.attribute(Todo, :status)
      assert T2.zod(attr.type, attr.constraints) == @status
    end
  end

  describe "untyped_map_type configuration (Zod analogue: zod_mapping_overrides kind table)" do
    test "uses the default open record when not configured" do
      assert AshSurface.Config.untyped_map_type() == "Record<string, any>"

      for type <- [Ash.Type.Map, Ash.Type.Keyword, Ash.Type.Tuple, Ash.Type.Struct] do
        assert T2.zod(type) == "z.record(z.string(), z.unknown())"
      end
    end

    test "uses the configured type when untyped_map_type is set" do
      T2.with_env(:untyped_map_type, "Record<string, unknown>", fn ->
        assert AshSurface.Config.untyped_map_type() == "Record<string, unknown>"
      end)

      overrides = %{
        "map" => "z.record(z.string(), z.unknown())",
        "keyword" => "z.record(z.string(), z.unknown())",
        "tuple" => "z.record(z.string(), z.unknown())",
        "struct" => "z.record(z.string(), z.unknown())"
      }

      T2.with_env(:zod_mapping_overrides, overrides, fn ->
        for type <- [Ash.Type.Map, Ash.Type.Keyword, Ash.Type.Tuple, Ash.Type.Struct] do
          assert T2.zod(type) == "z.record(z.string(), z.unknown())"
        end
      end)
    end

    test "uses a custom type when set to a custom value" do
      T2.with_env(:untyped_map_type, "MyCustomMapType", fn ->
        assert AshSurface.Config.untyped_map_type() == "MyCustomMapType"
      end)

      T2.with_env(:zod_mapping_overrides, %{"map" => "z.any()", "keyword" => "z.any()"}, fn ->
        assert T2.zod(Ash.Type.Map) == "z.any()"
        assert T2.zod(Ash.Type.Keyword) == "z.any()"
      end)
    end

    test "constrained maps still use typed objects regardless of config" do
      T2.with_env(:zod_mapping_overrides, %{"map" => "z.any()"}, fn ->
        constraints = [
          fields: [
            name: [type: :string, allow_nil?: false],
            age: [type: :integer, allow_nil?: true]
          ]
        ]

        assert T2.zod_full(Ash.Type.Map, constraints) ==
                 "z.object({ name: z.string(), age: z.number().int().nullable().optional() }).strict()"
      end)
    end

    test "input position uses the same configured fragment" do
      # ash_surface has one fragment table for inputs and outputs (get_ts_input_type analogue).
      T2.with_env(:zod_mapping_overrides, %{"map" => "z.record(z.string(), z.unknown())"}, fn ->
        assert T2.zod(Ash.Type.Map) == "z.record(z.string(), z.unknown())"
        assert T2.zod({:array, Ash.Type.Map}) == "z.array(z.record(z.string(), z.unknown()))"
      end)
    end
  end

  describe "selected fields and the primitive field set (was: build_map_type/2)" do
    defp map_definition(fields),
      do: %{
        "type" => %{
          "kind" => "typed_map",
          "fields" =>
            for({name, type, allow_nil?} <- fields, do: T2.field(name, type, [], allow_nil?))
        }
      }

    test "builds map type with selected fields only" do
      definition =
        map_definition([
          {:name, Ash.Type.String, false},
          {:age, Ash.Type.Integer, true},
          {:email, Ash.Type.String, false}
        ])

      assert {:ok, zod} = EmbeddedSchema.render(definition, select: ["name", "age"])
      assert zod =~ "name: z.string()"
      assert zod =~ "age: z.number().int().nullable().optional()"
      refute zod =~ "email"

      # the narrowed schema is strict: the unselected key is rejected under real zod
      assert accepts(zod, [%{"name" => "n", "age" => 1}, %{"name" => "n", "email" => "e"}]) ==
               [true, false]

      # no selection renders every field
      assert {:ok, full} = EmbeddedSchema.render(definition)
      assert full =~ "email: z.string()"
    end

    test "map field with declared subfields is still excluded from primitive fields" do
      details =
        T2.field(
          :details,
          Ash.Type.Map,
          [fields: [count: [type: :integer, allow_nil?: false]]],
          false
        )

      definition = %{
        "type" => %{
          "kind" => "typed_map",
          "fields" => [T2.field(:name, Ash.Type.String, [], false), details]
        }
      }

      assert EmbeddedSchema.primitive_fields(definition) == ["name"]
    end

    test "map field with no declared subfields is a selectable primitive" do
      definition =
        map_definition([{:name, Ash.Type.String, false}, {:metadata, Ash.Type.Map, true}])

      assert EmbeddedSchema.primitive_fields(definition) == ["name", "metadata"]
    end

    test "embedded resources and unions need nested selection, arrays of plain maps do not" do
      todo_metadata = T2.field(:meta, TodoMetadata, [], true)

      definition = %{
        "type" => %{
          "kind" => "typed_map",
          "fields" => [
            T2.field(:entries, {:array, Ash.Type.Map}, [], false),
            todo_metadata,
            T2.field(:label, Ash.Type.String, [], false)
          ]
        }
      }

      assert EmbeddedSchema.primitive_fields(definition) == ["entries", "label"]
    end
  end

  describe "record schema for a resource (was: generate_unified_resource_schema/2)" do
    defp key_check(zod, key, accept, reject) do
      probe = """
      const f = s.shape[#{Jason.encode!(key)}];
      return { present: f !== undefined,
               accept: #{Jason.encode!(accept)}.map((v) => f.safeParse(v).success),
               reject: #{Jason.encode!(reject)}.map((v) => f.safeParse(v).success) };
      """

      %{"present" => true, "accept" => a, "reject" => r} = T2.node_probe(zod, probe)
      assert Enum.all?(a), "#{key}: expected accepted #{inspect(accept)}"
      refute Enum.any?(r), "#{key}: expected rejected #{inspect(reject)}"
    end

    test "generates complete Todo record schema" do
      zod = T2.record_zod(Todo)
      uuid = "6f1b0c1e-8f43-4c0e-9b4e-7e0f5f3a2a11"

      key_check(zod, "id", [uuid], [1, nil])
      key_check(zod, "title", ["t"], [1, nil])
      key_check(zod, "description", ["d", nil], [1])
      key_check(zod, "completed", [true, nil], ["x"])
      key_check(zod, "status", ["pending", "finished", nil], ["bogus"])
      key_check(zod, "priority", ["high", "low", nil], ["bogus"])
      key_check(zod, "due_date", ["2024-01-02", nil], ["yesterday"])
      key_check(zod, "tags", [["a"], nil], ["a", [1]])
      key_check(zod, "user_id", [uuid], [nil])
    end

    test "count aggregates are never nullable, calculations keep their declared nullable type" do
      zod = T2.record_zod(Todo)
      key_check(zod, "comment_count", [0, 3], [nil, "3"])
      key_check(zod, "is_overdue", [true, nil], ["x"])
      key_check(zod, "days_until_due", [4, nil], ["x"])

      # aggregates/calculations are loaded on demand: optional keys
      assert %{"opt" => true} =
               T2.node_probe(
                 zod,
                 "return { opt: s.shape.comment_count.safeParse(undefined).success };"
               )

      assert %{"required" => false} =
               T2.node_probe(zod, "return { required: s.shape.id.safeParse(undefined).success };")
    end

    test "embedded attribute and array-of-embedded fields reference the embedded object schema" do
      zod = T2.record_zod(Todo)
      embedded = TodoMetadata |> T2.record_zod()

      assert %{"keys" => keys} = T2.node_probe(embedded, "return { keys: Object.keys(s.shape) };")
      assert "category" in keys

      # the record's metadata field is the embedded object (nullable), history an array of it
      key_check(zod, "metadata", [nil, %{"category" => "c"}], ["x", 1])
      key_check(zod, "metadata_history", [nil, [], [%{"category" => "c"}]], ["x", [1]])
    end

    test "relationships are optional record references (arrays for to-many)" do
      zod = T2.record_zod(Todo)
      key_check(zod, "user", [%{"id" => "x"}, nil], ["x"])
      key_check(zod, "comments", [[], [%{"id" => "x"}]], [nil, "x"])
    end

    test "generates complete TodoComment record schema" do
      zod = T2.record_zod(AshSurface.Ported.TodoComment)
      uuid = "6f1b0c1e-8f43-4c0e-9b4e-7e0f5f3a2a11"

      key_check(zod, "id", [uuid], [nil])
      key_check(zod, "content", ["c"], [nil, 1])
      key_check(zod, "author_name", ["a"], [nil, 1])
      key_check(zod, "rating", [3, nil], ["x"])
      key_check(zod, "is_helpful", [true, nil], ["x"])
      key_check(zod, "todo_id", [uuid], [nil])
      key_check(zod, "user_id", [uuid], [nil])
    end

    test "a module that is not a resource is a typed refusal" do
      assert {:error, {:not_a_resource, String}} = AshSurface.Compiler.RecordSchema.render(String)
    end
  end
end
