Code.require_file("support/e.exs", __DIR__)

defmodule AshSurface.Ported.Rpc.E.VerifyMetadataFieldNamesTest do
  @moduledoc """
  Port of ash_typescript `rpc/verify_metadata_field_names_test.exs` (13 tests).

  Reference: `rpc_action :read_data, :read_with_metadata, show_metadata: [...]` (+
  `metadata_field_names`) verified through `AshTypescript.Manifest.verify_for_domains/1`.
  ash_surface: `projection :read_with_metadata, name: :read_data, show_metadata: [...]` in the
  resource `surface` section, verified through `AshSurface.VerifierChecker`. "TypeScript name"
  wording becomes "client identifier"; the refusal texts keep the reference phrases
  ("Invalid metadata field name", "Metadata field conflicts with resource field",
  "Mapped metadata field conflicts with resource field").
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.E

  defp resource(opts) do
    name = E.uniq("T12.Meta")
    attrs = Keyword.get(opts, :attrs, "attribute :name, :string, public?: true")
    calcs = Keyword.get(opts, :calcs, "")
    meta = Keyword.fetch!(opts, :meta)
    surface_extra = Keyword.get(opts, :surface_extra, "")
    projection = Keyword.fetch!(opts, :projection)

    source = """
    defmodule #{name} do
      use Ash.Resource,
        domain: nil,
        data_layer: Ash.DataLayer.Ets,
        validate_domain_inclusion?: false,
        extensions: [AshSurface.Resource]

      surface do
        type_name "#{name |> String.split(".") |> List.last()}"
        #{surface_extra}
        projection :read_with_metadata, name: :read_data, #{projection}
      end

      attributes do
        uuid_primary_key :id
        #{attrs}
      end

      #{calcs}

      actions do
        defaults [:read, :destroy]

        read :read_with_metadata do
          #{meta}
        end
      end
    end
    """

    [mod] = E.compile!(source)
    mod
  end

  describe "metadata field name validation - invalid client names" do
    test "detects metadata fields with underscores followed by digits" do
      mod =
        resource(
          meta: "metadata :field_1, :string\n metadata :valid_field, :integer",
          projection: "show_metadata: [:field_1, :valid_field]"
        )

      assert {:error, message} = E.check(mod)
      assert message =~ ~r/Invalid metadata field name/
      assert message =~ ~r/field_1/
      assert message =~ ~r/field1/
    end

    test "detects metadata fields with question marks" do
      mod =
        resource(
          meta: "metadata :is_valid?, :boolean\n metadata :status, :string",
          projection: "show_metadata: [:is_valid?, :status]"
        )

      assert {:error, message} = E.check(mod)
      assert message =~ ~r/Invalid metadata field name/
      assert message =~ ~r/is_valid\?/
      assert message =~ ~r/is_valid/
    end

    test "detects metadata fields with combined invalid patterns" do
      mod =
        resource(
          meta: "metadata :field_1?, :string\n metadata :item__2, :integer",
          projection: "show_metadata: [:field_1?, :item__2]"
        )

      assert {:error, message} = E.check(mod)
      assert message =~ ~r/Invalid metadata field name/
      assert message =~ ~r/field_1\?/
      assert message =~ ~r/item__2/
    end
  end

  describe "metadata field name validation - conflicts with resource fields" do
    test "detects conflict with attribute name" do
      mod =
        resource(
          attrs: """
          attribute :title, :string, public?: true
          attribute :status, :string, public?: true
          """,
          meta: "metadata :title, :string\n metadata :processing_time, :integer",
          projection: "show_metadata: [:title, :processing_time]"
        )

      assert {:error, message} = E.check(mod)
      assert message =~ ~r/Metadata field conflicts with resource field/
      assert message =~ ~r/title/
    end

    test "detects conflict with calculation name" do
      mod =
        resource(
          attrs: """
          attribute :value, :integer, public?: true
          """,
          calcs: """
          calculations do
            calculate :computed_value, :integer, expr(value * 2) do
              public? true
            end
          end
          """,
          meta: "metadata :computed_value, :string\n metadata :status, :string",
          projection: "show_metadata: [:computed_value, :status]"
        )

      assert {:error, message} = E.check(mod)
      assert message =~ ~r/Metadata field conflicts with resource field/
      assert message =~ ~r/computed_value/
    end

    test "detects conflict with mapped field name" do
      mod =
        resource(
          attrs: "attribute :external_name_1, :string, public?: true",
          surface_extra: ~s(field_names external_name_1: "externalName"),
          meta: "metadata :externalName, :string",
          projection: "show_metadata: [:externalName]"
        )

      assert {:error, message} = E.check(mod)
      assert message =~ ~r/Metadata field conflicts with resource field/
      assert message =~ ~r/externalName/
    end
  end

  describe "metadata field name validation - valid configurations" do
    test "allows valid metadata field names with no conflicts" do
      mod =
        resource(
          attrs: "attribute :title, :string, public?: true",
          meta:
            "metadata :processing_time, :integer\n metadata :cache_status, :string\n metadata :is_cached, :boolean",
          projection: "show_metadata: [:processing_time, :cache_status, :is_cached]"
        )

      assert :ok = E.check(mod)
    end

    test "skips validation when show_metadata is nil" do
      mod =
        resource(
          meta: "metadata :field_1, :string",
          projection: "show_metadata: nil"
        )

      assert :ok = E.check(mod)
    end

    test "skips validation when show_metadata is false" do
      mod =
        resource(
          meta: "metadata :field_1, :string",
          projection: "show_metadata: false"
        )

      assert :ok = E.check(mod)
    end

    test "skips validation when show_metadata is empty list" do
      mod =
        resource(
          meta: "metadata :field_1, :string",
          projection: "show_metadata: []"
        )

      assert :ok = E.check(mod)
    end
  end

  describe "metadata_field_names mapping" do
    test "allows invalid metadata field names with proper mapping" do
      mod =
        resource(
          meta: "metadata :field_1, :string\n metadata :is_valid?, :boolean",
          projection:
            ~s|show_metadata: [:field_1, :is_valid?], metadata_field_names: [field_1: "field1", is_valid?: "isValid"]|
        )

      assert :ok = E.check(mod)
    end

    test "detects conflicts even with metadata_field_names mapping" do
      mod =
        resource(
          attrs: "attribute :title, :string, public?: true",
          meta: "metadata :meta_title, :string",
          projection:
            ~s|show_metadata: [:meta_title], metadata_field_names: [meta_title: "title"]|
        )

      assert {:error, message} = E.check(mod)
      assert message =~ ~r/Mapped metadata field conflicts with resource field/
      assert message =~ ~r/meta_title/
      assert message =~ ~r/title/
    end

    test "detects invalid client names even after mapping" do
      mod =
        resource(
          meta: "metadata :field_a, :string",
          projection: ~s|show_metadata: [:field_a], metadata_field_names: [field_a: "field_1"]|
        )

      assert {:error, message} = E.check(mod)
      assert message =~ ~r/Invalid metadata field name/
      assert message =~ ~r/field_a/
      assert message =~ ~r/field_1/
    end
  end
end
