defmodule AshSurface.S1IShoutFormatter do
  @moduledoc false
  # Real hand-written custom field-name formatter (not a mock).
  def shout(name), do: name |> to_string() |> String.upcase()
end

defmodule AshSurface.S1IIdentitySelectionFieldNameTest do
  use ExUnit.Case, async: false

  alias AshSurface.Compiler.{IdentitySchema, SelectionSchema}
  alias AshSurface.FieldName
  alias AshSurface.ZodFixtures.HarnessExt
  alias AshSurface.ZodFixtures.IdentityTenant.Account

  defp key(n, k), do: %{"name" => n, "type" => %{"kind" => k}}
  defp ident(n, keys), do: %{"name" => n, "keys" => keys}

  describe "L1 identity" do
    test "real Ash identities render and execute under node+zod" do
      ids =
        for i <- Ash.Resource.Info.identities(Account) do
          ident(to_string(i.name), Enum.map(i.keys, &key(to_string(&1), "string")))
        end

      {:ok, m} = IdentitySchema.render_get_schema(ids, ["id"])
      {name, zod} = Enum.find(m, fn {_, z} -> not String.contains?(z, ", ") end)
      [k] = Regex.run(~r/^z\.object\(\{(\w+):/, zod, capture: :all_but_first)

      res =
        HarnessExt.run_fragment!(zod, [
          %{label: "ok", expect: true, payload: %{k => "x"}},
          %{label: "extra", expect: false, payload: %{k => "x", "z" => 1}}
        ])

      assert is_binary(name)
      assert Enum.map(res, & &1["success"]) == [true, false]
    end

    test "non-identifier key is quoted, not silently dropped; executes" do
      {:ok, m} = IdentitySchema.render_get_schema([ident("e", [key("e-mail", "string")])], [])
      assert m["e"] =~ ~s("e-mail")

      res =
        HarnessExt.run_fragment!(m["e"], [
          %{label: "ok", expect: true, payload: %{"e-mail" => "a"}},
          %{label: "bad", expect: false, payload: %{"x" => "a"}}
        ])

      assert Enum.map(res, & &1["success"]) == [true, false]
    end

    test "embedded/typed kinds and missing types are not z.unknown identities" do
      for kind <- ~w(embedded_resource typed_struct typed_map) do
        assert {:error, :no_admitted_identities} =
                 IdentitySchema.render_get_schema([ident("x", [key("x", kind)])], [])
      end

      assert {:error, :no_admitted_identities} =
               IdentitySchema.render_get_schema([ident("x", [%{"name" => "x"}])], [])
    end

    test "two identities aliasing primary_key are refused; atom pks normalize" do
      ids = [ident("a", [key("id", "uuid")]), ident("b", [key("id", "uuid")])]

      assert {:error, {:identity_name_collision, "primary_key", ["a", "b"]}} =
               IdentitySchema.render_get_schema(ids, [:id])

      assert {:ok, %{"primary_key" => _}} =
               IdentitySchema.render_get_schema([ident("a", [key("id", "uuid")])], [:id])
    end
  end

  describe "L6 selection" do
    test "invalid relationship refused before name access" do
      for bad <- [%{}, %{"name" => 1}, :x, %{"name" => ""}] do
        assert {:error, {:invalid_relationship, ^bad}} =
                 SelectionSchema.render_selection_schema(["a"], [], relationships: [bad])
      end
    end

    test "dotted relationship name refused" do
      assert {:error, {:relationship_name_ambiguous, "a.b"}} =
               SelectionSchema.render_selection_schema(["a"], [],
                 relationships: [%{"name" => "a.b"}]
               )
    end
  end

  describe "L8 field names" do
    test "parse_input/4 intersects with the admitted set" do
      _ = :password_hash
      assert {:ok, :password_hash} = FieldName.parse_input("passwordHash", :camel_case)
      assert :error = FieldName.parse_input("passwordHash", :camel_case, [:user_name])
      assert {:ok, :user_name} = FieldName.parse_input("userName", :camel_case, [:user_name])
    end

    test "custom formatter inverse derived from admitted set; /2 refuses" do
      fm = {AshSurface.S1IShoutFormatter, :shout}
      assert :error = FieldName.parse_input("ID", fm)
      assert {:ok, :id} = FieldName.parse_input("ID", fm, [:id, :name])
    end

    test "empty sort field refused" do
      assert :error = FieldName.parse_sort("-")
      assert {"-", "a"} = FieldName.parse_sort("-a")
      assert :error = FieldName.parse_input("", :snake_case)
    end

    test "leading underscore preserved; interior collision detected forward" do
      assert FieldName.compute(:_private, :camel_case) == "_private"
      assert {:ok, "_private"} = FieldName.format_checked(:_private, :camel_case)

      assert {:error, {:not_invertible, :a__b, "aB"}} =
               FieldName.format_checked(:a__b, :camel_case)

      assert {:error, _} = FieldName.client_to_internal([:a__b], :camel_case)
      assert {:ok, %{"aB" => :a_b}} = FieldName.client_to_internal([:a_b], :camel_case)
    end
  end
end
