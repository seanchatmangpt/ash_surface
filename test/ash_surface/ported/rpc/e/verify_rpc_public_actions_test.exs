Code.require_file("support/e.exs", __DIR__)

defmodule AshSurface.Ported.Rpc.E.VerifyRpcPublicActionsTest do
  @moduledoc """
  Port of ash_typescript `rpc/verify_rpc_public_actions_test.exs` (8 tests): the `not public?`
  checks of `VerifyRpc`.

  Reference: inline domains with `rpc_action`/`typed_query` over private actions, verified via
  `check_all_verifiers/1`. ash_surface: `projection`/`typed_query` in the resource `surface`
  section, verified via `AshSurface.VerifierChecker`. Messages carry the reference phrases
  ("not `public?`", the action name and the projection/typed-query name).
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.E

  @fixtures """
  defmodule T12.PublicActions.RelDestNonPublicRead do
    use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false, extensions: [AshSurface.Resource]

    surface do
      type_name "RelDestNonPublicRead"
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
    end

    actions do
      read :read do
        primary? true
        public? false
      end
    end
  end

  defmodule T12.PublicActions.RelSourceNonPublicDest do
    use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false, extensions: [AshSurface.Resource]

    surface do
      type_name "RelSourceNonPublicDest"
      projection :read, name: :list_src
    end

    attributes do
      uuid_primary_key :id
    end

    relationships do
      belongs_to :dest, T12.PublicActions.RelDestNonPublicRead, public?: true
    end

    actions do
      defaults [:read]
    end
  end

  defmodule T12.PublicActions.RelDestPublicRead do
    use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false, extensions: [AshSurface.Resource]

    surface do
      type_name "RelDestPublicRead"
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
    end

    actions do
      read :read do
        primary? true
        public? true
      end
    end
  end

  defmodule T12.PublicActions.RelSourcePublicDest do
    use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false, extensions: [AshSurface.Resource]

    surface do
      type_name "RelSourcePublicDest"
      projection :read, name: :list_src
    end

    attributes do
      uuid_primary_key :id
    end

    relationships do
      belongs_to :dest, T12.PublicActions.RelDestPublicRead, public?: true
    end

    actions do
      defaults [:read]
    end
  end

  # No AshSurface.Resource extension and a non-public primary read: the verifier can only
  # return :ok if it really skips destinations outside the surface.
  defmodule T12.PublicActions.PlainDest do
    use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    attributes do
      uuid_primary_key :id
    end

    actions do
      read :read do
        primary? true
        public? false
      end
    end
  end

  defmodule T12.PublicActions.RelSourcePlainDest do
    use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false, extensions: [AshSurface.Resource]

    surface do
      type_name "RelSourcePlainDest"
      projection :read, name: :list_src
    end

    attributes do
      uuid_primary_key :id
    end

    relationships do
      belongs_to :dest, T12.PublicActions.PlainDest, public?: true
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

  defp resource(surface, actions) do
    name = E.uniq("T12.PublicActions.Res")

    [mod] =
      E.compile!("""
      defmodule #{name} do
        use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Ets,
          validate_domain_inclusion?: false, extensions: [AshSurface.Resource]

        surface do
          type_name "PublicActionsRes"
          #{surface}
        end

        attributes do
          uuid_primary_key :id
          attribute :name, :string, public?: true
        end

        actions do
          #{actions}
        end
      end
      """)

    mod
  end

  describe "rpc actions reject non-public destination actions" do
    test "returns error when a projection references a non-`public?` action" do
      mod =
        resource("projection :private_read, name: :list_private", """
        defaults [:read]

        read :private_read do
          public? false
        end
        """)

      assert {:error, message} = E.check(mod)
      assert message =~ "not `public?`"
      assert message =~ "private_read"
      assert message =~ "list_private"
    end

    test "passes when a projection references a `public?` action" do
      mod =
        resource("projection :public_read, name: :list_public", """
        read :public_read do
          public? true
        end
        """)

      assert :ok = E.check(mod)
    end

    test "returns error when read_action override is not `public?`" do
      mod =
        resource(
          "projection :update_thing, name: :update_thing, read_action: :private_lookup",
          """
          defaults [:read]

          read :private_lookup do
            public? false
          end

          update :update_thing do
            public? true
            require_atomic? false
          end
          """
        )

      assert {:error, message} = E.check(mod)
      assert message =~ "not `public?`"
      assert message =~ "private_lookup"
      assert message =~ "read_action"
    end
  end

  describe "relationship destination read actions must be public" do
    test "returns error when relationship destination has non-public read action" do
      assert {:error, message} = E.check(T12.PublicActions.RelSourceNonPublicDest)
      assert message =~ "not `public?`"
      assert message =~ "dest"
      assert message =~ "RelDestNonPublicRead"
    end

    test "passes when relationship destination has public read action" do
      assert :ok = E.check(T12.PublicActions.RelSourcePublicDest)
    end

    test "skips relationships to non-surface destinations" do
      assert :ok = E.check(T12.PublicActions.RelSourcePlainDest)
    end
  end

  describe "typed queries reject non-public actions" do
    test "returns error when typed query references a non-public action" do
      mod =
        resource(
          """
          typed_query :my_query, :private_read do
            fields [:id, :name]
          end
          """,
          """
          defaults [:read]

          read :private_read do
            public? false
          end
          """
        )

      assert {:error, message} = E.check(mod)
      assert message =~ "not `public?`"
      assert message =~ "private_read"
      assert message =~ "my_query"
    end

    test "passes when typed query references a public action" do
      mod =
        resource(
          """
          typed_query :my_query, :public_read do
            fields [:id, :name]
          end
          """,
          """
          read :public_read do
            public? true
          end
          """
        )

      assert :ok = E.check(mod)
    end
  end
end
