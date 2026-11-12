defmodule AshSurface.Ported.Manifest.VerifyMappableTypesSurfaceTest.BareCustomType do
  @moduledoc false
  use Ash.Type

  # KD-06 (wave3-t8/t12): storage with no JSON wire form is refused as unmappable; a plain
  # `:string` storage now derives z.string() and would be admitted, so the bare type keeps an
  # un-derivable storage to stay the "no Zod kind" specimen.
  @impl true
  def storage_type(_), do: :some_unmappable_thing
  @impl true
  def cast_input(nil, _), do: {:ok, nil}
  def cast_input(value, _) when is_binary(value), do: {:ok, value}
  def cast_input(_, _), do: :error
  @impl true
  def cast_stored(nil, _), do: {:ok, nil}
  def cast_stored(value, _) when is_binary(value), do: {:ok, value}
  def cast_stored(_, _), do: :error
  @impl true
  def dump_to_native(nil, _), do: {:ok, nil}
  def dump_to_native(value, _) when is_binary(value), do: {:ok, value}
  def dump_to_native(_, _), do: :error
end

defmodule AshSurface.Ported.Manifest.VerifyMappableTypesSurfaceTest.NamedCustomType do
  @moduledoc false
  use Ash.Type

  def typescript_type_name, do: "string"
  @impl true
  def storage_type(_), do: :string
  @impl true
  def cast_input(nil, _), do: {:ok, nil}
  def cast_input(value, _) when is_binary(value), do: {:ok, value}
  def cast_input(_, _), do: :error
  @impl true
  def cast_stored(nil, _), do: {:ok, nil}
  def cast_stored(value, _) when is_binary(value), do: {:ok, value}
  def cast_stored(_, _), do: :error
  @impl true
  def dump_to_native(nil, _), do: {:ok, nil}
  def dump_to_native(value, _) when is_binary(value), do: {:ok, value}
  def dump_to_native(_, _), do: :error
end

defmodule AshSurface.Ported.Manifest.VerifyMappableTypesSurfaceTest do
  @moduledoc """
  ash_surface counterpart of ash_typescript `manifest/verify_mappable_types_test`,
  against the real `AshSurface.Resource.Validator` (`unmappable_type` refusal).

  Changes: `AshTypescript.Manifest.verify_for_domains/1` -> `Validator.validate/1`;
  the `type_mapping_overrides` app env -> `:zod_mapping_overrides` (module-keyed Zod
  expression, snapshot/restored via `on_exit`); message wording ("Unsupported types found",
  "typescript_type_name/0") -> the refusal detail (`:name has type <Type> ... add a
  zod_mapping_overrides entry`). Per-test: the input-argument and nested-map cases
  assert the refusal names the offending field/argument and type.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.Manifest.VerifyMappableTypesSurfaceTest.{
    BareCustomType,
    NamedCustomType
  }

  @bare inspect(BareCustomType)

  defp compile(body) do
    mod = Module.concat(__MODULE__, "R#{System.unique_integer([:positive])}")

    src = """
    defmodule #{inspect(mod)} do
      use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Ets,
        extensions: [AshSurface.Resource]
      surface do
        type_name "#{List.last(Module.split(mod))}"
      end
      #{body}
    end
    """

    ExUnit.CaptureIO.capture_io(:standard_error, fn -> Code.compile_string(src) end)
    mod
  end

  defp unmappable(mod) do
    case AshSurface.Resource.Validator.validate(%{resource: mod, surface: []}) do
      :ok -> []
      {:error, refusals} -> for %{code: "unmappable_type"} = r <- refusals, do: r.detail
    end
  end

  describe "unmappable custom types" do
    test "bare custom type on an attribute is rejected with remediation guidance" do
      mod =
        compile("""
        attributes do
          uuid_primary_key :id
          attribute :identifier, #{@bare}, public?: true
        end
        actions do
          defaults [:read]
        end
        """)

      assert [detail] = unmappable(mod)
      assert detail =~ "VerifyMappableTypesSurfaceTest.BareCustomType"
      assert detail =~ ":identifier"
      assert detail =~ "zod_mapping_overrides"
    end

    test "bare custom type as an action argument is rejected with the argument context" do
      mod =
        compile("""
        attributes do
          uuid_primary_key :id
        end
        actions do
          defaults [:read]
          read :by_identifier do
            argument :identifier, #{@bare}
          end
        end
        """)

      assert [detail] = unmappable(mod)
      assert detail =~ "VerifyMappableTypesSurfaceTest.BareCustomType"
      assert detail =~ ":identifier"
    end

    test "bare custom type nested in a typed map field is rejected" do
      mod =
        compile("""
        attributes do
          uuid_primary_key :id
          attribute :payload, :map do
            public? true
            constraints fields: [identifier: [type: #{@bare}]]
          end
        end
        actions do
          defaults [:read]
        end
        """)

      assert [detail] = unmappable(mod)
      assert detail =~ ":payload"
      assert detail =~ "unmappable kinds"
    end
  end

  describe "container kinds are not unmappable" do
    test "union, typed map and embedded resource attributes are admitted" do
      mod =
        compile("""
        attributes do
          uuid_primary_key :id
          attribute :choice, :union do
            public? true
            constraints types: [text: [type: :string], count: [type: :integer]]
          end
          attribute :payload, :map do
            public? true
            constraints fields: [name: [type: :string]]
          end
          attribute :meta, AshSurface.Ported.TodoMetadata, public?: true
        end
        actions do
          defaults [:read]
        end
        """)

      assert unmappable(mod) == []
    end
  end

  describe "mappable custom types" do
    setup do
      original = Application.get_env(:ash_surface, :zod_mapping_overrides)

      on_exit(fn ->
        if original == nil,
          do: Application.delete_env(:ash_surface, :zod_mapping_overrides),
          else: Application.put_env(:ash_surface, :zod_mapping_overrides, original)
      end)

      :ok
    end

    test "custom type with typescript_type_name/0 passes" do
      mod =
        compile("""
        attributes do
          uuid_primary_key :id
          attribute :identifier, #{inspect(NamedCustomType)}, public?: true
        end
        actions do
          defaults [:read]
        end
        """)

      assert unmappable(mod) == []
    end

    test "the typescript_type_name/0 declaration renders its Zod primitive" do
      a = AshSurface.Compiler.TypeFacts.analyze(NamedCustomType, [])
      assert AshSurface.Compiler.ZodType.fragment(a.definition, overrides: %{}) == "z.string()"
    end

    test "bare custom type with a zod_mapping_overrides entry passes" do
      mod =
        compile("""
        attributes do
          uuid_primary_key :id
          attribute :identifier, #{@bare}, public?: true
        end
        actions do
          defaults [:read]
        end
        """)

      assert [_] = unmappable(mod)
      Application.put_env(:ash_surface, :zod_mapping_overrides, [{BareCustomType, "z.string()"}])
      assert unmappable(mod) == []
    end
  end
end
