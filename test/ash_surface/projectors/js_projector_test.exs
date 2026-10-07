defmodule AshSurface.Projectors.JsProjectorTest do
  @moduledoc """
  Tests for `AshSurface.Projectors.JS.project_ir/2`: ONE JSDoc + Zod `.mjs`
  artifact (default prefix `ash_surface_client`), byte-deterministic, with
  DO-boundary actions projecting dispatch-intent descriptors only.

  The artifact's behaviour - JSDoc namespaces, Zod schemas embedded from
  `IR.Schema.zod`, the DO dispatch-intent law and the refusing factory - is
  pinned by EXECUTION (`GeneratedArtifactsExecTest`, and
  `test/js/ir_projection.test.mjs` over the bridge below), not by asserting
  source fragments.

  `setup_all/1` also materializes the cross-language bridge consumed by
  `test/js/ir_projection.test.mjs`: the emitted artifact plus a `fixture.json`
  sidecar carrying the exact normalized fixture truth, both under
  `tmp/js_projector/`.
  """

  use ExUnit.Case, async: true

  alias AshSurface.IR
  alias AshSurface.Projector.IREntry
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

  describe "structured refusal objects" do
    test "emitted dispatchIntent refusals carry a machine-readable refusal property", %{
      bridge_code: code
    } do
      # Error type/message strings are unchanged (message-regex catch sites in
      # test/js keep working); the structured payload is additive.
      assert code =~ ~s(refusal: "REFUSED_UNKNOWN_ACTION")
      assert code =~ ~s(refusal: "REFUSED_NOT_DO_BOUNDARY")
      assert code =~ ~s(standing: "BLOCKED")
      assert code =~ ~s(detail: { actionId: id })
      assert code =~ "Object.assign(new Error(\"REFUSED_UNKNOWN_ACTION: \" + id)"
      refute code =~ ~s(throw new Error("REFUSED_)
    end

    test "the materialized bridge throws structured refusal errors at runtime", %{
      bridge_code: _code
    } do
      # Chicago: execute the real emitted artifact, assert on the thrown state.
      dir = Path.join(File.cwd!(), @bridge_dir)
      assert File.exists?(Path.join(dir, @default_artifact))

      {script, status} =
        System.cmd(
          "node",
          [
            "--input-type=module",
            "-e",
            """
            import { dispatchIntent } from #{inspect(Path.join(dir, @default_artifact))};
            const cases = [
              "Nope.missing",
              "Todo.list",
            ];
            for (const id of cases) {
              try {
                dispatchIntent(id, {});
                throw new Error("expected refusal for " + id);
              } catch (e) {
                if (!/^REFUSED_/.test(e.message) || typeof e.refusal !== "string" ||
                    !e.refusal.startsWith("REFUSED_") || e.standing !== "BLOCKED" ||
                    e.detail.actionId !== id) {
                  throw new Error("unstructured refusal for " + id + ": " + JSON.stringify({refusal: e.refusal, standing: e.standing, detail: e.detail}));
                }
              }
            }
            console.log("structured-refusals-ok");
            """,
          ],
          cd: dir
        )

      assert status == 0, "node runtime check failed:\n#{script}"
      assert String.trim(script) == "structured-refusals-ok"
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

  describe "AshSurface.Projector.IREntry normalization" do
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
end
