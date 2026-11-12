defmodule AshSurface.Ported.Rpc.E.TypedQueryFieldMappingCrossDomainSurfaceTest do
  @moduledoc """
  Behavioral counterparts of ash_typescript `rpc/typed_query_field_mapping_cross_domain_test.exs`
  tests 001, 002, 003 and 005. The reference reads mapped names out of generated TypeScript text
  (`addressLine1`, `isActive`, never `address_line_1` / `is_active?`) and then reads a created
  user back over `run_action`. ash_surface has no .ts; the same law is asserted on the real
  pipeline over the ported `User` resource (`field_names address_line_1: "addressLine1",
  is_active?: "isActive"`): mapped client names are selectable and shaped, the internal names
  never appear on the wire (the request parser itself accepts either spelling of an existing field; the output is where the mapping is enforced). No second-domain typed query exists in the shared
  fixtures (the typed-query fixture is private to `TqTodo`), so cross-domain is exercised through
  the one installed manifest that spans the ported domain's resources. Test 004 (schema type
  emitted once) is TypeScript text only and stays a loud skip.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported, as: P
  alias AshSurface.Ported.Rpc

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

  test "001 field mappings are applied to the selection of a typed-query-style read" do
    params = %{"action" => "list_users", "fields" => ["id", "addressLine1"]}
    assert {:ok, request} = Rpc.parse(params)
    assert :address_line_1 in request.select

    # the wire name of the same field is the mapped one
    assert Rpc.run(params, [user()])["data"] |> hd() |> Map.has_key?("addressLine1")
  end

  test "002 mapped calculation/attribute names appear in the fields, unmapped never do" do
    params = %{"action" => "list_users", "fields" => ["id", "addressLine1", "isActive"]}
    assert {:ok, _} = Rpc.parse(params)

    result = Rpc.run(params, [user()])
    assert %{"success" => true, "data" => [row]} = result
    assert Map.has_key?(row, "addressLine1")
    assert Map.has_key?(row, "isActive")
    refute Map.has_key?(row, "address_line_1")
    refute Map.has_key?(row, "isActive?")
    refute Map.has_key?(row, "is_active?")
  end

  test "003 result rows use mapped field names" do
    result =
      Rpc.run(%{"action" => "list_users", "fields" => ["id", "name", "addressLine1"]}, [user()])

    assert %{"success" => true, "data" => [row]} = result
    assert row["addressLine1"] == "123 Test Street"
    refute Map.has_key?(row, "address_line_1")
  end

  test "005 reading with mapped fields uses correct field mapping" do
    result =
      Rpc.run(
        %{
          "action" => "list_users",
          "resource" => "User",
          "input" => %{},
          "fields" => ["id", "name", "email", "addressLine1"]
        },
        [user()]
      )

    assert %{"success" => true, "data" => users} = result
    assert is_list(users)
    found = Enum.find(users, &(&1["id"] == user().id))
    assert found != nil
    assert found["name"] == "Test User"
    assert found["email"] == "test@example.com"
    assert found["addressLine1"] == "123 Test Street"
    refute Map.has_key?(found, "address_line_1")
  end
end
