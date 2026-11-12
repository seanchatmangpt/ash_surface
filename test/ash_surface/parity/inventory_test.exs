defmodule AshSurface.Parity.InventoryTest do
  use ExUnit.Case, async: true

  alias AshSurface.Parity.Inventory

  @repo Path.expand("../../..", __DIR__)

  # A real, tiny reference tree on disk: the extractors run over real files.
  defp write_reference! do
    root = Path.join(System.tmp_dir!(), "parity-ref-#{AshSurface.TestTmp.suffix()}")
    lib = Path.join(root, "lib/ash_typescript")
    File.mkdir_p!(Path.join(lib, "codegen"))
    File.mkdir_p!(Path.join(lib, "rpc"))
    File.mkdir_p!(Path.join(lib, "manifest/verifiers"))
    File.mkdir_p!(Path.join(root, "lib/mix/tasks"))
    File.mkdir_p!(Path.join(root, "test"))
    on_exit(fn -> File.rm_rf!(root) end)

    File.write!(Path.join(lib, "rpc.ex"), """
    defmodule AshTypescript.Rpc do
      @common [description: [type: :string], see: [type: :any]]
      @action %Spark.Dsl.Entity{
        name: :rpc_action,
        schema: [action: [type: :atom], enable_filter?: [type: :boolean]] ++ @common
      }
      def cfg, do: Application.get_env(:ash_typescript, :zod_import_path, "zod")
    end
    """)

    File.write!(Path.join(lib, "codegen/type_mapper.ex"), """
    defmodule AshTypescript.Codegen.TypeMapper do
      @primitives %{Ash.Type.UUIDv7 => "UUIDv7", Ash.Type.CiString => "string"}
      @aggregate_kinds %{count: "number"}
      def f(constraints), do: Keyword.get(constraints, :max_length)
      def ts, do: "export type Foo = string;"
    end
    """)

    File.write!(Path.join(lib, "rpc/error.ex"), """
    defimpl AshTypescript.Rpc.Error, for: Ash.Error.Query.NotFound do
      def to_error(_), do: %{type: "not_found"}
    end
    """)

    File.write!(Path.join(lib, "manifest/verifiers/verify_rpc.ex"), """
    defmodule AshTypescript.Manifest.Verifiers.VerifyRpc do
    end
    """)

    File.write!(Path.join(root, "lib/mix/tasks/ash_typescript.codegen.ex"), """
    defmodule Mix.Tasks.AshTypescript.Codegen do
      def run(args), do: OptionParser.parse(args, switches: [check: :boolean])
    end
    """)

    File.write!(
      Path.join(root, "test/a_test.exs"),
      "describe \"x\" do\n  test \"y\" do\n  end\nend\n"
    )

    root
  end

  test "extractors derive every section from real source files" do
    {:ok, inv} = Inventory.derive(write_reference!())
    ids = Enum.map(inv.capabilities, & &1.id)

    for id <-
          ~w(dsl.rpc.entity.rpc_action dsl.rpc.entity.rpc_action.option.action
             dsl.rpc.entity.rpc_action.option.enable_filter? dsl.rpc.entity.rpc_action.option.see
             config.key.zod_import_path type.kind.uuid_v7 type.kind.ci_string type.aggregate.count
             type.constraint.max_length error.impl.Ash.Error.Query.NotFound error.type.not_found
             task.codegen task.codegen.flag.check verifier.VerifyRpc tstype.Foo
             runtime.module.Rpc) do
      assert id in ids, "missing #{id}"
    end

    assert ids == Enum.sort(ids)
    assert ids == Enum.uniq(ids)
    assert inv.advisory["test_describe_blocks"] == 1
  end

  test "schema options spliced via ++ @attr are resolved" do
    {:ok, inv} = Inventory.derive(write_reference!())
    ids = Enum.map(inv.capabilities, & &1.id)
    assert "dsl.rpc.entity.rpc_action.option.description" in ids
  end

  test "JSON rendering is byte-identical across derivations and round-trips" do
    root = write_reference!()
    {:ok, a} = Inventory.derive(root)
    {:ok, b} = Inventory.derive(root)
    assert Inventory.to_json(a) == Inventory.to_json(b)
    refute Inventory.to_json(a) =~ root
    assert Inventory.from_json!(Inventory.to_json(a)) == a
  end

  test "a missing reference is a loud error, never an empty inventory" do
    assert {:error, msg} = Inventory.derive("/nonexistent/reference/root")
    assert msg =~ "not found"
  end

  test "committed parity/capabilities.json matches a fresh derivation of the live reference" do
    ref = Path.expand("~/ash_typescript")

    if File.dir?(Path.join(ref, "lib")) do
      {:ok, inv} = Inventory.derive(ref)
      assert Inventory.to_json(inv) == File.read!(Path.join(@repo, "parity/capabilities.json"))
    else
      IO.puts("[SKIP] reference checkout #{ref} absent: inventory drift not checked here")
    end
  end
end
