defmodule AshSurface.Compiler.EmbeddedSchemaTest do
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.EmbeddedSchema
  alias AshSurface.Projectors.JS.ZodGuard

  defp f(name, kind, extra \\ %{}),
    do: Map.merge(%{"name" => name, "type" => %{"kind" => kind}}, extra)

  defp admit!(zod), do: assert({:ok, :expression, ^zod} = ZodGuard.admit(zod))

  test "typed_struct with fields renders strict object with nullable/optional split" do
    def_ = %{
      "type" => %{
        "kind" => "typed_struct",
        "fields" => [
          f("a", "string"),
          f("b", "integer", %{"allow_nil?" => true, "omittable" => true})
        ]
      }
    }

    assert {:ok, zod} = EmbeddedSchema.render(def_)
    assert zod =~ ~r/\Az\.object\(\{ a: .+, b: .+\.nullable\(\)\.optional\(\) \}\)\.strict\(\)\z/
    admit!(zod)
  end

  for kind <- ~w(typed_map keyword tuple embedded_resource map) do
    test "#{kind} without fields is a string record" do
      assert {:ok, "z.record(z.string(), z.unknown())"} =
               EmbeddedSchema.render(%{"type" => %{"kind" => unquote(kind)}})
    end
  end

  test "container allow_nil? and omittable wrap the object" do
    def_ = %{
      "allow_nil?" => true,
      "omittable" => true,
      "type" => %{"kind" => "typed_map", "fields" => [f("a", "string")]}
    }

    assert {:ok, zod} = EmbeddedSchema.render(def_)
    assert String.ends_with?(zod, ".strict().nullable().optional()")
    admit!(zod)
  end

  test "instance_of resource is inlined from :resources (F1: guard-admissible)" do
    def_ = %{"type" => %{"kind" => "struct", "instance_of" => "My.App.Post"}}
    res = %{"My.App.Post" => [%{"name" => "title", "type" => %{"kind" => "string"}}]}
    assert {:ok, out} = EmbeddedSchema.render(def_, resources: res)
    assert out == "z.object({ title: z.string() }).strict()"

    assert {:ok, nullable} =
             EmbeddedSchema.render(Map.put(def_, "allow_nil?", true), resources: res)

    assert nullable == out <> ".nullable()"
    # unknown resource degrades to the record fallback (no bare identifier)
    assert {:ok, "z.record(z.string(), z.unknown())"} = EmbeddedSchema.render(def_)
  end

  test "embedded resource resolves through registry and nests" do
    resources = %{
      "E.Inner" => [f("x", "string")],
      "E.Outer" => [
        f("inner", "embedded_resource", %{
          "type" => %{"kind" => "embedded_resource", "resource" => "E.Inner"}
        })
      ]
    }

    def_ = %{"type" => %{"kind" => "embedded_resource", "resource" => "E.Outer"}}

    assert {:ok, zod} = EmbeddedSchema.render(def_, resources: resources)
    assert zod =~ "inner: z.object({ x: "
    refute zod =~ "lazy"
    admit!(zod)
  end

  defp cyclic do
    ref = fn n ->
      f("r", "embedded_resource", %{"type" => %{"kind" => "embedded_resource", "resource" => n}})
    end

    %{"A" => [ref.("B")], "B" => [ref.("A")]}
  end

  test "cycle without depth is a typed error with path" do
    def_ = %{"type" => %{"kind" => "embedded_resource", "resource" => "A"}}

    assert {:error, {:cyclic_schema, ["A", "B", "A"]}} =
             EmbeddedSchema.render(def_, resources: cyclic())
  end

  test "cycle with cycle_depth terminates in a record, deterministic, no z.lazy" do
    def_ = %{"type" => %{"kind" => "embedded_resource", "resource" => "A"}}
    assert {:ok, zod} = EmbeddedSchema.render(def_, resources: cyclic(), cycle_depth: 1)
    assert zod == elem(EmbeddedSchema.render(def_, resources: cyclic(), cycle_depth: 1), 1)
    assert zod =~ "z.record(z.string(), z.unknown())"
    refute zod =~ "lazy"
    admit!(zod)
  end

  test "non-identifier field names are quoted" do
    def_ = %{"type" => %{"kind" => "typed_map", "fields" => [f("default?", "boolean")]}}

    assert {:ok, zod} =
             AshSurface.Ported.AshNames.with_verbatim(fn -> EmbeddedSchema.render(def_) end)

    assert zod =~ ~s("default?": )
    admit!(zod)
  end

  describe "wave 2" do
    alias AshSurface.ZodFixtures.Harness

    defp tdef(kind, extra), do: %{"type" => Map.merge(%{"kind" => kind}, extra)}

    test "struct with non-resource instance_of and no fields is z.object({})" do
      d = tdef("struct", %{"instance_of" => "Elixir.Date"})
      # Re-pinned (S1-G L2): strict, so unknown keys are rejected not stripped.
      assert {:ok, "z.object({}).strict()"} =
               EmbeddedSchema.render(d, non_resources: ["Elixir.Date"])

      assert {:ok, "z.object({}).strict()"} =
               EmbeddedSchema.render(
                 tdef("struct", %{"instance_of" => "X", "resource?" => false})
               )

      assert {:ok, "z.object({}).strict().nullable()"} =
               EmbeddedSchema.render(
                 Map.put(d, "allow_nil?", true),
                 non_resources: ["Elixir.Date"]
               )

      # F1: unflagged instance_of is a resource ref; unknown -> record fallback
      assert {:ok, "z.record(z.string(), z.unknown())"} = EmbeddedSchema.render(d)
    end

    test "kind resource is inlined; schema_suffix is unused" do
      d = tdef("resource", %{"instance_of" => "My.App.Post"})
      res = %{"My.App.Post" => [%{"name" => "t", "type" => %{"kind" => "string"}}]}
      assert {:ok, out} = EmbeddedSchema.render(d, resources: res)
      assert out == "z.object({ t: z.string() }).strict()"
      assert {:ok, ^out} = EmbeddedSchema.render(d, resources: res, schema_suffix: "Z")
    end

    test "scalar with omittable and default emits exactly one .optional()" do
      for extra <- [
            %{"omittable" => true, "default" => 1},
            %{"omittable" => true, "optional" => true},
            %{"omittable" => true, "required?" => false},
            %{"default" => 1, "optional" => true},
            %{"omittable" => true}
          ] do
        d = Map.merge(%{"type" => %{"kind" => "integer"}}, extra)
        assert {:ok, zod} = EmbeddedSchema.render(d)
        assert length(String.split(zod, ".optional()")) == 2, zod
        admit!(zod)
      end
    end

    test "container with default/optional keys gets one .optional()" do
      d =
        Map.merge(tdef("typed_map", %{"fields" => [f("a", "string")]}), %{
          "optional" => true,
          "omittable" => true
        })

      assert {:ok, zod} = EmbeddedSchema.render(d)
      assert String.ends_with?(zod, ".strict().optional()")
      refute zod =~ ".optional().optional()"
    end

    test "array of embedded renders z.array(container)" do
      resources = %{"E.Inner" => [f("x", "string")]}

      d = %{
        "allow_nil?" => true,
        "type" => %{
          "kind" => "array",
          "items" => %{"type" => %{"kind" => "embedded_resource", "resource" => "E.Inner"}}
        }
      }

      assert {:ok, zod} = EmbeddedSchema.render(d, resources: resources)
      assert zod =~ ~r/\Az\.array\(z\.object\(\{ x: .+ \}\)\.strict\(\)\)\.nullable\(\)\z/
      assert EmbeddedSchema.container?(d)
      admit!(zod)

      bare =
        put_in(d, ["type", "items"], %{"kind" => "typed_map", "fields" => [f("y", "boolean")]})

      assert {:ok, z2} = EmbeddedSchema.render(bare)
      assert z2 =~ "z.array(z.object({ y: "
      admit!(z2)

      nested = %{"type" => %{"kind" => "array", "items" => d["type"] |> then(&%{"type" => &1})}}
      assert {:ok, z3} = EmbeddedSchema.render(nested, resources: resources)
      assert z3 =~ "z.array(z.array(z.object({ x: "
      admit!(z3)
    end

    test "array of scalars is not a container here" do
      refute EmbeddedSchema.container?(%{
               "type" => %{"kind" => "array", "items" => %{"kind" => "string"}}
             })
    end

    test "map-form fields are sorted by name, list-form keeps declared order" do
      m =
        tdef("typed_map", %{
          "fields" => %{
            "b" => %{"type" => %{"kind" => "string"}},
            "a" => %{"type" => %{"kind" => "string"}}
          }
        })

      assert {:ok, zod} = EmbeddedSchema.render(m)
      assert zod =~ ~r/\{ a: .+, b: .+ \}/

      l = tdef("typed_map", %{"fields" => [f("b", "string"), f("a", "string")]})
      assert {:ok, zl} = EmbeddedSchema.render(l)
      assert zl =~ ~r/\{ b: .+, a: .+ \}/
      admit!(zod)
      admit!(zl)
    end

    test "registry field with constraints chain renders and is admitted" do
      resources = %{
        "E.C" => [
          %{
            "name" => "code",
            "type" => %{"kind" => "string"},
            "constraints" => %{"min_length" => 2, "max_length" => 5}
          },
          f("n", "integer", %{"constraints" => %{"min" => 0, "max" => 9}})
        ]
      }

      assert {:ok, zod} =
               EmbeddedSchema.render(tdef("embedded_resource", %{"resource" => "E.C"}),
                 resources: resources
               )

      assert zod =~ ".min(2)"
      assert zod =~ ".max(5)"
      admit!(zod)
    end

    test "cycle error path and cycle_depth bounds expansion" do
      ref = fn n ->
        f("r", "embedded_resource", %{"type" => %{"kind" => "embedded_resource", "resource" => n}})
      end

      res = %{"A" => [ref.("A")]}
      d = tdef("embedded_resource", %{"resource" => "A"})
      assert {:error, {:cyclic_schema, ["A", "A"]}} = EmbeddedSchema.render(d, resources: res)

      sizes =
        for n <- 0..3 do
          {:ok, z} = EmbeddedSchema.render(d, resources: res, cycle_depth: n)
          admit!(z)
          refute z =~ "lazy"
          String.length(z)
        end

      assert sizes == Enum.sort(sizes)
      assert length(Enum.uniq(sizes)) == 4
    end

    test "union delegates to UnionSchema.render_members/2" do
      d =
        tdef("union", %{
          "members" => [
            %{"name" => "text", "type" => %{"kind" => "string"}},
            %{"name" => "num", "type" => %{"kind" => "integer"}}
          ]
        })

      assert {:ok, zod} = EmbeddedSchema.render(d)
      assert zod =~ "z.union("
      assert zod =~ "text:"
      assert zod =~ "num:"
      assert {:ok, :expression, _} = AshSurface.Projectors.JS.ZodGuard.admit(zod)
      assert EmbeddedSchema.container?(d)
    end

    test "rendering is deterministic across repeated calls" do
      d = tdef("typed_struct", %{"fields" => [f("a", "string"), f("b", "integer")]})
      outs = for _ <- 1..5, do: EmbeddedSchema.render(d)
      assert length(Enum.uniq(outs)) == 1
    end

    test "emitted object schema executes under node with real zod" do
      resources = %{
        "E.Addr" => [
          f("street", "string", %{"constraints" => %{"min_length" => 1}}),
          f("zip", "string", %{"omittable" => true, "default" => "00000"})
        ]
      }

      d = %{
        "type" => %{
          "kind" => "typed_struct",
          "fields" => [
            f("title", "string"),
            f("addr", "embedded_resource", %{
              "type" => %{"kind" => "embedded_resource", "resource" => "E.Addr"}
            }),
            f("addrs", "array", %{
              "type" => %{
                "kind" => "array",
                "items" => %{"type" => %{"kind" => "embedded_resource", "resource" => "E.Addr"}}
              }
            })
          ]
        }
      }

      assert {:ok, zod} = EmbeddedSchema.render(d, resources: resources)
      admit!(zod)

      dir = Path.join(System.tmp_dir!(), "em_zod_#{AshSurface.TestTmp.suffix()}")
      File.mkdir_p!(dir)
      on_exit(fn -> File.rm_rf!(dir) end)
      Harness.zod!()
      File.ln_s!(Path.join(Harness.repo_root(), "node_modules"), Path.join(dir, "node_modules"))

      File.write!(Path.join(dir, "run.mjs"), """
      import { z } from "zod";
      const S = #{zod};
      const ok = { title: "t", addr: { street: "s" }, addrs: [{ street: "a", zip: "12345" }] };
      const out = {
        good: S.safeParse(ok).success,
        extraKey: S.safeParse({ ...ok, extra: 1 }).success,
        badNested: S.safeParse({ ...ok, addr: { street: "" } }).success,
        badArray: S.safeParse({ ...ok, addrs: [{}] }).success,
        missing: S.safeParse({ title: "t" }).success
      };
      console.log(JSON.stringify(out));
      """)

      {output, status} = Harness.run(Harness.tool!("node"), ["run.mjs"], dir)
      assert status == 0, output
      result = output |> String.trim() |> String.split("\n") |> List.last() |> Jason.decode!()

      assert result == %{
               "good" => true,
               "extraKey" => false,
               "badNested" => false,
               "badArray" => false,
               "missing" => false
             }
    end
  end
end
