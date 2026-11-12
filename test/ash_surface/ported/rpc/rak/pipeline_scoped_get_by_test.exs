defmodule AshSurface.Ported.Rpc.Rak.PipelineScopedGetByTest do
  @moduledoc """
  Lane RAK. Exact-value courts over (1) `Pipeline.parse_get_by` extra/missing field refusals,
  (2) the scoped-formatter sort/filter refusals (KD-10: stricter inside a `FieldName` scope),
  (3) tenant fragments of `IdentitySchema`/IR, and (4) the typed-query style cross-domain read
  shape. Real ported fixtures through the non-actuating pipeline; nothing is executed.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Compiler.IdentitySchema
  alias AshSurface.FieldName
  alias AshSurface.Ported, as: P
  alias AshSurface.Ported.Rpc, as: R

  describe "get_by field set" do
    test "an extra get_by field is refused, naming both the extra and the allowed" do
      params = %{
        "action" => "get_user_by_email",
        "getBy" => %{"email" => "a@b.c", "name" => "x"},
        "fields" => ["id"]
      }

      assert {:error, {:unexpected_get_by_fields, ["name"], ["email"]}} = R.parse(params)
    end

    test "a missing get_by field is refused, naming it" do
      params = %{
        "action" => "get_todo_by_user_and_status",
        "getBy" => %{"userId" => "u1"},
        "fields" => ["id"]
      }

      assert {:error, {:missing_get_by_fields, ["status"]}} = R.parse(params)
    end

    test "extra wins over missing when both occur" do
      params = %{
        "action" => "get_todo_by_user_and_status",
        "getBy" => %{"userId" => "u1", "title" => "t"},
        "fields" => ["id"]
      }

      assert {:error, {:unexpected_get_by_fields, ["title"], allowed}} = R.parse(params)
      assert Enum.sort(allowed) == ["status", "userId"]
    end

    test "exact fields parse to the internal-keyed map" do
      params = %{
        "action" => "get_todo_by_user_and_status",
        "getBy" => %{"userId" => "u1", "status" => "pending"},
        "fields" => ["id"]
      }

      assert {:ok, request} = R.parse(params)
      assert request.get_by == %{user_id: "u1", status: "pending"}
    end
  end

  describe "scoped formatter spellings (sort / filter / fields)" do
    test "inside a snake_case scope a camelCase sort field is refused" do
      FieldName.with_formatter(:snake_case, fn ->
        assert {:error, {:unknown_field, :due_date, _, []}} =
                 R.parse(%{"action" => "list_todos", "fields" => ["id"], "sort" => "dueDate"})

        assert {:ok, request} =
                 R.parse(%{"action" => "list_todos", "fields" => ["id"], "sort" => "due_date"})

        assert request.sort == "due_date"
      end)
    end

    test "the sort direction prefix does not hide the refusal" do
      FieldName.with_formatter(:snake_case, fn ->
        assert {:error, {:unknown_field, :due_date, _, []}} =
                 R.parse(%{"action" => "list_todos", "fields" => ["id"], "sort" => "-dueDate"})
      end)
    end

    test "inside a snake_case scope a camelCase filter key is refused, nested too" do
      FieldName.with_formatter(:snake_case, fn ->
        assert {:error, {:unknown_field, :due_date, _, []}} =
                 R.parse(%{
                   "action" => "list_todos",
                   "fields" => ["id"],
                   "filter" => %{"dueDate" => %{"eq" => "2020-01-01"}}
                 })

        assert {:error, {:unknown_field, :due_date, _, []}} =
                 R.parse(%{
                   "action" => "list_todos",
                   "fields" => ["id"],
                   "filter" => %{"and" => [%{"dueDate" => %{"eq" => "2020-01-01"}}]}
                 })
      end)
    end

    test "outside a scope camelCase sort and filter are accepted" do
      assert {:ok, _} =
               R.parse(%{
                 "action" => "list_todos",
                 "fields" => ["id"],
                 "sort" => "dueDate",
                 "filter" => %{"dueDate" => %{"eq" => "2020-01-01"}}
               })
    end
  end

  describe "non-scalar identity key kinds are not admitted" do
    test "every non-scalar kind (keyword included) yields no admitted identity" do
      kinds =
        ~w(map array union embedded struct keyword tuple resource embedded_resource typed_struct typed_map)

      for kind <- kinds do
        ids = [%{"name" => "x", "keys" => [%{"name" => "x", "type" => %{"kind" => kind}}]}]

        assert IdentitySchema.render_get_schema(ids, []) == {:error, :no_admitted_identities},
               "kind #{kind} must not be admitted"
      end

      ok = [%{"name" => "x", "keys" => [%{"name" => "x", "type" => %{"kind" => "string"}}]}]
      assert {:ok, %{"x" => _}} = IdentitySchema.render_get_schema(ok, [])
    end
  end

  describe "tenant fragments" do
    @required "z.string().min(1)"

    test "bare renderer is the required fragment" do
      assert IdentitySchema.render_tenant_schema() == {:ok, @required}
    end

    test "attribute and context strategies are tenant-bearing, optional by default" do
      for strategy <- ["attribute", "context", :attribute, :context] do
        assert IdentitySchema.render_tenant_schema(%{"strategy" => strategy}, false) ==
                 {:ok, @required <> ".optional()"}
      end
    end

    test "require_tenant_parameters (fact or default) makes it required; fact wins" do
      assert IdentitySchema.render_tenant_schema(%{"strategy" => "attribute"}, true) ==
               {:ok, @required}

      assert IdentitySchema.render_tenant_schema(
               %{"strategy" => "attribute", "require_tenant_parameters" => true},
               false
             ) == {:ok, @required}

      assert IdentitySchema.render_tenant_schema(
               %{"strategy" => "attribute", "require_tenant_parameters" => false},
               true
             ) == {:ok, @required <> ".optional()"}
    end

    test "global, unknown-strategy and non-map yield no tenant parameter" do
      assert IdentitySchema.render_tenant_schema(%{"strategy" => "attribute", "global?" => true}, true) ==
               {:ok, nil}

      assert IdentitySchema.render_tenant_schema(%{"strategy" => nil}, true) == {:ok, nil}
      assert IdentitySchema.render_tenant_schema(%{"strategy" => "other"}, true) == {:ok, nil}
      assert IdentitySchema.render_tenant_schema(nil, true) == {:ok, nil}
    end
  end

  describe "cross-domain typed-query style read (exact rows)" do
    defp user,
      do:
        struct(P.User, %{
          id: "11111111-1111-1111-1111-111111111111",
          name: "Test User",
          email: "test@example.com",
          address_line_1: "123 Test Street",
          is_active?: true,
          active: true
        })

    test "mapped selection is exact: only mapped wire keys with their values" do
      params = %{
        "action" => "list_users",
        "fields" => ["id", "addressLine1", "isActive"]
      }

      assert {:ok, request} = R.parse(params)
      assert Enum.sort(request.select) == [:address_line_1, :id]

      assert R.run(params, [user()]) == %{
               "success" => true,
               "data" => [
                 %{
                   "id" => "11111111-1111-1111-1111-111111111111",
                   "addressLine1" => "123 Test Street",
                   "isActive" => true
                 }
               ]
             }
    end
  end
end
