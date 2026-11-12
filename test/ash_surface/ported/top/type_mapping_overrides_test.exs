Code.require_file("support/t2.exs", __DIR__)

defmodule AshSurface.Ported.Top.TypeMappingOverridesTest do
  @moduledoc """
  Adaptation of ash_typescript `type_mapping_overrides_test.exs`. The TS-string override table
  (`type_mapping_overrides`) has no emitted-TS counterpart; its Zod analogue is
  `zod_mapping_overrides`, and the module-keyed entries (`{CustomIdentifier, "z.string()"}`)
  are consulted by `ZodType` (lane T2 added module-key lookup). `Config.type_mapping_overrides/0`
  is asserted as the config accessor. Global `:ash_surface` env is scoped per test.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.{CustomIdentifier, T2, Task}
  alias AshSurface.Compiler.{TypeFacts, ZodType}
  alias AshSurface.VerifierChecker

  @task_overrides [
    {CustomIdentifier, "z.string()"},
    {AshSurface.Ported.GeoPoint, "z.record(z.string(), z.number())"},
    {AshMoney.Types.Money, "z.string()"}
  ]

  defmodule OpaqueStorage do
    @moduledoc false
    use Ash.Type
    @impl true
    def storage_type(_), do: :some_unmappable_thing
    @impl true
    def cast_input(v, _), do: {:ok, v}
    @impl true
    def cast_stored(v, _), do: {:ok, v}
    @impl true
    def dump_to_native(v, _), do: {:ok, v}
  end

  describe "type mapping override configuration" do
    test "retrieves configured type mapping overrides" do
      T2.with_env(:type_mapping_overrides, [{CustomIdentifier, "string"}], fn ->
        assert AshSurface.Config.type_mapping_overrides() == [{CustomIdentifier, "string"}]
      end)
    end

    test "returns empty list when no overrides configured" do
      T2.with_env(:type_mapping_overrides, [{CustomIdentifier, "string"}], fn ->
        Application.delete_env(:ash_surface, :type_mapping_overrides)
        assert AshSurface.Config.type_mapping_overrides() == []
      end)
    end
  end

  describe "type mapping override in codegen (zod_mapping_overrides, module-keyed)" do
    test "the zod fragment uses the override for the configured type" do
      T2.with_env(:zod_mapping_overrides, [{CustomIdentifier, "z.string()"}], fn ->
        assert T2.zod(CustomIdentifier) == "z.string()"
      end)
    end

    test "works with the overridden type in an array" do
      T2.with_env(:zod_mapping_overrides, [{CustomIdentifier, "z.string()"}], fn ->
        assert T2.zod({:array, CustomIdentifier}) == "z.array(z.string())"
      end)
    end

    test "overrides take precedence over the built-in kind table" do
      # A module-keyed entry wins over the table fragment for that module's kind.
      assert T2.zod(Ash.Type.Integer) == "z.number().int()"

      T2.with_env(:zod_mapping_overrides, [{Ash.Type.Integer, "z.string()"}], fn ->
        assert T2.zod(Ash.Type.Integer) == "z.string()"
        # other integer-kinded fragments and unrelated modules are untouched
        assert T2.zod(Ash.Type.String) == "z.string()"
      end)
    end
  end

  describe "built-in decimal mapping (real ZodType + node zod)" do
    test "decimal projects z.string() and validates strings, not numbers" do
      T2.with_env(:zod_mapping_overrides, [], fn ->
        assert T2.zod(Ash.Type.Decimal) == "z.string()"
        assert {:ok, [true, false]} = T2.node_eval(T2.zod(Ash.Type.Decimal), ["1.50", 1.5])
      end)
    end
  end

  describe "built-in uuid mapping (real ZodType + node zod)" do
    test "uuid projects z.guid(): accepts any 8-4-4-4-12 hex, rejects non-uuid strings" do
      T2.with_env(:zod_mapping_overrides, [], fn ->
        assert T2.zod(Ash.Type.UUID) == "z.guid()"

        assert {:ok, [true, true, false, false]} =
                 T2.node_eval(T2.zod(Ash.Type.UUID), [
                   "123e4567-e89b-12d3-a456-426614174000",
                   "ffffffff-ffff-ffff-ffff-ffffffffffff",
                   "not-a-uuid",
                   42
                 ])
      end)
    end
  end

  describe "resource schema generation with type mapping overrides" do
    test "Task resource includes custom_id with the overridden type" do
      T2.with_env(:zod_mapping_overrides, @task_overrides, fn ->
        Application.put_env(:ash_surface_t2, :ash_domains, [AshSurface.Ported.Domain])
        {:ok, manifest} = Ash.Info.Manifest.generate(otp_app: :ash_surface_t2)
        {:ok, irs} = AshSurface.Compiler.compile(manifest)
        irs = if is_map(irs), do: Map.values(irs), else: irs

        ir = Enum.find(irs, &(&1.ash.resource == Task and &1.ash.action == :create))
        assert ir.schema.zod =~ "customId: z.string().nullable().optional()"
        refute ir.schema.zod =~ "customId: z.unknown()"
      end)
    end
  end

  describe "type without override" do
    # KD-06 (wave3-t8/t12): a hand-rolled type is kind "unknown"; its `:string` storage now
    # derives z.string() (admitted), while storage with no JSON wire form stays refused.
    test "custom type with derivable storage is kind unknown but derived, not refused" do
      assert TypeFacts.kind(CustomIdentifier) == "unknown"

      T2.with_env(:zod_mapping_overrides, [], fn ->
        assert T2.zod(CustomIdentifier) == "z.string()"
        assert ZodType.unmappable_kinds([TypeFacts.analyze(CustomIdentifier).definition]) == []
      end)
    end

    test "custom type with un-derivable storage is an unmappable kind" do
      T2.with_env(:zod_mapping_overrides, [], fn ->
        assert TypeFacts.kind(__MODULE__.OpaqueStorage) == "unknown"
        assert T2.zod(__MODULE__.OpaqueStorage) == "z.unknown()"

        assert ZodType.unmappable_kinds([TypeFacts.analyze(__MODULE__.OpaqueStorage).definition]) ==
                 ["unknown"]
      end)
    end

    test "the same type becomes mappable (verifier clean) once an override is configured" do
      T2.with_env(:zod_mapping_overrides, @task_overrides, fn ->
        assert ZodType.unmappable_kinds([TypeFacts.analyze(CustomIdentifier).definition]) == []
        assert :ok = VerifierChecker.check_all_verifiers([Task])
      end)
    end
  end

  describe "multiple type overrides" do
    test "supports multiple type mapping overrides" do
      another = AshSurface.Ported.AnotherCustomType
      overrides = [{CustomIdentifier, "string"}, {another, "number"}]

      T2.with_env(:type_mapping_overrides, overrides, fn ->
        got = AshSurface.Config.type_mapping_overrides()
        assert length(got) == 2
        assert {CustomIdentifier, "string"} in got
        assert {another, "number"} in got
      end)

      T2.with_env(
        :zod_mapping_overrides,
        [{CustomIdentifier, "z.string()"}, {Ash.Type.Float, "z.string()"}],
        fn ->
          assert T2.zod(CustomIdentifier) == "z.string()"
          assert T2.zod(Ash.Type.Float) == "z.string()"
        end
      )
    end
  end
end
