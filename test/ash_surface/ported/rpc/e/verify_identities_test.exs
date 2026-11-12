Code.require_file("support/e.exs", __DIR__)

defmodule AshSurface.Ported.Rpc.E.VerifyIdentitiesTest do
  @moduledoc """
  Port of ash_typescript `rpc/verify_identities_test.exs` (12 tests).

  Reference: `rpc_action :update_resource, :update, identities: [...]` inside a domain
  `typescript_rpc` block, verified through `AshTypescript.Manifest.verify_for_domains/1`.
  ash_surface: `projection :update, name: :update_resource, identities: [...]` in the resource
  `surface` section, verified through `AshSurface.VerifierChecker.check_all_verifiers/1`
  (`AshSurface.Resource.Validator` identity law: named identities must exist, `:_primary_key`
  needs a primary key, the refusal lists the available identities).
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.E

  defp resource(opts) do
    name = E.uniq("T12.Ident")
    attrs = Keyword.get(opts, :attrs, "attribute :name, :string, public?: true")
    identities = Keyword.get(opts, :identities, "")
    projections = Keyword.fetch!(opts, :projections)
    layer = Keyword.get(opts, :layer, "Ash.DataLayer.Ets")
    pk = Keyword.get(opts, :pk, "uuid_primary_key :id")
    extra = Keyword.get(opts, :extra, "")

    actions =
      Keyword.get(opts, :actions, "defaults [:read, :destroy, create: [:name], update: [:name]]")

    source = """
    defmodule #{name} do
      use Ash.Resource,
        domain: nil,
        data_layer: #{layer},
        validate_domain_inclusion?: false,
        extensions: [AshSurface.Resource]

      #{extra}

      surface do
        type_name "#{name |> String.split(".") |> List.last()}"
        #{projections}
      end

      attributes do
        #{pk}
        #{attrs}
      end

      #{identities}

      actions do
        #{actions}
      end
    end
    """

    [mod] = E.compile!(source)
    mod
  end

  describe "identity validation - non-existent identities" do
    test "detects identity that doesn't exist on resource" do
      mod =
        resource(
          attrs: """
          attribute :name, :string, public?: true
          attribute :email, :string, public?: true
          """,
          identities: """
          identities do
            identity :email, [:email]
          end
          """,
          actions: "defaults [:read, :destroy, create: [:name, :email], update: [:name]]",
          projections:
            "projection :update, name: :update_resource, identities: [:non_existent_identity]"
        )

      assert {:error, message} = E.check(mod)
      assert message =~ ~r/Identity not found on resource/
      assert message =~ ~r/non_existent_identity/
      assert message =~ ~r/Available identities.*:email/
    end

    test "detects multiple non-existent identities" do
      mod =
        resource(
          projections: "projection :update, name: :update_resource, identities: [:foo, :bar]"
        )

      assert {:error, message} = E.check(mod)
      assert message =~ ~r/Identity not found on resource/
      assert message =~ ~r/:foo/
      assert message =~ ~r/:bar/
      assert message =~ ~r/No identities are defined on this resource/
    end

    test "shows available identities in error message" do
      mod =
        resource(
          attrs: """
          attribute :email, :string, public?: true
          attribute :username, :string, public?: true
          """,
          identities: """
          identities do
            identity :email, [:email]
            identity :username, [:username]
          end
          """,
          actions:
            "defaults [:read, :destroy, create: [:email, :username], update: [:email, :username]]",
          projections: "projection :update, name: :update_resource, identities: [:wrong_identity]"
        )

      assert {:error, message} = E.check(mod)

      assert message =~ ~r/Available identities.*:email.*:username/s or
               message =~ ~r/Available identities.*:username.*:email/s
    end

    test "detects :_primary_key used on resource without primary key" do
      # Ash.DataLayer.Simple supports update/destroy without a primary key (Ets does not).
      mod =
        resource(
          layer: "Ash.DataLayer.Simple",
          pk: "",
          extra: "resource do\n require_primary_key? false\n end",
          projections: "projection :update, name: :update_resource, identities: [:_primary_key]"
        )

      assert {:error, message} = E.check(mod)
      assert message =~ ~r/Resource has no primary key/
      assert message =~ ~r/:_primary_key identity is configured/
    end
  end

  describe "identity validation - valid configurations" do
    test "allows :_primary_key identity" do
      mod =
        resource(
          projections: "projection :update, name: :update_resource, identities: [:_primary_key]"
        )

      assert :ok = E.check(mod)
    end

    test "allows existing named identity" do
      mod =
        resource(
          attrs: "attribute :email, :string, public?: true",
          identities: "identities do\n identity :email, [:email]\n end",
          actions: "defaults [:read, :destroy, create: [:email], update: [:email]]",
          projections: "projection :update, name: :update_resource, identities: [:email]"
        )

      assert :ok = E.check(mod)
    end

    test "allows mix of :_primary_key and named identities" do
      mod =
        resource(
          attrs: """
          attribute :email, :string, public?: true
          attribute :username, :string, public?: true
          """,
          identities: """
          identities do
            identity :email, [:email]
            identity :username, [:username]
          end
          """,
          actions:
            "defaults [:read, :destroy, create: [:email, :username], update: [:email, :username]]",
          projections:
            "projection :update, name: :update_resource, identities: [:_primary_key, :email, :username]"
        )

      assert :ok = E.check(mod)
    end

    test "allows default identities (not explicitly specified)" do
      mod = resource(projections: "projection :update, name: :update_resource")

      assert :ok = E.check(mod)
    end

    test "allows empty identities list for actor-scoped actions" do
      mod = resource(projections: "projection :update, name: :update_resource, identities: []")

      assert :ok = E.check(mod)
    end
  end

  describe "identity validation - action type scoping" do
    test "skips validation for read actions" do
      mod = resource(projections: "projection :read, name: :list_resources")

      assert :ok = E.check(mod)
    end

    test "skips validation for create actions" do
      mod = resource(projections: "projection :create, name: :create_resource")

      assert :ok = E.check(mod)
    end

    test "validates identities for destroy actions" do
      mod =
        resource(
          projections: "projection :destroy, name: :destroy_resource, identities: [:non_existent]"
        )

      assert {:error, message} = E.check(mod)
      assert message =~ ~r/Identity not found on resource/
      assert message =~ ~r/non_existent/
    end
  end
end
