defmodule CAE.A.Item do
  use Ash.Resource, data_layer: :embedded, domain: nil

  attributes do
    uuid_primary_key(:id)
    attribute(:n, :integer, public?: true)
  end
end

defmodule CAE.B.Item do
  use Ash.Resource, data_layer: :embedded, domain: nil

  attributes do
    uuid_primary_key(:id)
    attribute(:s, :string, public?: true)
  end
end

defmodule CAE.Rec do
  use Ash.Resource, data_layer: :embedded, domain: nil

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, public?: true)
    attribute(:child, :struct, public?: true, constraints: [instance_of: CAE.Rec])
  end
end

defmodule CAE.Rich do
  use Ash.Resource, data_layer: :embedded, domain: nil
  require Ash.Expr

  attributes do
    uuid_primary_key(:id)

    attribute(:u, :union,
      public?: true,
      constraints: [types: [i: [type: :integer], s: [type: :string]]]
    )

    attribute(:e, CAE.A.Item, public?: true)
  end

  calculations do
    calculate(:c, :string, Ash.Expr.expr("x"), public?: true)
  end
end

defmodule AshSurface.Projectors.JSEmbeddedFilterExportTest do
  @moduledoc """
  Lane CR: embedded-resource filter schemas are exported as named consts from the real
  projected .mjs and executed under real node + zod (no mocks).
  """
  use ExUnit.Case, async: false

  alias AshSurface.{IR, Projectors.JS}
  alias AshSurface.Ported.TaskMetadata

  @root Path.expand("../../..", __DIR__)

  defp ir do
    IR.new(
      ash: %IR.Ash{
        resource: "Todo",
        action: :run,
        action_type: :action,
        policies: [%{"authorityBoundary" => "OBSERVE"}]
      },
      schema: %IR.Schema{zod: "z.object({a: z.string()})"}
    )
  end

  defp project(opts), do: JS.project_ir(ir(), opts)

  defp run(code, name, payloads) do
    dir = Path.join(System.tmp_dir!(), "cr_#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(Path.join(dir, "node_modules"))
    File.ln_s!(Path.join(@root, "node_modules/zod"), Path.join(dir, "node_modules/zod"))
    File.write!(Path.join(dir, "client.mjs"), code)

    File.write!(Path.join(dir, "run.mjs"), """
    import * as m from "./client.mjs";
    const S = m.#{name};
    const ps = #{Jason.encode!(payloads)};
    process.stdout.write(JSON.stringify(ps.map((p) => S.safeParse(p).success)));
    """)

    {out, status} = System.cmd("node", ["run.mjs"], cd: dir, stderr_to_stdout: true)
    File.rm_rf!(dir)
    assert status == 0, out
    Jason.decode!(out)
  end

  test "embedded filter is a named export validated by node+zod from the real artifact" do
    assert {:ok, %{"ash_surface_client.mjs" => code}, _} =
             project(embedded_filters: [TaskMetadata])

    assert code =~ "export const TaskMetadataEmbeddedFilterSchema ="

    f = fn field, op, value -> %{field: field, op: op, value: value} end

    assert [true, true, false, true, false] ==
             run(code, "TaskMetadataEmbeddedFilterSchema", [
               f.("createdBy", "eq", "a"),
               %{op: "and", value: [f.("isPublic", "eq", true)]},
               f.("created_by", "eq", "a"),
               %{op: "not", value: f.("priorityLevel", "gt", 1)},
               f.("createdBy", "gt", 5)
             ])
  end

  test "deterministic: repeat projection is byte-identical; default emits no embedded export" do
    {:ok, a, _} = project(embedded_filters: [TaskMetadata])
    {:ok, b, _} = project(embedded_filters: [TaskMetadata, TaskMetadata])
    assert a == b

    {:ok, %{"ash_surface_client.mjs" => base}, _} = project([])
    refute base =~ "EmbeddedFilterSchema"
  end

  test "invalid embedded_filters is refused, nothing rendered" do
    assert {:error, {:invalid_embedded_filters, :nope}} = project(embedded_filters: :nope)
    assert {:error, {:unadmitted_embedded_filter, _, _}} = project(embedded_filters: [String])
  end

  defp f(field, op, value), do: %{field: field, op: op, value: value}

  test "same short name in different namespaces exports both, deterministically qualified" do
    assert {:ok, %{"ash_surface_client.mjs" => code}, _} =
             project(embedded_filters: [CAE.A.Item, CAE.B.Item])

    assert code =~ "export const CAEAItemEmbeddedFilterSchema ="
    assert code =~ "export const CAEBItemEmbeddedFilterSchema ="

    assert [true, false] ==
             run(code, "CAEAItemEmbeddedFilterSchema", [f("n", "eq", 1), f("s", "eq", "x")])

    assert [true, false] ==
             run(code, "CAEBItemEmbeddedFilterSchema", [f("s", "eq", "x"), f("n", "eq", 1)])

    assert {:ok, %{"ash_surface_client.mjs" => named}, _} =
             project(
               embedded_filters: [CAE.A.Item, CAE.B.Item],
               namespace_names: %{"CAE.A.Item" => "AItem", "CAE.B.Item" => "BItem"}
             )

    assert named =~ "export const AItemEmbeddedFilterSchema ="
    assert named =~ "export const BItemEmbeddedFilterSchema ="
  end

  test "embedded/union attribute values are typed; calculations are filterable" do
    {:ok, %{"ash_surface_client.mjs" => code}, _} = project(embedded_filters: [CAE.Rich])

    assert [true, true, true, false, false, false, true, false] ==
             run(code, "RichEmbeddedFilterSchema", [
               f("e", "eq", %{n: 5}),
               f("u", "eq", %{i: 5}),
               f("u", "eq", %{s: "x"}),
               f("e", "eq", 5),
               f("u", "eq", 5),
               f("u", "eq", %{a: 1}),
               f("c", "eq", "x"),
               f("c", "eq", 5)
             ])
  end

  test "self-referential struct filter is bounded and typed, junk rejected" do
    {:ok, %{"ash_surface_client.mjs" => code}, _} = project(embedded_filters: [CAE.Rec])

    assert [false, false, true] ==
             run(code, "RecEmbeddedFilterSchema", [
               f("child", "eq", "junk"),
               f("child", "eq", 5),
               f("child", "eq", %{name: "n"})
             ])
  end

  test "Ash cannot aggregate on an embedded resource; no aggregate entry is ever emitted" do
    out =
      ExUnit.CaptureIO.capture_io(:stderr, fn ->
        Code.compile_string("""
        defmodule CAG.Emb do
          use Ash.Resource, data_layer: :embedded, domain: nil

          attributes do
            uuid_primary_key(:id)
            attribute(:n, :integer, public?: true)
          end

          relationships do
            has_many :kids, CAG.Emb, public?: true
          end

          aggregates do
            count :kid_count, :kids, public?: true
          end
        end
        """)
      end)

    # The real Ash verifier error (the module still loads, so the fact layer must refuse).
    assert out =~ "CAG.Emb.kids is not aggregatable"

    assert Ash.Resource.Info.public_aggregates(CAG.Emb) != []

    names =
      CAG.Emb
      |> AshSurface.Compiler.ResourceFacts.embedded_filter_entries()
      |> Enum.map(& &1["name"])

    assert "n" in names
    refute "kidCount" in names

    {:ok, %{"ash_surface_client.mjs" => code}, _} = project(embedded_filters: [CAG.Emb])

    assert [true, false, false] ==
             run(code, "EmbEmbeddedFilterSchema", [
               f("n", "eq", 1),
               f("kidCount", "eq", 1),
               f("n", "eq", "x")
             ])
  end

  test "self-referential child: scalar rejected within the cut; past it a record limit (pinned)" do
    {:ok, %{"ash_surface_client.mjs" => code}, _} = project(embedded_filters: [CAE.Rec])

    nest = fn leaf, depth ->
      Enum.reduce(1..depth, leaf, fn _, acc -> %{name: "n", child: acc} end)
    end

    # Documented limit (no z.lazy in filter values): beyond the cut the value is an object-only
    # record, so a scalar buried 6 levels deep is accepted (indices 3, 4); the cut itself
    # still rejects a bare scalar (index 2 and the CAE courts).
    assert [true, true, false, true, true] ==
             run(code, "RecEmbeddedFilterSchema", [
               f("child", "eq", nest.(%{name: "n"}, 1)),
               f("child", "eq", nest.(%{name: "n"}, 6)),
               f("child", "eq", nest.("junk", 1)),
               f("child", "eq", nest.("junk", 6)),
               f("child", "eq", nest.(5, 6))
             ])
  end
end
