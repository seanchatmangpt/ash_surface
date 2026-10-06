defmodule AshSurface.JSNamespacePrefixTest do
  @moduledoc """
  Chicago state courts for the JS projector's opt-in `:namespace_prefix`.

  Laws pinned here:

    * **Default behavior is unchanged.** Without `:namespace_prefix`, a
      resource short name colliding with a JavaScript built-in
      (`Xaas.Ocel.Object` → `Object`) is still refused typed as
      `{:unsafe_js_namespace, "Object"}` — no artifact.
    * **A prefix lifts the refusal by renaming the binding, not by weakening
      admission.** With `namespace_prefix: "Xaas"`, the same IR projects and
      the namespace binding is `XaasObject`; the descriptor `resource` data
      field stays the original short name; all registries reference the
      prefixed binding.
    * **Prefixed output is real JavaScript.** The artifact passes
      `node --check` (real Node subprocess, no doubles).
    * **Admission still fires under a prefix.** Unsafe members, duplicate
      ids, and namespace collisions (prefixed names collide too) are still
      refused; an invalid `:namespace_prefix` value is refused typed.
  """

  use ExUnit.Case, async: true

  alias AshSurface.IR
  alias AshSurface.Projectors.JS

  @scratch Path.join(Mix.Project.build_path(), "js_namespace_prefix")

  describe "default (no :namespace_prefix)" do
    test "Xaas.Ocel.Object is still refused as a built-in collision" do
      assert JS.project_ir(js_ir("Xaas.Ocel.Object", :read)) ==
               {:error, {:unsafe_js_namespace, "Object"}}
    end

    test "refusal holds for the full-app shape (multiple resources, one colliding)" do
      irs = [
        js_ir("Xaas.Ocel.Object", :read),
        js_ir("Xaas.Todo.Todo", :create)
      ]

      assert JS.project_ir(irs) == {:error, {:unsafe_js_namespace, "Object"}}
    end
  end

  describe "namespace_prefix: opt-in prefixing" do
    test "the same colliding IR projects with the prefixed binding" do
      assert {:ok, %{"ash_surface_client.mjs" => code}, meta} =
               JS.project_ir(js_ir("Xaas.Ocel.Object", :read), namespace_prefix: "Xaas")

      assert code =~ "export const XaasObject = Object.freeze({"
      assert code =~ "@typedef {Object} XaasObjectNamespace"
      assert meta.namespace_count == 1
      # Descriptor data keeps the real (unprefixed) resource name.
      assert code =~ ~s(resource: "Object")
    end

    test "multiple resources all get the prefix; registries reference the bindings" do
      irs = [
        js_ir("Xaas.Ocel.Object", :read),
        js_ir("Xaas.Todo.Todo", :create, zod: "z.object({})"),
        js_ir("Xaas.Cart.Line", :update)
      ]

      assert {:ok, %{"ash_surface_client.mjs" => code}, meta} =
               JS.project_ir(irs, namespace_prefix: "Xaas")

      for binding <- ~w(XaasObject XaasTodo XaasLine) do
        assert code =~ "export const #{binding} = Object.freeze({"
      end

      assert code =~ "NAMESPACES = Object.freeze({\n  XaasLine,\n  XaasObject,\n  XaasTodo\n});"
      assert code =~ "XaasObject.read"
      assert code =~ "XaasTodo.create"
      # Schema consts are keyed by action id and stay unprefixed (id-keyed
      # collisions are still caught by check_bindings).
      assert code =~ "Todo_create_schema"
      assert meta.namespace_count == 3
      assert meta.action_count == 3
    end

    test "prefixed artifact is node-parseable" do
      {:ok, %{"ash_surface_client.mjs" => code}, _} =
        JS.project_ir([js_ir("Xaas.Ocel.Object", :read), js_ir("Xaas.Todo.Todo", :create)],
          namespace_prefix: "Xaas"
        )

      assert {_, 0} = code |> then(&write_artifact!("prefixed.mjs", &1)) |> node_check()
    end
  end

  describe "admission still fires under a prefix" do
    test "two resources sharing a short name still collide (prefixed)" do
      irs = [js_ir("MyApp.Blog.Post", :create), js_ir("MyApp.Forum.Post", :create)]

      assert JS.project_ir(irs, namespace_prefix: "Xaas") ==
               {:error,
                {:js_namespace_collision, "XaasPost", ["MyApp.Blog.Post", "MyApp.Forum.Post"]}}
    end

    test "prefixed names that are themselves unsafe are refused" do
      # prefix ending in a non-identifier byte makes every binding unsafe
      assert JS.project_ir(js_ir("MyApp.Post", :read), namespace_prefix: "my-thing") ==
               {:error, {:unsafe_js_namespace, "my-thingPost"}}
    end

    test "unsafe members and duplicate ids are still refused with a prefix" do
      assert JS.project_ir(js_ir("Shop.Cart", "add-item"), namespace_prefix: "Xaas") ==
               {:error, {:unsafe_js_member, "Cart.add-item"}}

      # Duplicate ids are refused under the post-disambiguation id (the
      # artifact-facing id follows the resolved namespace binding).
      assert JS.project_ir([js_ir("Shop.Cart", :read), js_ir("Shop.Cart", :read)],
               namespace_prefix: "Xaas"
             ) == {:error, {:duplicate_js_member, "XaasCart.read"}}
    end

    test "an invalid :namespace_prefix value is refused typed" do
      assert JS.project_ir(js_ir("MyApp.Post", :read), namespace_prefix: "") ==
               {:error, {:invalid_namespace_prefix, ""}}

      assert JS.project_ir(js_ir("MyApp.Post", :read), namespace_prefix: 7) ==
               {:error, {:invalid_namespace_prefix, 7}}
    end
  end

  defp js_ir(resource, action, opts \\ []) do
    %IR{
      version: "v1",
      ash: %IR.Ash{
        resource: resource,
        action: action,
        action_type: :read,
        policies: Keyword.get(opts, :policies, [])
      },
      schema: %IR.Schema{zod: Keyword.get(opts, :zod)}
    }
  end

  defp write_artifact!(name, code) do
    dir = Path.join(@scratch, "#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    path = Path.join(dir, name)
    File.write!(path, code)
    path
  end

  defp node_check(path), do: System.cmd("node", ["--check", path], stderr_to_stdout: true)
end
