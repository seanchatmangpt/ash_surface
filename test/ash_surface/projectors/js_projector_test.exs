defmodule AshSurface.Projectors.JsProjectorTest do
  @moduledoc """
  Tests for `AshSurface.Projectors.JS.project_ir/2`: ONE JSDoc + Zod `.mjs`
  artifact (default prefix `ash_surface_client`), byte-deterministic, with
  DO-boundary actions projecting dispatch-intent descriptors only.

  `setup_all/1` also materializes the cross-language bridge consumed by
  `test/js/ir_projection.test.mjs`: the emitted artifact plus a `fixture.json`
  sidecar carrying the exact normalized fixture truth, both under
  `tmp/js_projector/`.
  """

  use ExUnit.Case, async: true

  alias AshSurface.IR
  alias AshSurface.Projector.IR, as: IREntry
  alias AshSurface.Projectors.JS

  @bridge_dir "tmp/js_projector"
  @default_artifact "ash_surface_client.mjs"

  @create_zod "z.object({\n  title: z.string().min(1),\n  due_on: z.string().optional()\n})"
  @list_zod "z.object({\n  status: z.enum([\"open\", \"done\"]).optional()\n})"

  # ---------------------------------------------------------------------------
  # Fixture IR: four admitted entries across two resources — a DO-boundary
  # write with a delegated Zod schema, an OBSERVE read with a schema, a
  # CONSTRUCT with atom-keyed delegated facts, and an entry whose boundary no
  # source delegated (nil, never inferred).
  # ---------------------------------------------------------------------------

  defp todo_create_ir do
    IR.new(
      ash: %IR.Ash{
        resource: "Todo",
        action: :create,
        action_type: :create,
        policies: [%{"authorityBoundary" => "DO"}]
      },
      semantic: %IR.Semantic{capability_iri: "cap:todo.write"},
      capability: %IR.Capability{
        capability_id: "todo.write",
        consequence_class: "IRREVERSIBLE",
        authority_required: true,
        receipt_required: true
      },
      presentation: %IR.Presentation{label: "Create todo", group: "writing"},
      schema: %IR.Schema{zod: @create_zod}
    )
  end

  defp todo_list_ir do
    IR.new(
      ash: %IR.Ash{
        resource: "Todo",
        action: :list,
        action_type: :read,
        policies: [%{"authorityBoundary" => "OBSERVE"}]
      },
      capability: %IR.Capability{capability_id: "todo.read", receipt_required: false},
      schema: %IR.Schema{zod: @list_zod}
    )
  end

  defp member_profile_ir do
    IR.new(
      ash: %IR.Ash{
        resource: "Member",
        action: :profile,
        action_type: :read,
        policies: [%{:authorityBoundary => "CONSTRUCT"}]
      },
      presentation: %IR.Presentation{label: "Member profile"}
    )
  end

  defp member_deactivate_ir do
    IR.new(
      ash: %IR.Ash{
        resource: "Member",
        action: :deactivate,
        action_type: :destroy,
        policies: []
      }
    )
  end

  defp fixture_irs do
    [todo_create_ir(), todo_list_ir(), member_profile_ir(), member_deactivate_ir()]
  end

  defp sidecar_actions do
    IREntry.entries(fixture_irs())
    |> Enum.map(fn entry ->
      %{
        id: entry.id,
        resource: entry.resource,
        action: entry.action,
        actionType: entry.action_type,
        authorityBoundary: entry.authority_boundary,
        receiptRequired: entry.receipt_required,
        descriptorKind: (IREntry.do_boundary?(entry) && "DISPATCH_INTENT") || "DESCRIPTOR",
        capabilityIri: entry.capability_iri,
        label: entry.label,
        zod: entry.zod,
        validInput: sample(entry.id, :valid),
        invalidInput: sample(entry.id, :invalid)
      }
    end)
  end

  defp sample("Todo.create", :valid),
    do: %{"title" => "ship the projection", "due_on" => "2026-09-16"}

  defp sample("Todo.create", :invalid), do: %{"title" => ""}
  defp sample("Todo.list", :valid), do: %{}
  defp sample("Todo.list", :invalid), do: %{"status" => "bogus"}
  defp sample(_, _), do: nil

  setup_all do
    bridge_dir = Path.join(File.cwd!(), @bridge_dir)
    {:ok, artifacts, meta} = JS.project_ir(fixture_irs(), target_dir: bridge_dir)
    code = Map.fetch!(artifacts, @default_artifact)

    File.write!(
      Path.join(bridge_dir, "fixture.json"),
      Jason.encode!(%{prefix: "ash_surface_client", actions: sidecar_actions()})
    )

    %{bridge_code: code, bridge_artifacts: artifacts, bridge_meta: meta}
  end

  describe "project_ir/2 artifact shape" do
    test "emits exactly one artifact under the default prefix", %{bridge_artifacts: artifacts} do
      assert Map.keys(artifacts) == [@default_artifact]
    end

    test "default artifact carries the expected projection facts", %{bridge_meta: meta} do
      assert meta.prefix == "ash_surface_client"
      assert meta.action_count == 4
      assert meta.namespace_count == 2
    end

    test "custom prefix names the single artifact" do
      assert {:ok, artifacts, %{prefix: "acme_client"}} =
               JS.project_ir(fixture_irs(), prefix: "acme_client")

      assert Map.keys(artifacts) == ["acme_client.mjs"]
    end
  end

  describe "JSDoc + Zod content" do
    test "embeds IR.Schema.zod strings verbatim as exported schemas", %{bridge_code: code} do
      assert code =~ "export const Todo_create_schema = #{@create_zod};"
      assert code =~ "export const Todo_list_schema = #{@list_zod};"
      assert code =~ ~s|SCHEMAS = Object.freeze({\n  "Todo.create": Todo_create_schema,|
    end

    test "exports JSDoc-typed namespaces per resource", %{bridge_code: code} do
      assert code =~ "@typedef {Object} TodoNamespace"
      assert code =~ "@typedef {Object} MemberNamespace"
      assert code =~ "export const Todo = Object.freeze({"
      assert code =~ "export const NAMESPACES = Object.freeze({\n  Member,\n  Todo\n});"
    end
  end

  describe "DO boundary law" do
    test "exactly one dispatch-intent descriptor, and it is the DO action", %{bridge_code: code} do
      assert code =~
               ~s|id: "Todo.create",\n    resource: "Todo",\n    action: "create",\n    actionType: "create",\n    authorityBoundary: "DO",\n    receiptRequired: true,\n    descriptorKind: "DISPATCH_INTENT",|

      assert count(code, ~r/\n    descriptorKind: "DISPATCH_INTENT",/) == 1
    end

    test "dispatch intents are minted by a refusing, non-executing factory", %{bridge_code: code} do
      assert code =~ ~s|throw new Error("REFUSED_UNKNOWN_ACTION: " + id);|
      assert code =~ ~s|throw new Error("REFUSED_NOT_DO_BOUNDARY: " + id|

      assert code =~
               "return Object.freeze({ kind: \"DISPATCH_INTENT\", actionId: id, input: parsed });"

      # No execution path anywhere in the artifact.
      refute code =~ "invoke("
      refute code =~ "fetch("
      refute code =~ "transport"
      refute code =~ "await "
    end

    test "non-delegated boundary stays null instead of being inferred", %{bridge_code: code} do
      assert code =~ ~s|id: "Member.deactivate",|
      assert code =~ "authorityBoundary: null"
    end
  end

  describe "byte determinism" do
    test "repeated projection over the same IR is byte-identical", %{bridge_code: code} do
      {name, first} = project_code(fixture_irs())
      {^name, second} = project_code(fixture_irs())
      assert first == second
      assert first == code
    end

    test "input reordering projects byte-identical bytes", %{bridge_code: code} do
      shuffled = Enum.reverse(fixture_irs())

      {_name, other} = project_code(shuffled)
      assert other == code
    end
  end

  describe "target_dir write" do
    @tag :tmp_dir
    test "writes exactly the one .mjs file", %{tmp_dir: tmp_dir} do
      {sole, code} = project_code(fixture_irs(), target_dir: tmp_dir)

      written = File.read!(Path.join(tmp_dir, sole))
      assert written == code
    end
  end

  describe "AshSurface.Projector.IR normalization" do
    test "describe/1 flattens delegated facts with atom/string tolerance" do
      entry = IREntry.describe(member_profile_ir())
      assert entry.id == "Member.profile"
      assert entry.resource == "Member"
      assert entry.action_type == "read"
      assert entry.authority_boundary == "CONSTRUCT"
      assert entry.zod == nil
    end

    test "module resources are named by their last segment" do
      ir = %{todo_create_ir() | ash: %{todo_create_ir().ash | resource: Some.Domain.Todo}}

      assert %IREntry{} = entry = IREntry.describe(ir)
      assert entry.id == "Todo.create"
    end

    test "do_boundary?/1 holds only for the literal DO fact" do
      entries = IREntry.entries(fixture_irs())
      assert [%{id: "Todo.create"}] = Enum.filter(entries, &IREntry.do_boundary?/1)
    end
  end

  defp project_code(irs, opts \\ []) do
    assert {:ok, artifacts, _meta} = JS.project_ir(irs, opts)
    assert [sole] = Map.keys(artifacts)
    {sole, Map.fetch!(artifacts, sole)}
  end

  defp count(code, regex), do: length(Regex.scan(regex, code))
end
