defmodule AshSurface.Ported.Rpc.B.LoadRestrictionsTest do
  @moduledoc """
  Counterpart of ash_typescript `rpc/load_restrictions_test` (pipeline-level describes).

  Changes: the reference declares `rpc_action ..., allowed_loads:/denied_loads:` on the
  domain and drives `Pipeline.parse_request/3` with an action name. ash_surface has no domain
  rpc DSL and no Pipeline; the same restriction specs are normalised by
  `AshSurface.RuntimeParity.RequestedFields.LoadRestrictions.normalize/1` and enforced during
  field selection by `RuntimeParity.RequestedFieldsProcessor` (real fixtures). The reference
  action names map to the restriction spec in `@specs`; `request.load` becomes the `load`
  element of the processor result; `{:error, {:load_not_allowed, paths}}` is the same
  tuple shape. The `run_action ...` describes live in `load_restrictions_gap_test.exs`.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Ported.RFP
  alias AshSurface.Ported.Todo
  alias AshSurface.RuntimeParity.RequestedFields.LoadRestrictions

  @specs %{
    "list_todos" => :none,
    "list_todos_allow_only_user" => {:allow, [:user]},
    "list_todos_allow_nested" => {:allow, [:user, comments: [:todo]]},
    "list_todos_deny_user" => {:deny, [:user]},
    "list_todos_deny_nested" => {:deny, [comments: [:todo]]},
    "list_todos_allow_nested_calc" => {:allow, [comments: [:weighted_score]]},
    "list_todos_deny_nested_calc" => {:deny, [comments: [:weighted_score]]}
  }

  # Mirrors Pipeline.parse_request/3 for a `:read` rpc action carrying the restriction spec.
  defp parse_request(%{"action" => name, "fields" => fields}) do
    restrictions = LoadRestrictions.normalize(Map.fetch!(@specs, name))

    case RFP.process(Todo, :read, fields, load_restrictions: restrictions) do
      {:ok, {_select, load, _template}} -> {:ok, %{load: load}}
      {:error, _} = error -> error
    end
  end

  describe "allowed_loads option - pipeline behavior" do
    test "allows loading fields that are in the allow list" do
      params = %{
        "action" => "list_todos_allow_only_user",
        "fields" => ["id", "title", %{"user" => ["id", "email"]}]
      }

      assert {:ok, request} = parse_request(params)
      assert request.load == [{:user, [:id, :email]}]
    end

    test "rejects loading fields that are not in the allow list" do
      params = %{
        "action" => "list_todos_allow_only_user",
        "fields" => ["id", "title", %{"comments" => ["id", "content"]}]
      }

      assert {:error, {:load_not_allowed, disallowed}} = parse_request(params)
      assert "comments" in disallowed
    end

    test "allows nested fields when explicitly allowed" do
      params = %{
        "action" => "list_todos_allow_nested",
        "fields" => ["id", %{"comments" => ["id", %{"todo" => ["id"]}]}]
      }

      assert {:ok, request} = parse_request(params)
      assert request.load != []
    end

    test "rejects nested fields when parent is allowed but nested is not" do
      params = %{
        "action" => "list_todos_allow_only_user",
        "fields" => ["id", %{"user" => ["id", %{"todos" => ["id"]}]}]
      }

      assert {:error, {:load_not_allowed, disallowed}} = parse_request(params)
      assert Enum.any?(disallowed, &String.contains?(&1, "todos"))
    end

    test "works with no loads requested" do
      params = %{"action" => "list_todos_allow_only_user", "fields" => ["id", "title"]}

      assert {:ok, request} = parse_request(params)
      assert request.load == []
    end
  end

  describe "denied_loads option - pipeline behavior" do
    test "allows loading fields that are not in the deny list" do
      params = %{
        "action" => "list_todos_deny_user",
        "fields" => ["id", "title", %{"comments" => ["id", "content"]}]
      }

      assert {:ok, request} = parse_request(params)
      assert request.load == [{:comments, [:id, :content]}]
    end

    test "rejects loading fields that are in the deny list" do
      params = %{
        "action" => "list_todos_deny_user",
        "fields" => ["id", "title", %{"user" => ["id", "email"]}]
      }

      assert {:error, {:load_denied, denied}} = parse_request(params)
      assert "user" in denied
    end

    test "rejects loading nested fields when parent is denied" do
      params = %{
        "action" => "list_todos_deny_user",
        "fields" => ["id", %{"user" => ["id", %{"todos" => ["id"]}]}]
      }

      assert {:error, {:load_denied, denied}} = parse_request(params)
      assert Enum.any?(denied, &String.contains?(&1, "user"))
    end

    test "allows parent field but denies nested field" do
      params = %{
        "action" => "list_todos_deny_nested",
        "fields" => ["id", %{"comments" => ["id", "content"]}]
      }

      assert {:ok, request} = parse_request(params)
      assert request.load != []
    end

    test "denies nested field explicitly" do
      params = %{
        "action" => "list_todos_deny_nested",
        "fields" => ["id", %{"comments" => ["id", %{"todo" => ["id"]}]}]
      }

      assert {:error, {:load_denied, denied}} = parse_request(params)
      assert Enum.any?(denied, &String.contains?(&1, "todo"))
    end

    test "works with no loads requested" do
      params = %{"action" => "list_todos_deny_user", "fields" => ["id", "title"]}

      assert {:ok, request} = parse_request(params)
      assert request.load == []
    end
  end

  describe "nested scalar loads - CVE-3210" do
    test "rejects a nested calculation on an allowed relationship" do
      params = %{
        "action" => "list_todos_allow_only_user",
        "fields" => ["id", %{"user" => ["id", "isActive"]}]
      }

      assert {:error, {:load_not_allowed, disallowed}} = parse_request(params)
      assert Enum.any?(disallowed, &String.contains?(&1, "is_active?"))
    end

    test "allows a nested calculation that is explicitly allowed" do
      params = %{
        "action" => "list_todos_allow_nested_calc",
        "fields" => ["id", %{"comments" => ["id", "weightedScore"]}]
      }

      assert {:ok, request} = parse_request(params)
      assert request.load == [{:comments, [:id, :weighted_score]}]
    end

    test "rejects a denied nested calculation" do
      params = %{
        "action" => "list_todos_deny_nested_calc",
        "fields" => ["id", %{"comments" => ["id", "weightedScore"]}]
      }

      assert {:error, {:load_denied, denied}} = parse_request(params)
      assert Enum.any?(denied, &String.contains?(&1, "weighted_score"))
    end

    test "allows attributes on a relationship whose calculation is denied" do
      params = %{
        "action" => "list_todos_deny_nested_calc",
        "fields" => ["id", %{"comments" => ["id", "content"]}]
      }

      assert {:ok, request} = parse_request(params)
      assert request.load == [{:comments, [:id, :content]}]
    end

    test "allows a nested calculation that is not denied" do
      params = %{
        "action" => "list_todos_deny_nested",
        "fields" => ["id", %{"comments" => ["id", "weightedScore"]}]
      }

      assert {:ok, request} = parse_request(params)
      assert request.load == [{:comments, [:id, :weighted_score]}]
    end

    test "rejects a nested embedded calculation with and without a query envelope" do
      plain = %{
        "action" => "list_todos_allow_nested",
        "fields" => ["id", %{"comments" => ["id", %{"commentMetadata" => ["displayCategory"]}]}]
      }

      envelope = %{
        "action" => "list_todos_allow_nested",
        "fields" => [
          "id",
          %{"comments" => %{"fields" => ["id", %{"commentMetadata" => ["displayCategory"]}]}}
        ]
      }

      assert {:error, {:load_not_allowed, plain_disallowed}} = parse_request(plain)
      assert {:error, {:load_not_allowed, envelope_disallowed}} = parse_request(envelope)

      assert Enum.any?(plain_disallowed, &String.contains?(&1, "comment_metadata"))
      assert Enum.any?(envelope_disallowed, &String.contains?(&1, "comment_metadata"))
    end

    test "rejects a nested union member load inside a query envelope" do
      params = %{
        "action" => "list_todos_allow_nested",
        "fields" => [
          "id",
          %{
            "comments" => %{
              "fields" => ["id", %{"authorInfo" => [%{"metadata" => ["displayCategory"]}]}]
            }
          }
        ]
      }

      assert {:error, {:load_not_allowed, disallowed}} = parse_request(params)
      assert Enum.any?(disallowed, &String.contains?(&1, "author_info"))
    end

    test "rejects a nested calculation inside a relationship query envelope" do
      params = %{
        "action" => "list_todos_allow_nested",
        "fields" => ["id", %{"comments" => %{"limit" => 2, "fields" => ["id", "weightedScore"]}}]
      }

      assert {:error, {:load_not_allowed, disallowed}} = parse_request(params)
      assert Enum.any?(disallowed, &String.contains?(&1, "weighted_score"))
    end
  end

  describe "neither option - default behavior" do
    test "allows all loads when no restriction is set" do
      params = %{
        "action" => "list_todos",
        "fields" => ["id", "title", %{"user" => ["id"]}, %{"comments" => ["id"]}]
      }

      assert {:ok, request} = parse_request(params)
      assert length(request.load) == 2
    end
  end

  describe "mutual exclusivity - verifier" do
    # Reference tests are implicit `assert true` compile-time notes. Counterpart: the
    # ash_surface DSL declares both options as mutually exclusive (resource.ex); asserted
    # here against the real projection schema docs.
    test "compiles successfully when only allowed_loads is set" do
      assert {:allow, [[:user]]} = LoadRestrictions.normalize({:allow, [:user]})
    end

    test "compiles successfully when only denied_loads is set" do
      assert {:deny, [[:user]]} = LoadRestrictions.normalize({:deny, [:user]})
    end

    test "compiles successfully when neither is set" do
      assert :none = LoadRestrictions.normalize(nil)
    end
  end

  describe "error messages" do
    test "load_not_allowed error contains field path" do
      params = %{
        "action" => "list_todos_allow_only_user",
        "fields" => ["id", %{"comments" => ["id"]}]
      }

      assert {:error, {:load_not_allowed, paths}} = parse_request(params)
      assert is_list(paths)
      assert Enum.all?(paths, &is_binary/1)
    end

    test "load_denied error contains field path" do
      params = %{
        "action" => "list_todos_deny_user",
        "fields" => ["id", %{"user" => ["id"]}]
      }

      assert {:error, {:load_denied, paths}} = parse_request(params)
      assert is_list(paths)
      assert Enum.all?(paths, &is_binary/1)
    end
  end
end
