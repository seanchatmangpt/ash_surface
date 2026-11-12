defmodule AshSurface.Compiler.S1GSchemaCourtsTest do
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.{EmbeddedSchema, UnionSchema, ValidationErrorSchema}
  alias AshSurface.Projectors.JS.ZodGuard

  # Executes `expr` under real zod in node; returns [bool] per payload, or {:throws, msg}.
  defp zod(expr, payloads) do
    root = File.cwd!()
    node = System.find_executable("node") || raise "REQUIRED TOOL MISSING: node"

    dir =
      Path.join(
        System.tmp_dir!(),
        "s1g_#{System.unique_integer([:positive])}_#{System.pid()}_#{Base.url_encode64(:crypto.strong_rand_bytes(6), padding: false)}"
      )

    File.mkdir_p!(dir)
    File.ln_s!(Path.join(root, "node_modules"), Path.join(dir, "node_modules"))

    File.write!(Path.join(dir, "run.mjs"), """
    import { z } from "zod";
    let out;
    try {
      const S = #{expr};
      const ps = #{Jason.encode!(payloads)};
      out = ps.map((p) => S.safeParse(p).success);
    } catch (e) { out = {throws: String(e)}; }
    process.stdout.write(JSON.stringify(out));
    """)

    {out, 0} = System.cmd(node, ["run.mjs"], cd: dir, stderr_to_stdout: true)
    File.rm_rf!(dir)
    Jason.decode!(out)
  end

  defp admitted(expr), do: assert({:ok, :expression, ^expr} = ZodGuard.admit(expr))

  describe "union (M7)" do
    test "embedded member with resource key expands via opts[:resources]" do
      members = [
        %{
          "name" => "e",
          "type" => %{"type" => %{"kind" => "embedded_resource", "resource" => "My.Emb"}}
        }
      ]

      res = %{"My.Emb" => [%{"name" => "zip", "type" => %{"kind" => "string"}}]}
      assert {:ok, expr} = UnionSchema.render_members_admitted(members, resources: res)
      admitted(expr)

      assert zod(expr, [%{"e" => %{"zip" => "1"}}, %{"e" => %{"zip" => 1}}, %{"e" => %{}}]) ==
               [true, false, false]
    end

    test "enum member keeps values" do
      members = [
        %{"name" => "c", "type" => %{"type" => %{"kind" => "enum", "values" => ["a", "b"]}}}
      ]

      {:ok, expr} = UnionSchema.render_members_admitted(members)
      admitted(expr)
      assert zod(expr, [%{"c" => "a"}, %{"c" => "zzz"}]) == [true, false]
    end

    test "no double nullable on containers" do
      members = [
        %{
          "name" => "m",
          "type" => %{
            "allow_nil?" => true,
            "type" => %{
              "kind" => "typed_map",
              "fields" => [%{"name" => "a", "type" => %{"kind" => "string"}}]
            }
          }
        }
      ]

      {:ok, expr} = UnionSchema.render_members_admitted(members)
      refute expr =~ ".nullable().nullable()"
      assert zod(expr, [%{"m" => nil}, %{"m" => %{"a" => "x"}}]) == [true, true]
    end

    test "duplicate tags are a typed error (would throw under zod)" do
      facts = [%{tag: "a", kind: :string}, %{tag: "a", kind: :integer}]
      assert {:error, {:duplicate_tag, "a"}} = UnionSchema.render_union_schema(facts)

      ok = [%{tag: "a", kind: :string}, %{tag: "b", kind: :integer}]
      {:ok, expr} = UnionSchema.render_union_schema_admitted(ok)

      assert zod(expr, [%{"type" => "a", "value" => "s"}, %{"type" => "b", "value" => "s"}]) == [
               true,
               false
             ]
    end

    test "member name equal to tag or discriminator is refused" do
      m = [%{"name" => "kind", "type" => "string", "tag" => "kind", "tag_value" => "K"}]
      assert {:error, {:duplicate_member_key, "kind", _, 0}} = UnionSchema.render_members(m)
    end
  end

  describe "embedded (M8/L2)" do
    test "resource references inline, are guard-admitted and validate under node+zod (F1)" do
      user = %{"name" => "name", "type" => %{"kind" => "string"}}
      post = %{"name" => "author", "type" => %{"kind" => "resource", "instance_of" => "My.User"}}

      d = %{
        "type" => %{
          "kind" => "typed_map",
          "fields" => [
            %{"name" => "post", "type" => %{"kind" => "resource", "instance_of" => "My.Post"}},
            %{
              "name" => "all",
              "type" => %{
                "kind" => "array",
                "items" => %{"type" => %{"kind" => "resource", "instance_of" => "My.User"}}
              }
            }
          ]
        }
      }

      res = %{"My.User" => [user], "My.Post" => [post]}
      assert {:ok, out} = EmbeddedSchema.render(d, resources: res)
      refute out =~ "ZodSchema"
      admitted(out)

      assert [true, false, false] ==
               zod(out, [
                 %{post: %{author: %{name: "a"}}, all: [%{name: "b"}]},
                 %{post: %{author: %{name: 1}}, all: []},
                 %{post: %{author: %{name: "a", x: 1}}, all: []}
               ])
    end

    test "self-referencing resource: typed cycle error, then bounded by cycle_depth" do
      node = %{"name" => "next", "type" => %{"kind" => "resource", "instance_of" => "My.Node"}}
      res = %{"My.Node" => [node]}
      d = %{"type" => %{"kind" => "resource", "instance_of" => "My.Node"}}
      assert {:error, {:cyclic_schema, _}} = EmbeddedSchema.render(d, resources: res)
      assert {:ok, out} = EmbeddedSchema.render(d, resources: res, cycle_depth: 1)
      admitted(out)

      assert {:error, {:schema_too_large, _, 10}} =
               EmbeddedSchema.render(d, resources: res, cycle_depth: 3, max_bytes: 10)
    end

    test "__proto__ field is a typed refusal, other dunder-free names still admitted (S2-01)" do
      bad = %{
        "type" => %{
          "kind" => "typed_map",
          "fields" => [%{"name" => "__proto__", "type" => %{"kind" => "string"}}]
        }
      }

      assert {:error, {:denied_field_name, "__proto__"}} = EmbeddedSchema.render(bad)

      assert {:error, {:denied_field_name, "__proto__"}} =
               ValidationErrorSchema.render(bad, formatter: :snake_case)

      ok = %{
        "type" => %{
          "kind" => "typed_map",
          "fields" => [%{"name" => "proto", "type" => %{"kind" => "string"}}]
        }
      }

      assert {:ok, out} = EmbeddedSchema.render(ok)
      admitted(out)
      assert [true, false] == zod(out, [%{proto: "x"}, %{__proto__: 1}])
    end

    test "map_error_type returns the typed too-large error, never raises (F1)" do
      alias AshSurface.Compiler.ValidationErrorSchema, as: V
      f = %{"name" => "a", "type" => %{"kind" => "string"}}
      d = %{"type" => %{"kind" => "embedded_resource", "fields" => [f]}}
      assert {:error, {:schema_too_large, _, 5}} = V.map_error_type(d, max_bytes: 5)
      assert {:error, {:schema_too_large, _, 5}} = V.render(d, max_bytes: 5)
      assert {:ok, _} = V.map_error_type(d)
    end

    test "atom-keyed fields use their names; map form too" do
      d = %{
        "type" => %{"kind" => "typed_map", "fields" => [%{name: "a", type: %{kind: "string"}}]}
      }

      assert {:ok, expr} = EmbeddedSchema.render(d)
      assert expr =~ "a:"
      admitted(expr)

      d2 = %{
        "type" => %{"kind" => "typed_map", "fields" => %{a: %{"type" => %{"kind" => "string"}}}}
      }

      assert {:ok, expr2} = EmbeddedSchema.render(d2)
      assert expr2 =~ "a:"
    end

    test "non-map field is a typed error" do
      d = %{"type" => %{"kind" => "typed_map", "fields" => ["oops"]}}
      assert {:error, {:invalid_field, "oops"}} = EmbeddedSchema.render(d)
      d2 = %{"type" => %{"kind" => "typed_map", "fields" => %{"x" => 5}}}
      assert {:error, {:invalid_field, 5}} = EmbeddedSchema.render(d2)
    end

    test "struct with non-resource instance_of is strict" do
      d = %{"type" => %{"kind" => "struct", "instance_of" => "Elixir.Date"}}
      assert {:ok, expr} = EmbeddedSchema.render(d, non_resources: ["Elixir.Date"])
      assert expr == "z.object({}).strict()"
      assert zod(expr, [%{}, %{"x" => 1}]) == [true, false]
    end

    test "cycle_depth blowup hits the byte cap" do
      fields =
        for i <- 1..4,
            do: %{
              "name" => "r#{i}",
              "type" => %{"kind" => "embedded_resource", "resource" => "N"}
            }

      d = %{"type" => %{"kind" => "embedded_resource", "resource" => "N"}}

      assert {:error, {:schema_too_large, bytes, 5_000}} =
               EmbeddedSchema.render(d,
                 resources: %{"N" => fields},
                 cycle_depth: 10,
                 max_bytes: 5_000
               )

      assert bytes > 5_000
    end
  end

  describe "validation errors (M8/L2)" do
    test "resource reference is inlined and guard-admitted, executes under zod" do
      res = %{"My.User" => [%{"name" => "email", "type" => %{"kind" => "string"}}]}
      d = %{"type" => %{"kind" => "resource", "instance_of" => "My.User"}}
      assert {:ok, expr} = ValidationErrorSchema.render(d, resources: res)
      admitted(expr)

      assert zod(expr, [%{"email" => ["bad"]}, %{"email" => "bad"}, %{"nope" => []}]) == [
               true,
               false,
               false
             ]
    end

    test "unresolvable reference degrades to record, still admitted" do
      d = %{"type" => %{"kind" => "resource", "instance_of" => "My.Ghost"}}
      assert {:ok, expr} = ValidationErrorSchema.render(d)
      admitted(expr)
    end

    test "atom-keyed field maps keep names" do
      d = %{
        "type" => %{"kind" => "typed_map", "fields" => [%{name: "zip", type: %{kind: "string"}}]}
      }

      assert {:ok, expr} = ValidationErrorSchema.render(d)
      assert expr =~ "zip:"
    end

    test "DAG expansion over the cap is a typed error" do
      fields =
        for i <- 1..4,
            do: %{
              "name" => "r#{i}",
              "type" => %{"kind" => "embedded_resource", "resource" => "N"}
            }

      d = %{"type" => %{"kind" => "embedded_resource", "resource" => "N"}}

      assert {:error, {:schema_too_large, _, 5_000}} =
               ValidationErrorSchema.render(d,
                 resources: %{"N" => fields},
                 cycle_depth: 10,
                 max_bytes: 5_000
               )
    end

    test "dunder field names are quoted like union keys" do
      d = %{
        "type" => %{
          "kind" => "typed_map",
          "fields" => [%{"name" => "__x", "type" => %{"kind" => "string"}}]
        }
      }

      assert {:ok, expr} = ValidationErrorSchema.render(d, formatter: :snake_case)
      assert expr =~ ~s("__x":)
    end
  end
end
