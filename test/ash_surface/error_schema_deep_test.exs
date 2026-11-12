defmodule AshSurface.ErrorSchemaDeepTest do
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.{ErrorSchema, ValidationErrorSchema}
  alias AshSurface.IR.ErrorShape
  alias AshSurface.Projectors.JS.ZodGuard

  defp t(kind, extra \\ %{}), do: %{"type" => Map.merge(%{"kind" => kind}, extra)}
  defp f(name, kind, extra \\ %{}), do: Map.put(t(kind, extra), "name", name)

  defp me(def, opts \\ []) do
    {:ok, expr} = ValidationErrorSchema.map_error_type(def, opts)
    expr
  end

  defp node_validate(expr, payloads) do
    node = System.find_executable("node") || raise "REQUIRED TOOL MISSING: node"
    root = File.cwd!()
    File.dir?(Path.join(root, "node_modules/zod")) || raise "REQUIRED PACKAGE MISSING: zod"
    dir = Path.join(System.tmp_dir!(), "ash_surface_esd_#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(dir)
    File.ln_s!(Path.join(root, "node_modules"), Path.join(dir, "node_modules"))

    File.write!(Path.join(dir, "run.mjs"), """
    import { z } from "zod";
    import { readFileSync } from "node:fs";
    const E = #{expr};
    const ps = JSON.parse(readFileSync(new URL("./p.json", import.meta.url), "utf8"));
    process.stdout.write(JSON.stringify(ps.map((p) => E.safeParse(p).success)));
    """)

    File.write!(Path.join(dir, "p.json"), Jason.encode!(payloads))
    {out, 0} = System.cmd(node, ["run.mjs"], cd: dir, stderr_to_stdout: true)
    File.rm_rf!(dir)
    Jason.decode!(out)
  end

  describe "ErrorSchema" do
    test "20 variants, every one guarded, discriminator literal per type" do
      {:ok, r} = ErrorSchema.render()
      assert map_size(r.variants) == 20

      for {type, expr} <- r.variants do
        assert :ok = ZodGuard.expression(expr)
        assert expr =~ ~s|type: z.literal("#{type}")|
      end
    end

    test "default keys are camel-only; formatter opts rename keys in every renderer" do
      assert ErrorSchema.base() =~ "shortMessage"
      refute ErrorSchema.base() =~ "short_message"
      assert ErrorSchema.base(formatter: :snake_case) =~ "short_message"
      assert ErrorSchema.base(formatter: :pascal_case) =~ "ShortMessage"

      assert ErrorSchema.variant("required", formatter: :pascal_case) =~
               ~s|Type: z.literal("required")|

      assert ErrorSchema.union(formatter: :pascal_case) =~ ~s|z.discriminatedUnion("Type"|
      {:ok, r} = ErrorSchema.render(%{}, formatter: &String.upcase/1)
      assert r.base =~ "SHORT_MESSAGE"
    end

    test "carry/2 renders {errors, fieldErrors} per action, guarded, deterministic" do
      {:ok, r} = ErrorSchema.render(%{create: [:title, :body]})
      assert r.carry["create"] =~ "z.object({errors: z.array(z.discriminatedUnion("

      assert r.carry["create"] =~
               "fieldErrors: z.object({body: z.array(z.string()).optional(), title:"

      assert :ok = ZodGuard.expression(r.carry["create"])
      assert ErrorSchema.carry([:b, :a]) == ErrorSchema.carry([:a, :b, :a])
      assert ErrorSchema.carry([:a], formatter: :snake_case) =~ "field_errors:"
    end

    test "carry executes in zod: accepts errors+fieldErrors, refuses unknown keys" do
      expr = ErrorSchema.carry([:title])

      err = %{
        "type" => "required",
        "message" => "m",
        "shortMessage" => "s",
        "vars" => %{},
        "fields" => ["title"],
        "path" => []
      }

      ok = %{"errors" => [err], "fieldErrors" => %{"title" => ["blank"]}}

      assert node_validate(expr, [
               ok,
               %{"errors" => []},
               Map.put(ok, "x", 1),
               put_in(ok, ["fieldErrors", "zzz"], ["a"])
             ]) ==
               [true, true, false, false]
    end

    test "every type normalises into the closed set" do
      for t <- ErrorShape.types(), do: assert(ErrorShape.normalize_type(t) == t)
    end
  end

  describe "ValidationErrorSchema" do
    test "scalar and nil definitions are message arrays" do
      assert me(t("string")) == "z.array(z.string())"
      assert me(nil) == "z.array(z.string())"
      assert me(t("integer")) == "z.array(z.string())"
    end

    test "arrays recurse" do
      def = t("array", %{"items" => t("array", %{"items" => %{"kind" => "string"}})})
      assert me(def) == "z.array(z.array(z.array(z.string())))"
    end

    test "embedded resource with fields, formatted names, optional keys" do
      def =
        t("embedded_resource", %{"fields" => [f("street_line", "string"), f("zip", "string")]})

      assert me(def) ==
               "z.object({streetLine: z.array(z.string()).optional(), zip: z.array(z.string()).optional()}).strict()"

      assert me(def, formatter: :snake_case) =~ "street_line:"
    end

    test "typed containers: map-form fields sorted; no fields -> record" do
      def = t("typed_map", %{"fields" => %{"b" => t("string"), "a" => t("integer")}})
      assert me(def) =~ "z.object({a: "
      assert me(t("map")) == "z.record(z.string(), z.unknown())"
      assert me(t("keyword", %{"fields" => []})) =~ "z.record"
      assert me(t("tuple", %{"fields" => [f("x", "string")]})) =~ "x:"
    end

    test "union maps to object keyed by member, empty union -> record" do
      def =
        t("union", %{
          "members" => [
            %{"name" => "text", "type" => t("string")},
            %{
              "name" => "addr",
              "type" => t("embedded_resource", %{"fields" => [f("zip", "string")]})
            }
          ]
        })

      assert me(def) ==
               "z.object({text: z.array(z.string()).optional(), addr: z.object({zip: z.array(z.string()).optional()}).strict().optional()}).strict()"

      assert me(t("union", %{"members" => []})) == "z.record(z.string(), z.unknown())"
    end

    test "resource references and cycles terminate" do
      # Re-pinned (S1-G M8): ZodGuard refuses bare identifiers, so references are
      # inlined from :resources, and degrade to the record when unresolvable.
      rec = "z.record(z.string(), z.unknown())"
      assert me(t("resource", %{"instance_of" => "My.Todo"})) == rec

      todo = %{"My.Todo" => [f("title", "string")]}

      assert {:ok, e} =
               ValidationErrorSchema.render(t("resource", %{"instance_of" => "My.Todo"}),
                 resources: todo
               )

      assert e =~ "z.object({title:"

      resources = %{
        "My.Node" => [
          f("child", "embedded_resource", %{"resource" => "My.Node"}),
          f("name", "string")
        ]
      }

      def = t("embedded_resource", %{"resource" => "My.Node"})
      expr = me(def, resources: resources)
      assert expr =~ "child: z.record(z.string(), z.unknown()).optional()"
      assert expr =~ "name:"
    end

    test "atom-keyed kind maps and render/2 guard" do
      assert {:ok, "z.array(z.string())"} =
               ValidationErrorSchema.render(%{type: %{kind: :string}})

      assert {:ok, e} =
               ValidationErrorSchema.render(
                 t("array", %{
                   "items" => t("embedded_resource", %{"fields" => [f("zip", "string")]})
                 })
               )

      assert :ok = ZodGuard.expression(e)

      assert me(t("array", %{"items" => t("string")})) ==
               me(t("array", %{"items" => t("string")}))
    end

    test "executes in zod: nested embedded/union/array error payloads" do
      def =
        t("embedded_resource", %{
          "fields" => [
            f("title", "string"),
            f("tags", "array", %{"items" => %{"kind" => "string"}}),
            f("ref", "union", %{"members" => [%{"name" => "text", "type" => t("string")}]})
          ]
        })

      {:ok, expr} = ValidationErrorSchema.render(def)

      payloads = [
        %{"title" => ["blank"], "tags" => [["bad"], ["worse"]], "ref" => %{"text" => ["x"]}},
        %{},
        %{"title" => "blank"},
        %{"nope" => ["x"]},
        %{"tags" => ["bad"]}
      ]

      assert node_validate(expr, payloads) == [true, true, false, false, false]
    end
  end
end
