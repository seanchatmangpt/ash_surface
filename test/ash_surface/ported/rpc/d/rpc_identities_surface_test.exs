defmodule AshSurface.Ported.Rpc.D.RpcIdentitiesSurfaceTest do
  @moduledoc """
  Surface port of the runtime half of `rpc_identities_test.exs`. Identity resolution is the pure
  half of the reference executor (`Pipeline.resolve_identity/1`: validates the client identity
  against the entry's `identities` and returns the equality filter; no query is built). Where
  the reference asserts the updated record, the record is a caller-built `User` struct fed
  through result processing. Cases that need a data layer (a non-matching email returning
  not-found, an operator-map injection leaving the stored record untouched, deleting the actor)
  are asserted at the filter level (the exact equality filter, or the typed refusal that
  precludes execution); the remaining record-existence facts are loud skips in
  `rpc_identities_gap_test.exs`. TypeScript-text tests are loud skips there too.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.{Rpc, User}
  alias AshSurface.RuntimeParity.Rpc.Pipeline

  @user_id "11111111-1111-1111-1111-111111111111"
  @email "identity-test-1@example.com"

  defp user(attrs \\ []),
    do:
      struct(
        User,
        Keyword.merge([id: @user_id, name: "Identity Test User", email: @email], attrs)
      )

  # parse + identity resolution; returns {:ok, filter} or the failure envelope
  defp resolve(params) do
    {:ok, request} = Rpc.parse(params)

    case Pipeline.resolve_identity(request) do
      {:ok, filter} -> {:ok, filter}
      {:error, reason} -> Pipeline.error_response(reason)
    end
  end

  defp single_error(result) do
    assert %{"success" => false, "errors" => [error]} = result
    error
  end

  describe "identity-based update actions" do
    test "update_user uses primary key identity directly" do
      params = %{
        "action" => "update_user",
        "identity" => @user_id,
        "input" => %{"name" => "Updated via PK"},
        "fields" => ["id", "name"]
      }

      assert {:ok, [id: @user_id]} = resolve(params)

      result = Rpc.run(params, user(name: "Updated via PK"))
      assert %{"success" => true, "data" => data} = result
      assert data["name"] == "Updated via PK"
      assert data["id"] == @user_id
    end

    test "update_user_by_identity can use primary key" do
      params = %{
        "action" => "update_user_by_identity",
        "identity" => @user_id,
        "input" => %{"name" => "Updated via PK in multi-identity"},
        "fields" => ["id", "name"]
      }

      assert {:ok, [id: @user_id]} = resolve(params)

      assert %{"success" => true, "data" => data} =
               Rpc.run(params, user(name: "Updated via PK in multi-identity"))

      assert data["name"] == "Updated via PK in multi-identity"
      assert data["id"] == @user_id
    end

    test "update_user_by_identity can use email identity" do
      params = %{
        "action" => "update_user_by_identity",
        "identity" => %{"email" => @email},
        "input" => %{"name" => "Updated via Email"},
        "fields" => ["id", "name", "email"]
      }

      assert {:ok, [email: @email]} = resolve(params)

      assert %{"success" => true, "data" => data} =
               Rpc.run(params, user(name: "Updated via Email"))

      assert data["name"] == "Updated via Email"
      assert data["email"] == @email
    end

    test "update_user_by_email only accepts email identity" do
      params = %{
        "action" => "update_user_by_email",
        "identity" => %{"email" => @email},
        "input" => %{"name" => "Updated by Email Only"},
        "fields" => ["id", "name", "email"]
      }

      assert {:ok, [email: @email]} = resolve(params)

      assert %{"success" => true, "data" => data} =
               Rpc.run(params, user(name: "Updated by Email Only"))

      assert data["name"] == "Updated by Email Only"
      assert data["email"] == @email
    end

    test "update_user_by_email with non-matching email returns not found" do
      # Identity resolution admits the (well-formed) identity as an equality filter on the
      # given email; the not-found outcome itself needs a data layer. The refusal envelope the
      # executor would return for a missing record is fed through the formatter.
      params = %{
        "action" => "update_user_by_email",
        "identity" => %{"email" => "nonexistent@example.com"},
        "input" => %{"name" => "Should Fail"},
        "fields" => ["id", "name"]
      }

      assert {:ok, [email: "nonexistent@example.com"]} = resolve(params)

      assert %{"success" => false} =
               Rpc.run(params, {:error, Ash.Error.to_ash_error(%Ash.Error.Query.NotFound{})})
    end

    test "update_user_by_email with wrong identity field name returns invalid_identity error" do
      error =
        single_error(
          resolve(%{
            "action" => "update_user_by_email",
            "identity" => %{"emai" => "test@example.com"},
            "input" => %{"name" => "Should Fail"},
            "fields" => ["id", "name"]
          })
        )

      assert error["type"] == "invalid_identity"
      assert error["shortMessage"] == "Invalid identity"
    end

    test "update_user_by_email with extra identity fields still matches valid identity" do
      params = %{
        "action" => "update_user_by_email",
        "identity" => %{"email" => @email, "extraField" => "value"},
        "input" => %{"name" => "Updated with extra fields"},
        "fields" => ["id", "name"]
      }

      assert {:ok, [email: @email]} = resolve(params)

      assert %{"success" => true, "data" => data} =
               Rpc.run(params, user(name: "Updated with extra fields"))

      assert data["name"] == "Updated with extra fields"
    end

    test "update_user_by_identity with completely wrong fields returns invalid_identity error" do
      error =
        single_error(
          resolve(%{
            "action" => "update_user_by_identity",
            "identity" => %{"wrongField" => "value"},
            "input" => %{"name" => "Should Fail"},
            "fields" => ["id", "name"]
          })
        )

      assert error["type"] == "invalid_identity"
      assert is_map(error["details"])
    end

    test "invalid_identity error message uses client-facing field names" do
      error =
        single_error(
          resolve(%{
            "action" => "update_user_by_email",
            "identity" => %{"emai" => "test@example.com"},
            "input" => %{"name" => "Should Fail"},
            "fields" => ["id", "name"]
          })
        )

      assert error["type"] == "invalid_identity"
      assert error["vars"]["expectedKeys"] == "email"
      assert error["vars"]["providedKeys"] == "emai"
      assert error["message"] =~ "%{providedKeys}"
      assert error["message"] =~ "%{expectedKeys}"
      assert "email" in error["details"]["expectedKeys"]
      assert "emai" in error["details"]["providedKeys"]
    end

    test "update action without identity when identity is required returns missing_identity error" do
      error =
        single_error(
          resolve(%{
            "action" => "update_user",
            "input" => %{"name" => "Should Fail Without Identity"},
            "fields" => ["id", "name"]
          })
        )

      assert error["type"] == "missing_identity"
      assert error["shortMessage"] == "Missing identity"
      assert error["message"] =~ "Identity is required"
      assert error["message"] =~ "id"
      assert is_map(error["details"])
      assert is_list(error["details"]["expectedKeys"])
    end

    test "update action with empty map identity returns missing_identity error" do
      error =
        single_error(
          resolve(%{
            "action" => "update_user_by_email",
            "identity" => %{},
            "input" => %{"name" => "Should Fail"},
            "fields" => ["id", "name"]
          })
        )

      assert error["type"] in ["missing_identity", "invalid_identity"]
    end

    test "destroy action without identity when identity is required returns missing_identity error" do
      error = single_error(resolve(%{"action" => "destroy_user", "fields" => ["id"]}))

      assert error["type"] == "missing_identity"
      assert error["shortMessage"] == "Missing identity"
    end

    test "invalid_identity error applies field_names mapping for client-facing names" do
      error =
        single_error(
          resolve(%{
            "action" => "update_subscription_by_user_status",
            "identity" => %{"userId" => @user_id, "isActiv" => true},
            "input" => %{"plan" => "basic"},
            "fields" => ["id", "plan"]
          })
        )

      assert error["type"] == "invalid_identity"
      assert error["vars"]["expectedKeys"] == "userId, isActive"
      assert error["vars"]["providedKeys"] == "userId, isActiv"
      assert "userId" in error["details"]["expectedKeys"]
      assert "isActive" in error["details"]["expectedKeys"]
      refute "isActive?" in error["details"]["expectedKeys"]
      refute "is_active?" in error["details"]["expectedKeys"]
    end

    test "update rejects an operator map as a named identity value (filter injection)" do
      # The refusal happens before any filter is built, so no query (and no stored record)
      # can be affected: the typed refusal itself is the observable state.
      error =
        single_error(
          resolve(%{
            "action" => "update_user_by_email",
            "identity" => %{"email" => %{"greater_than" => ""}},
            "input" => %{"name" => "Injected"},
            "fields" => ["id", "name", "email"]
          })
        )

      assert error["type"] == "invalid_identity"
    end

    test "update rejects a non-scalar primary key identity value" do
      error =
        single_error(
          resolve(%{
            "action" => "update_user",
            "identity" => [@user_id],
            "input" => %{"name" => "Injected PK"},
            "fields" => ["id", "name"]
          })
        )

      assert error["type"] == "invalid_identity"
    end
  end

  describe "actor-scoped actions (no identity)" do
    test "update_me works without identity when actor is set" do
      params = %{
        "action" => "update_me",
        "input" => %{"name" => "Updated My Name"},
        "fields" => ["id", "name"]
      }

      assert {:ok, nil} = resolve(params)
      assert {:ok, request} = Rpc.parse(params, actor: user())
      assert request.actor.id == @user_id

      assert %{"success" => true, "data" => data} =
               Rpc.run(params, user(name: "Updated My Name"), actor: user())

      assert data["name"] == "Updated My Name"
      assert data["id"] == @user_id
    end

    test "destroy_me works without identity when actor is set" do
      params = %{"action" => "destroy_me", "fields" => ["id"]}

      assert {:ok, nil} = resolve(params)

      assert %{"success" => true, "data" => data} = Rpc.run(params, user(), actor: user())
      assert data["id"] == @user_id
    end
  end
end
