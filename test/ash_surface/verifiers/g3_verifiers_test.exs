defmodule AshSurface.Verifiers.G3Test.Opaque do
  @moduledoc false
  use Ash.Type
  # Storage with no JSON wire form: KD-06 refuses it (kind "unknown"). A `:string` storage
  # now derives z.string() (wave3-t8 storage-derived custom types) and is no longer refused.
  @impl true
  def storage_type(_), do: :some_unmappable_thing
  @impl true
  def cast_input(v, _), do: {:ok, v}
  @impl true
  def cast_stored(v, _), do: {:ok, v}
  @impl true
  def dump_to_native(v, _), do: {:ok, v}
end

defmodule AshSurface.Verifiers.G3Test do
  @moduledoc """
  Real-Spark-path courts for the ported ash_typescript verifiers and transformer:
  VerifyUniqueInputFieldNames, VerifyMapFieldNames, VerifyMappableTypes,
  VerifyMetadataFieldNames, VerifyUniqueTypeNames, VerifyRpcWarnings (analogue),
  VerifierChecker, PersistFormattedFields. Resources are compiled with
  `Code.compile_string`; Spark verifier errors surface as compile warnings on
  stderr (no mocks).
  """
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  defp uniq, do: :erlang.unique_integer([:positive])

  defp resource_src(mod, body, opts \\ []) do
    domain = Keyword.get(opts, :domain, "nil")
    attrs = Keyword.get(opts, :attrs, "")
    actions = Keyword.get(opts, :actions, "defaults([:read])")

    """
    defmodule #{mod} do
      use Ash.Resource, domain: #{domain}, data_layer: Ash.DataLayer.Simple,
        extensions: [AshSurface.Resource]
      attributes do
        uuid_primary_key(:id, public?: true)
        #{attrs}
      end
      actions do
        #{actions}
      end
      surface do
        #{body}
      end
    end
    """
  end

  defp compile(src), do: capture_io(:stderr, fn -> Code.compile_string(src) end)

  defp refused(src, code) do
    out = compile(src)
    assert out =~ "Spark.Error.DslError"
    assert out =~ code
    out
  end

  defp mod, do: "AshSurface.Verifiers.G3Test.R#{uniq()}"

  describe "VerifyUniqueInputFieldNames" do
    test "inputs colliding after formatting are refused; argument_names resolves it" do
      actions = """
      create :make do
        accept []
        argument :user_id, :string, public?: true
        argument :userId, :string, public?: true
      end
      """

      refused(
        resource_src(mod(), "projection(:make)", actions: actions),
        "unique_input_field_names"
      )

      ok =
        resource_src(
          mod(),
          ~s|projection(:make)\nargument_names make: [userId: "userIdentifier"]|,
          actions: actions
        )

      refute compile(ok) =~ "unique_input_field_names"
    end
  end

  describe "VerifyMapFieldNames" do
    test "typed map fields that collide after formatting are refused" do
      attrs = """
      attribute :meta, :map, public?: true,
        constraints: [fields: [user_id: [type: :string], userId: [type: :string]]]
      """

      refused(resource_src(mod(), "projection(:read)", attrs: attrs), "invalid_map_field_names")

      ok = """
      attribute :meta, :map, public?: true,
        constraints: [fields: [user_id: [type: :string], name: [type: :string]]]
      """

      refute compile(resource_src(mod(), "projection(:read)", attrs: ok)) =~
               "invalid_map_field_names"
    end
  end

  describe "VerifyMappableTypes" do
    test "an attribute whose type has no Zod kind is refused" do
      attrs = "attribute :blob, AshSurface.Verifiers.G3Test.Opaque, public?: true"
      out = compile(resource_src(mod(), "projection(:read)", attrs: attrs))
      assert out =~ "unmappable_type"
    end

    test "a built-in type is admitted" do
      attrs = "attribute :name, :string, public?: true"
      refute compile(resource_src(mod(), "projection(:read)", attrs: attrs)) =~ "unmappable_type"
    end
  end

  describe "VerifyMetadataFieldNames" do
    test "unknown show_metadata and colliding metadata names are refused" do
      actions = """
      read :with_meta do
        metadata :score, :integer
        metadata :score_two, :integer
      end
      """

      out =
        refused(
          resource_src(mod(), "projection(:with_meta, show_metadata: [:ghost])",
            actions: actions
          ),
          "unknown_show_metadata"
        )

      assert out =~ "unknown_show_metadata"

      out =
        refused(
          resource_src(
            mod(),
            ~s|projection(:with_meta, show_metadata: [:score, :score_two], metadata_field_names: [score: "same", score_two: "same"])|,
            actions: actions
          ),
          "invalid_metadata_field_names"
        )

      assert out =~ "invalid_metadata_field_names"
    end
  end

  describe "VerifyUniqueTypeNames" do
    test "two surface resources in one domain with the same type_name are refused" do
      n = uniq()
      dom = "AshSurface.Verifiers.G3Test.Dom#{n}"
      a = "AshSurface.Verifiers.G3Test.A#{n}"
      b = "AshSurface.Verifiers.G3Test.B#{n}"

      src =
        """
        defmodule #{dom} do
          use Ash.Domain, validate_config_inclusion?: false, extensions: [AshSurface.Domain]
          resources do
            resource(#{a})
            resource(#{b})
          end
        end
        """ <>
          resource_src(a, ~s|type_name "Same"\nprojection(:read)|, domain: dom) <>
          resource_src(b, ~s|type_name "Same"\nprojection(:read)|, domain: dom)

      out = compile(src)
      assert out =~ "duplicate_type_names"
      assert out =~ "Same"
    end

    test "distinct type names are admitted" do
      n = uniq()
      dom = "AshSurface.Verifiers.G3Test.Dom#{n}"
      a = "AshSurface.Verifiers.G3Test.A#{n}"
      b = "AshSurface.Verifiers.G3Test.B#{n}"

      src =
        """
        defmodule #{dom} do
          use Ash.Domain, validate_config_inclusion?: false, extensions: [AshSurface.Domain]
          resources do
            resource(#{a})
            resource(#{b})
          end
        end
        """ <>
          resource_src(a, ~s|type_name "One"\nprojection(:read)|, domain: dom) <>
          resource_src(b, ~s|type_name "Two"\nprojection(:read)|, domain: dom)

      refute compile(src) =~ "duplicate_type_names"
    end
  end

  describe "VerifyRpcWarnings (warn_on_missing_rpc_config analogue)" do
    defp domain_with_empty_resource do
      n = uniq()
      dom = "AshSurface.Verifiers.G3Test.WDom#{n}"
      a = "AshSurface.Verifiers.G3Test.WA#{n}"

      """
      defmodule #{dom} do
        use Ash.Domain, validate_config_inclusion?: false, extensions: [AshSurface.Domain]
        resources do
          resource(#{a})
        end
      end
      """ <> resource_src(a, "", domain: dom)
    end

    test "warns on stderr by default, silent when toggled off, never an error" do
      out = compile(domain_with_empty_resource())
      assert out =~ "declares no surface projection"
      refute out =~ "Spark.Error.DslError"

      Application.put_env(:ash_surface, :warn_on_missing_rpc_config, false)

      try do
        refute compile(domain_with_empty_resource()) =~ "declares no surface projection"
      after
        Application.delete_env(:ash_surface, :warn_on_missing_rpc_config)
      end
    end
  end

  describe "VerifierChecker" do
    test "ok for a valid resource, aggregated error for an invalid one" do
      good = mod()
      bad = mod()
      capture_io(:stderr, fn -> Code.compile_string(resource_src(good, "projection(:read)")) end)
      capture_io(:stderr, fn -> Code.compile_string(resource_src(bad, "projection(:ghost)")) end)

      assert :ok == AshSurface.VerifierChecker.check_all_verifiers([Module.concat([good])])

      assert {:error, msg} =
               AshSurface.VerifierChecker.check_all_verifiers([
                 Module.concat([good]),
                 Module.concat([bad])
               ])

      assert msg =~ bad
      assert msg =~ "unknown_action_projection"
      refute msg =~ good
    end
  end

  describe "PersistFormattedFields transformer" do
    test "persists resolved client names with field_names mapping and reverse index" do
      m = mod()

      attrs = """
      attribute :first_name, :string, public?: true
      attribute :field_1, :string, public?: true
      """

      capture_io(:stderr, fn ->
        Code.compile_string(
          resource_src(m, ~s|projection(:read)\nfield_names field_1: "field1"|, attrs: attrs)
        )
      end)

      persisted =
        Spark.Dsl.Extension.get_persisted(Module.concat([m]), :ash_surface_formatted_fields)

      assert persisted.mapped.first_name == "firstName"
      assert persisted.mapped.field_1 == "field1"
      assert persisted.reverse["field1"] == :field_1
    end
  end
end
