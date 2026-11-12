defmodule AshSurface.Dsl.RoutePresentationParityTest do
  @moduledoc """
  Parity courts for ash_typescript typed_controller route presentation options
  (deprecated, description, see, namespace, zod_schema_name). Descriptors carry the
  fields; the Zod response fragment and declaration are executed under node + zod.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.RouteSchema
  alias AshSurface.ZodFixtures.Harness

  defp route(extra),
    do:
      Map.merge(
        %{
          "name" => "show",
          "method" => "get",
          "path" => "/a",
          "arguments" => [],
          "returns" => %{"type" => %{"kind" => "string"}}
        },
        extra
      )

  defp build1(extra) do
    {:ok, [r]} = RouteSchema.build([route(extra)])
    r
  end

  defp node_run(body) do
    dir = Path.join(System.tmp_dir!(), "rc_presentation_#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(dir)
    File.ln_s!(Path.join(Harness.repo_root(), "node_modules"), Path.join(dir, "node_modules"))
    Harness.zod!()
    File.write!(Path.join(dir, "run.mjs"), ~s(import { z } from "zod";\n) <> body)
    {out, 0} = Harness.run(Harness.tool!("node"), ["run.mjs"], dir)
    File.rm_rf!(dir)
    Jason.decode!(out)
  end

  test "typed_controller route option description: applied as zod describe, executed" do
    r = build1(%{"description" => "Shows \"it\""})
    assert r["description"] == "Shows \"it\""
    assert r["response"] =~ ".describe("

    assert %{"desc" => "Shows \"it\"", "ok" => true, "bad" => false} =
             node_run("""
             const s = #{r["response"]};
             process.stdout.write(JSON.stringify({desc: s.description,
               ok: s.safeParse("x").success, bad: s.safeParse(1).success}));
             """)
  end

  test "typed_controller route option deprecated: jsdoc carries @deprecated" do
    assert build1(%{"deprecated" => true})["jsdoc"] =~ "@deprecated"
    r = build1(%{"deprecated" => "use /b"})
    assert r["deprecated"] == "use /b"
    assert r["jsdoc"] =~ "@deprecated use /b"
    refute Map.has_key?(build1(%{"deprecated" => false}), "deprecated")
    refute Map.has_key?(build1(%{}), "jsdoc")
  end

  test "typed_controller route option see: jsdoc carries @see" do
    r = build1(%{"see" => "https://x.test/doc", "description" => "d*/e"})
    assert r["see"] == "https://x.test/doc"
    assert r["jsdoc"] =~ "@see https://x.test/doc"
    refute r["jsdoc"] =~ "d*/e"
  end

  test "typed_controller route option namespace: carried as presentation grouping" do
    assert build1(%{"namespace" => "billing"})["namespace"] == "billing"
    refute Map.has_key?(build1(%{}), "namespace")
  end

  test "typed_controller route option zod_schema_name: names the executed response const" do
    r = build1(%{"zod_schema_name" => "ShowResponse"})
    assert r["schema_declaration"] =~ ~r/^export const ShowResponse = /

    decl = String.replace_prefix(r["schema_declaration"], "export ", "")

    assert %{"ok" => true, "bad" => false} =
             node_run("""
             #{decl}
             process.stdout.write(JSON.stringify({ok: ShowResponse.safeParse("x").success,
               bad: ShowResponse.safeParse(1).success}));
             """)

    refute Map.has_key?(build1(%{}), "schema_declaration")
  end

  test "typed_controller route option valibot_schema_name: carried, identifier-checked" do
    assert build1(%{"valibot_schema_name" => "ShowValibot"})["valibot_schema_name"] ==
             "ShowValibot"

    refute Map.has_key?(build1(%{}), "valibot_schema_name")

    for bad <- ["1bad", "a b", "x;y", "a-b", 7] do
      assert {:error, {:invalid_valibot_schema_name, "show", ^bad}} =
               RouteSchema.build([route(%{"valibot_schema_name" => bad})])
    end
  end

  test "typed_controller section option namespace: default for routes, route namespace wins" do
    {:ok, [a, b]} =
      RouteSchema.build(
        [
          route(%{"name" => "a", "path" => "/a"}),
          route(%{"name" => "b", "path" => "/b", "namespace" => "own"})
        ],
        namespace: "billing"
      )

    assert a["namespace"] == "billing"
    assert b["namespace"] == "own"

    {:ok, [c]} = RouteSchema.build([route(%{})])
    refute Map.has_key?(c, "namespace")

    assert [
             %{"namespace" => "billing", "routes" => ["a"]},
             %{"namespace" => "own", "routes" => ["b"]}
           ] =
             RouteSchema.namespace_plan([a, b], enabled: true, output_dir: "out")
             |> Enum.sort_by(& &1["namespace"])
  end
end
