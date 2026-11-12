defmodule AshSurface.ParityDeepen.SchemaCourtsTest do
  @moduledoc """
  Wave-3 F1-deepen courts: shared-sub-schema emission, `zod_schema_suffix`, the TypeMapper
  kind table, and aggregate kinds. Real renderers, ZodGuard admission, and real node + zod
  evaluation of the emitted expressions. No doubles.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Compiler.{CalculationSchema, EmbeddedSchema, ZodType}
  alias AshSurface.Config
  alias AshSurface.Config.Verifier
  alias AshSurface.Projectors.JS.ZodGuard

  @root Path.expand("../../..", __DIR__)

  defp f(name, type), do: %{"name" => name, "type" => type}
  defp ref(name), do: %{"kind" => "embedded_resource", "resource" => name}

  # Evaluates `expr` (a zod expression) against `value` under real node + zod.
  defp node_parse(expr, value) do
    script = """
    import { z } from "zod";
    const schema = #{expr};
    const r = schema.safeParse(#{Jason.encode!(value)});
    console.log(JSON.stringify({ success: r.success }));
    """

    {out, 0} =
      System.cmd("node", ["--input-type=module", "-e", script], cd: @root, stderr_to_stdout: true)

    out
    |> String.trim()
    |> String.split("\n")
    |> List.last()
    |> Jason.decode!()
    |> Map.fetch!("success")
  end

  defp count(haystack, needle), do: length(String.split(haystack, needle)) - 1

  describe "codegen.module.Codegen.SharedSchemaGenerator (counterpart: inlined shared sub-schema)" do
    test "an embedded resource referenced several times is emitted identically at every site" do
      res = %{"N" => [f("label", %{"kind" => "string"}), f("n", %{"kind" => "integer"})]}
      assert {:ok, inner} = EmbeddedSchema.render(%{"type" => ref("N")}, resources: res)

      holder = %{
        "type" => %{
          "kind" => "typed_map",
          "fields" => [
            f("a", ref("N")),
            f("b", ref("N")),
            f("many", %{"kind" => "array", "items" => ref("N")})
          ]
        }
      }

      assert {:ok, outer} = EmbeddedSchema.render(holder, resources: res)

      # shared sub-schema is inlined consistently at all three reference sites, no shared const
      assert count(outer, inner) == 3
      refute outer =~ "const "
      assert {:ok, _, _} = ZodGuard.admit(outer)

      # and executes under real zod: each site enforces the same shape
      good = %{"label" => "x", "n" => 1}
      assert node_parse(outer, %{"a" => good, "b" => good, "many" => [good, good]})
      refute node_parse(outer, %{"a" => good, "b" => %{"label" => 1, "n" => 1}, "many" => []})
      refute node_parse(outer, %{"a" => good, "b" => good, "many" => [good, %{"label" => "x"}]})
    end

    test "rendering is deterministic: the same references render byte-identically" do
      res = %{"N" => [f("label", %{"kind" => "string"})]}
      d = %{"type" => %{"kind" => "typed_map", "fields" => [f("a", ref("N")), f("b", ref("N"))]}}
      assert EmbeddedSchema.render(d, resources: res) == EmbeddedSchema.render(d, resources: res)
    end
  end

  describe "config.key.zod_schema_suffix" do
    setup do
      prior = Application.fetch_env(:ash_surface, :zod_schema_suffix)
      Application.delete_env(:ash_surface, :zod_schema_suffix)

      on_exit(fn ->
        case prior do
          {:ok, v} -> Application.put_env(:ash_surface, :zod_schema_suffix, v)
          :error -> Application.delete_env(:ash_surface, :zod_schema_suffix)
        end
      end)
    end

    test "default is ZodSchema and the verifier admits it" do
      assert Config.zod_schema_suffix() == "ZodSchema"
      assert Verifier.verify() == :ok
    end

    test "Application.put_env overrides the accessor and a valid override verifies" do
      Application.put_env(:ash_surface, :zod_schema_suffix, "Zs")
      assert Config.zod_schema_suffix() == "Zs"
      assert Verifier.verify() == :ok
    end

    test "verifier refuses a non-string and a non-identifier suffix" do
      Application.put_env(:ash_surface, :zod_schema_suffix, 5)
      assert {:error, errs} = Verifier.verify()
      assert Enum.any?(errs, &(&1 =~ "zod_schema_suffix"))

      Application.put_env(:ash_surface, :zod_schema_suffix, "1 bad")
      assert {:error, errs} = Verifier.verify()
      assert Enum.any?(errs, &(&1 =~ "zod_schema_suffix"))
    end

    test "consumer: inlined embedded references carry no suffix-named identifier (admitted by ZodGuard)" do
      res = %{"N" => [f("label", %{"kind" => "string"})]}
      d = %{"type" => ref("N")}
      Application.put_env(:ash_surface, :zod_schema_suffix, "OverrideSfx")

      assert {:ok, via_config} = EmbeddedSchema.render(d, resources: res)
      assert {:ok, via_opt} = EmbeddedSchema.render(d, resources: res, schema_suffix: "Opt")
      # inline law (wave3-f1r): no named schema references, so the suffix never leaks into output
      assert via_config == via_opt
      refute via_config =~ "OverrideSfx"
      assert {:ok, _, _} = ZodGuard.admit(via_config)
    end
  end

  describe "codegen.module.Codegen.TypeMapper (hand-written expected table)" do
    @expected %{
      "any" => "z.any()",
      "array" => "z.array(z.unknown())",
      "atom" => "z.string()",
      "binary" => "z.string()",
      "binary_id" => "z.guid()",
      "boolean" => "z.boolean()",
      "ci_string" => "z.string()",
      "date" => "z.iso.date()",
      "date_time" => "z.iso.datetime()",
      "datetime" => "z.iso.datetime()",
      "decimal" => "z.string()",
      "duration" => "z.iso.duration()",
      "duration_name" => "z.string()",
      "enum" => "z.string()",
      "file" => "z.any()",
      "float" => "z.number()",
      "function" => "z.any()",
      "integer" => "z.number().int()",
      "keyword" => "z.record(z.string(), z.unknown())",
      "ltree" => "z.union([z.string(), z.array(z.string())])",
      "map" => "z.record(z.string(), z.unknown())",
      "module" => "z.string()",
      "naive_datetime" => "z.iso.datetime({local: true})",
      "string" => "z.string()",
      "struct" => "z.record(z.string(), z.unknown())",
      "term" => "z.any()",
      "time" => "z.iso.time()",
      "time_usec" => "z.iso.time()",
      "tuple" => "z.record(z.string(), z.unknown())",
      "url_encoded_binary" => "z.string()",
      "utc_datetime" => "z.iso.datetime()",
      "utc_datetime_usec" => "z.iso.datetime()",
      "uuid" => "z.guid()",
      "uuid_v7" => "z.uuid()",
      "vector" => "z.array(z.number())"
    }

    test "the table covers exactly the kinds ZodType knows" do
      assert @expected |> Map.keys() |> Enum.sort() == ZodType.kinds()
    end

    # KD-05 (wave3-f1kd.md): map/keyword/tuple/struct spell z.unknown() (witnessed divergence).
    for {kind, text} <- @expected do
      @kind kind
      @text text
      test "kind #{kind} maps to #{text}" do
        assert ZodType.base(@kind) == @text
        assert ZodType.fragment(%{"type" => %{"kind" => @kind}}) == @text
      end
    end

    test "an unmapped kind degrades to z.unknown() and is reported as unmappable" do
      assert ZodType.base("no_such_kind") == "z.unknown()"

      assert ZodType.unmappable_kinds([%{"type" => %{"kind" => "no_such_kind"}}]) == [
               "no_such_kind"
             ]
    end

    test "overrides replace the base fragment for the overridden kind only" do
      assert ZodType.base("string", overrides: %{"string" => "z.string().trim()"}) ==
               "z.string().trim()"
    end
  end

  describe "aggregate kinds" do
    defp one(kind, field_kind \\ :integer) do
      assert {:ok, [{name, zod}]} =
               CalculationSchema.render_aggregate_schemas([
                 %{name: "agg", kind: kind, field_kind: field_kind}
               ])

      assert name == "agg"
      assert {:ok, _, _} = ZodGuard.admit(zod)
      zod
    end

    test "type.aggregate.integer: a sum over an :integer field renders a nullable number" do
      zod = one(:sum, :integer)
      assert zod == "z.number().nullable()"
      assert node_parse(zod, 3)
      assert node_parse(zod, nil)
      refute node_parse(zod, "3")
      # field_kind selects the base: a :string field under :first renders a string base
      assert one(:first, :string) =~ "z.string()"
    end

    test "type.kind.count: never null, always an integer" do
      zod = one(:count)
      refute zod =~ "nullable()"
      assert node_parse(zod, 0)
      refute node_parse(zod, nil)
      refute node_parse(zod, 1.5)
    end

    test "type.kind.sum: nullable over an empty relationship, typed by the field" do
      zod = one(:sum, :integer)
      assert node_parse(zod, nil)
      assert node_parse(zod, 10)
      refute node_parse(zod, "ten")

      assert {:ok, [line]} =
               CalculationSchema.render_aggregate_metadata([
                 %{name: "agg", kind: :sum, field_kind: :integer}
               ])

      assert line =~ "| null"

      assert {:ok, [cline]} =
               CalculationSchema.render_aggregate_metadata([%{name: "agg", kind: :count}])

      assert cline =~ "{number}"
      refute cline =~ "| null"
    end
  end

  describe "aggregate kind rows (literal titles; each kind against its hand-written expression)" do
    defp agg(kind), do: one(kind, :integer)

    test "type.aggregate :count over an integer field renders z.number().int()" do
      assert agg(:count) == "z.number().int()"
    end

    test "type.aggregate :avg over an integer field renders z.number().nullable()" do
      assert agg(:avg) == "z.number().nullable()"
    end

    test "type.aggregate :max over an integer field renders z.number().int().nullable()" do
      assert agg(:max) == "z.number().int().nullable()"
    end

    test "type.aggregate :min over an integer field renders z.number().int().nullable()" do
      assert agg(:min) == "z.number().int().nullable()"
    end

    test "type.aggregate :sum over an integer field renders z.number().nullable()" do
      assert agg(:sum) == "z.number().nullable()"
    end

    test "type.aggregate :first over an integer field renders z.number().int().nullable()" do
      assert agg(:first) == "z.number().int().nullable()"
    end

    test "type.aggregate :last over an integer field renders z.number().int().nullable()" do
      assert agg(:last) == "z.number().int().nullable()"
    end

    test "type.aggregate :exists over an integer field renders z.boolean()" do
      assert agg(:exists) == "z.boolean()"
    end

    test "type.aggregate :list over an integer field renders z.array(z.number().int())" do
      assert agg(:list) == "z.array(z.number().int())"
    end

    test "type.aggregate :custom over an integer field renders z.any()" do
      assert agg(:custom) == "z.any()"
    end
  end
end
