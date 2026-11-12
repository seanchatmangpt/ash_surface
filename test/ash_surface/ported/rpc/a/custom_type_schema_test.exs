Code.require_file("../../top/support/t2.exs", __DIR__)

defmodule AshSurface.Ported.Rpc.A.CustomTypeSchemaTest do
  @moduledoc """
  Adaptation of ash_typescript `custom_type_schema_test.exs` (hand-rolled custom Ash types).

  Deltas (pinned in `changes` of the ledger row):

    * ash_surface is Zod-only (README non-goals: no Valibot, no generated `.ts`); every
      `valibot(...)` assertion and the "per-library schema imports" describe have no counterpart.
    * ash_surface DERIVES a schema from `storage_type/1` for hand-rolled custom types with no
      override (parity with the reference `storage_derived_schema/2`): integer -> number, map ->
      record, datetime -> iso datetime, `{:array, t}` -> array. Executed under node+zod.
      Divergence KD-06: storage with no unambiguous JSON wire form is REFUSED as unmappable
      (kind "unknown", `z.unknown()`), where the reference silently falls back to `z.any()`.
    * Override tests run against `AshSurface.Compiler.ZodType` (module-keyed
      `:zod_mapping_overrides`), via `T2.zod/1`; "generated output" runs the real manifest +
      compiler and asserts the IR's `schema.zod` text.
  """
  use ExUnit.Case, async: false

  # Every test shells out to real node+zod (and two compile the whole ported domain); under a
  # loaded machine one test can pass ExUnit's 60s default (observed: pass alone, fail once in a
  # mixed run). All shared state is already per-test unique (T2 tmp dirs carry pid+unique_integer)
  # or scoped via T2.with_env, so the structural fix is a wide module budget, not a sleep.
  @moduletag timeout: 600_000

  alias AshSurface.Compiler.TypeFacts
  alias AshSurface.Ported.{CustomIdentifier, GeoPoint, T2}
  alias AshSurface.Ported.Todo.{ColorPalette, PriorityScore}

  for {name, storage} <- [
        {IntegerStorageType, :integer},
        {DatetimeStorageType, :utc_datetime_usec},
        {ArrayStorageType, {:array, :string}},
        {OpaqueStorageType, :some_unmappable_thing}
      ] do
    defmodule Module.concat(__MODULE__, name) do
      @moduledoc false
      use Ash.Type
      @storage storage

      @impl true
      def storage_type(_), do: @storage
      @impl true
      def cast_input(v, _), do: {:ok, v}
      @impl true
      def cast_stored(v, _), do: {:ok, v}
      @impl true
      def dump_to_native(v, _), do: {:ok, v}
    end
  end

  @integer_storage Module.concat(__MODULE__, IntegerStorageType)
  @datetime_storage Module.concat(__MODULE__, DatetimeStorageType)
  @array_storage Module.concat(__MODULE__, ArrayStorageType)
  @opaque_storage Module.concat(__MODULE__, OpaqueStorageType)

  # KD-06: never a guessed schema for storage with no JSON wire form: kind "unknown" renders
  # the explicit `z.unknown()` fragment, which the verifier reports as an unmappable kind.
  defp refused?(type), do: TypeFacts.kind(type) == "unknown" and T2.zod(type) == "z.unknown()"

  defp accepts(expr, payloads) do
    assert {:ok, oks} = T2.node_eval(expr, payloads)
    oks
  end

  describe "storage-derived fallback" do
    test "an integer-storage custom type validates as a number, not a string" do
      assert T2.zod(PriorityScore) == "z.number().int()"
      assert T2.zod(@integer_storage) == "z.number().int()"
      assert accepts(T2.zod(@integer_storage), [5, "5", 1.5]) == [true, false, false]
    end

    test "a map-storage custom type validates as a record, not a string" do
      assert T2.zod(ColorPalette) == "z.record(z.string(), z.unknown())"
      assert accepts(T2.zod(ColorPalette), [%{"a" => 1}, "x", nil]) == [true, false, false]
    end

    test "derives from storage for datetime-backed types" do
      assert T2.zod(@datetime_storage) == "z.iso.datetime()"

      assert accepts(T2.zod(@datetime_storage), ["2025-01-01T00:00:00Z", "yesterday"]) ==
               [true, false]
    end

    test "derives an array schema for array storage" do
      assert T2.zod(@array_storage) == "z.array(z.string())"
      assert accepts(T2.zod(@array_storage), [["a"], [1], "a"]) == [true, false, false]
    end

    test "unmappable storage is refused rather than silently permissive (KD-06)" do
      # A wrong schema rejects valid data; z.any() accepts invalid data. ash_surface refuses.
      assert refused?(@opaque_storage)
    end

    test "verifier view: derived storage is mappable, opaque storage is an unmappable kind" do
      defn = fn t -> AshSurface.Compiler.TypeFacts.analyze(t, []).definition end
      assert AshSurface.Compiler.ZodType.unmappable_kinds([defn.(@integer_storage)]) == []
      assert AshSurface.Compiler.ZodType.unmappable_kinds([defn.(@array_storage)]) == []
      assert AshSurface.Compiler.ZodType.unmappable_kinds([defn.(@opaque_storage)]) == ["unknown"]
    end

    test "a declared typescript_type_name does not mask the storage-derived schema" do
      assert function_exported?(PriorityScore, :typescript_type_name, 0)
      assert T2.zod(PriorityScore) == "z.number().int()"
    end
  end

  describe "config overrides" do
    test "an override replaces the unmappable-kind refusal" do
      T2.with_env(
        :zod_mapping_overrides,
        [{@integer_storage, ~s{z.string().brand<"Id">()}}],
        fn ->
          assert T2.zod(@integer_storage) == ~s{z.string().brand<"Id">()}
        end
      )
    end

    test "an override on one type leaves the other storage-derived types derived" do
      T2.with_env(:zod_mapping_overrides, [{@integer_storage, "z.string()"}], fn ->
        assert T2.zod(@integer_storage) == "z.string()"
        assert T2.zod(@datetime_storage) == "z.iso.datetime()"
      end)
    end

    test "an unrelated override does not leak onto other types" do
      T2.with_env(:zod_mapping_overrides, [{@integer_storage, "z.string()"}], fn ->
        assert T2.zod(PriorityScore) == "z.number().int()"
        assert T2.zod(Ash.Type.Integer) == "z.number().int()"
      end)
    end

    test "GeoPoint's override replaces a record schema it would otherwise get" do
      T2.with_env(:zod_mapping_overrides, [], fn ->
        assert T2.zod(GeoPoint) == "z.record(z.string(), z.unknown())"
      end)

      T2.with_env(:zod_mapping_overrides, [{GeoPoint, "z.record(z.string(), z.number())"}], fn ->
        assert T2.zod(GeoPoint) == "z.record(z.string(), z.number())"
      end)
    end

    test "an override wins over an in-tree mapping" do
      T2.with_env(:zod_mapping_overrides, [{Ash.Type.String, "z.string().length(26)"}], fn ->
        assert T2.zod(Ash.Type.String) == "z.string().length(26)"
      end)
    end
  end

  describe "generated output (compiled IR schema.zod)" do
    @tag timeout: 600_000
    test "configured overrides reach the compiled Zod schemas and nothing collapses to z.unknown()" do
      overrides = [
        {PriorityScore, "z.number().int()"},
        {ColorPalette, "z.record(z.string(), z.any())"},
        {CustomIdentifier, "CustomZodSchemas.objectId"},
        {GeoPoint, "NestedZodSchemas.geoPoint"},
        {AshMoney.Types.Money, "z.string()"}
      ]

      T2.with_env(:zod_mapping_overrides, overrides, fn ->
        Application.put_env(:ash_surface_t2, :ash_domains, [AshSurface.Ported.Domain])
        {:ok, manifest} = Ash.Info.Manifest.generate(otp_app: :ash_surface_t2)
        {:ok, irs} = AshSurface.Compiler.compile(manifest)
        irs = if is_map(irs), do: Map.values(irs), else: irs
        zods = for ir <- irs, ir.ash.resource == AshSurface.Ported.Todo, do: ir.schema.zod
        joined = Enum.join(zods, "\n")

        assert joined =~ "priorityScore: z.number().int()"
        assert joined =~ "colorPalette: z.record(z.string(), z.any())"
        refute joined =~ "priorityScore: z.unknown()"
        refute joined =~ "colorPalette: z.unknown()"
      end)
    end

    @tag timeout: 600_000
    test "hand-rolled custom types without overrides compile to storage-derived schemas" do
      overrides = [
        {CustomIdentifier, "CustomZodSchemas.objectId"},
        {GeoPoint, "NestedZodSchemas.geoPoint"},
        {AshMoney.Types.Money, "z.string()"}
      ]

      T2.with_env(:zod_mapping_overrides, overrides, fn ->
        Application.put_env(:ash_surface_t2, :ash_domains, [AshSurface.Ported.Domain])
        {:ok, manifest} = Ash.Info.Manifest.generate(otp_app: :ash_surface_t2)
        {:ok, irs} = AshSurface.Compiler.compile(manifest)
        irs = if is_map(irs), do: Map.values(irs), else: irs

        zods =
          for ir <- irs,
              ir.ash.resource in [AshSurface.Ported.Todo, AshSurface.Ported.Task],
              do: ir.schema.zod

        joined = Enum.join(zods, "\n")

        assert joined =~ "priorityScore: z.number().int()"
        assert joined =~ "colorPalette: z.record(z.string(), z.unknown())"
        assert joined =~ "customId: CustomZodSchemas.objectId"
        assert joined =~ "geoPoint: NestedZodSchemas.geoPoint"
        refute joined =~ "priorityScore: z.string()"
        refute joined =~ "colorPalette: z.string()"
        refute joined =~ "geoPoint: z.record"
      end)
    end
  end
end
