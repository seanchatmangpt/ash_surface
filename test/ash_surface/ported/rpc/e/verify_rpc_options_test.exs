Code.require_file("support/e.exs", __DIR__)

defmodule AshSurface.Ported.Rpc.E.VerifyRpcOptionsTest do
  @moduledoc """
  Port of ash_typescript `rpc/verify_rpc_options_test.exs` (7 tests): `show_metadata` and
  `allowed_loads`/`denied_loads` existence checks.

  Reference: `rpc_action ... show_metadata:/allowed_loads:/denied_loads:` in a domain
  `typescript_rpc` block. ash_surface: `projection ...` with the same options in the resource
  `surface` section; `AshSurface.Resource.Validator` refuses unknown metadata names and
  load paths that are not public relationships/calculations/aggregates (nested through
  relationship destinations and embedded attributes; plain attributes never).
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.E

  @fixtures """
  defmodule T12.VerifyRpcOptions.Settings do
    use Ash.Resource, data_layer: :embedded

    attributes do
      attribute :theme, :string, public?: true
    end

    calculations do
      calculate :display_theme, :string, expr(theme), public?: true
    end
  end

  defmodule T12.VerifyRpcOptions.Item do
    use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
      attribute :source_id, :uuid, public?: true
    end

    actions do
      defaults [:read]
    end
  end
  """

  setup_all do
    E.compile!(@fixtures)
    :ok
  end

  defp source(projection) do
    name = E.uniq("T12.VerifyRpcOptions.Source")

    [mod] =
      E.compile!("""
      defmodule #{name} do
        use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Ets,
          validate_domain_inclusion?: false, extensions: [AshSurface.Resource]

        surface do
          type_name "VerifyOptionsSource"
          #{projection}
        end

        attributes do
          uuid_primary_key :id
          attribute :name, :string, public?: true
          attribute :settings, T12.VerifyRpcOptions.Settings, public?: true
        end

        relationships do
          has_many :items, T12.VerifyRpcOptions.Item,
            destination_attribute: :source_id,
            public?: true
        end

        calculations do
          calculate :display_name, :string, expr(name), public?: true
        end

        aggregates do
          count :items_count, :items, public?: true
        end

        actions do
          defaults [:read]

          read :read_with_meta do
            metadata :total_count, :integer
            metadata :cache_status, :string
          end
        end
      end
      """)

    mod
  end

  describe "show_metadata validation" do
    test "rejects metadata fields the action does not define" do
      mod =
        source(
          "projection :read_with_meta, name: :list_with_meta, show_metadata: [:total_count, :has_more]"
        )

      assert {:error, message} = E.check(mod)
      assert message =~ "show_metadata contains unknown metadata fields"
      assert message =~ ":has_more"
      assert message =~ "list_with_meta"
    end

    test "accepts metadata fields the action defines" do
      mod =
        source(
          "projection :read_with_meta, name: :list_with_meta_ok, show_metadata: [:total_count, :cache_status]"
        )

      assert :ok = E.check(mod)
    end
  end

  describe "allowed_loads / denied_loads validation" do
    test "rejects load paths that don't exist on the resource" do
      mod = source("projection :read, name: :list_bad_loads, allowed_loads: [:nonexistent]")

      assert {:error, message} = E.check(mod)
      assert message =~ "allowed_loads contains invalid load paths"
      assert message =~ "nonexistent"
    end

    test "rejects nested load paths that don't exist on the relationship destination" do
      mod = source("projection :read, name: :list_bad_nested, denied_loads: [items: [:bogus]]")

      assert {:error, message} = E.check(mod)
      assert message =~ "denied_loads contains invalid load paths"
      assert message =~ "items.bogus"
    end

    test "rejects plain attributes (never load paths)" do
      mod = source("projection :read, name: :list_attr_load, allowed_loads: [:name]")

      assert {:error, message} = E.check(mod)
      assert message =~ "allowed_loads contains invalid load paths"
      assert message =~ "name"
    end

    test "rejects unknown fields nested under an embedded attribute" do
      mod =
        source("projection :read, name: :list_bad_embedded, allowed_loads: [settings: [:nope]]")

      assert {:error, message} = E.check(mod)
      assert message =~ "allowed_loads contains invalid load paths"
      assert message =~ "settings.nope"
    end

    test "accepts relationships, calculations, aggregates, and valid nested paths" do
      mod =
        source("""
        projection :read,
          name: :list_good_loads,
          allowed_loads: [:display_name, :items_count, settings: [:display_theme], items: []]
        """)

      assert :ok = E.check(mod)
    end
  end
end
