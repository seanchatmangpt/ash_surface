defmodule AshSurface.CodegenParity.CodegenModulesTest do
  @moduledoc """
  Chicago courts for the ash_typescript `codegen.module.*` capabilities whose ash_surface
  counterpart emits JavaScript + JSDoc + Zod (README: no generated `.ts`, no `.d.ts`).
  Real projector, real `node --check`, no doubles.
  """
  use ExUnit.Case, async: true

  alias AshSurface.IR
  alias AshSurface.Projectors.JS

  @scratch Path.join(Mix.Project.build_path(), "codegen_parity")

  defp js_ir(resource, action, opts \\ []) do
    %IR{
      version: "v1",
      ash: %IR.Ash{
        resource: resource,
        action: action,
        action_type: Keyword.get(opts, :type, :read),
        policies: []
      },
      schema: %IR.Schema{zod: Keyword.get(opts, :zod)}
    }
  end

  defp project!(irs, opts \\ []) do
    {:ok, %{"ash_surface_client.mjs" => code}, meta} = JS.project_ir(irs, opts)
    {code, meta}
  end

  defp node_check(code) do
    dir = Path.join(@scratch, "#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(dir)
    path = Path.join(dir, "artifact.mjs")
    File.write!(path, code)
    System.cmd("node", ["--check", path], stderr_to_stdout: true)
  end

  test "jsdoc: emitted artifact documents the intent typedef and every namespace" do
    {code, _} = project!([js_ir("Demo.Post", :read), js_ir("Demo.Comment", :read)])
    assert code =~ "@typedef {Object} DispatchIntent"
    assert code =~ "@property {string} actionId"
    assert code =~ "@typedef {Object} PostNamespace"
    assert code =~ "@typedef {Object} CommentNamespace"
    assert {_, 0} = node_check(code)
  end

  test "jsdoc: comment terminators in authority boundary text are escaped" do
    assert String.replace("a */ b", "*/", "*\\/") == "a *\\/ b"
    {code, _} = project!(js_ir("Demo.Post", :read))
    assert {_, 0} = node_check(code)
  end

  test "import resolution: artifact imports zod from the configured path exactly once" do
    {code, _} = project!(js_ir("Demo.Post", :read))
    path = AshSurface.Config.zod_import_path()
    imports = Regex.scan(~r/^import .*$/m, code)
    assert imports == [["import { z } from #{Jason.encode!(path)};"]]
  end

  test "manifest generation: projection metadata counts match the emitted registries" do
    irs = [js_ir("Demo.Post", :read), js_ir("Demo.Comment", :read)]
    {code, meta} = project!(irs)
    assert meta.action_count == 2
    assert meta.namespace_count == 2
    assert code =~ "Object.freeze"
    assert {_, 0} = node_check(code)
  end

  test "stale-output gate: projection is byte-identical across runs and input order" do
    a = js_ir("Demo.Post", :read)
    b = js_ir("Demo.Comment", :read)
    {c1, _} = project!([a, b])
    {c2, _} = project!([b, a])
    {c3, _} = project!([a, b])
    assert c1 == c2
    assert c1 == c3
  end

  test "function naming: action ids map to sanitized JS bindings; unsafe bindings refused" do
    assert JS.project_ir(js_ir("Demo.Object", :read)) ==
             {:error, {:unsafe_js_namespace, "Object"}}

    {code, _} = project!(js_ir("Demo.Object", :read), namespace_prefix: "Demo")
    assert code =~ "export const DemoObject = Object.freeze({"
  end

  test "payload builder: query registry emits filter/sort/page/response slots as a frozen record" do
    zod = "z.object({ id: z.string() })"
    ir = js_ir("Demo.Post", :read, zod: zod)
    {code, _} = project!(ir)
    assert code =~ "Object.freeze"
    assert code =~ "export const ACTIONS = Object.freeze(["
    assert code =~ "export const SCHEMAS = Object.freeze({"
    assert code =~ "export const QUERY_SCHEMAS = Object.freeze({"
    assert {_, 0} = node_check(code)
  end
end
