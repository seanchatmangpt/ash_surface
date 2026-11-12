defmodule AshSurface.Ported.Rpc.D.StructArgumentTest do
  @moduledoc """
  Port of ash_typescript `struct_argument_test.exs`. `get_ts_input_type` (TS text) maps to the
  compiler's `TypeFacts.analyze/2`, which classifies a struct argument with `instance_of`
  pointing at an Ash resource as a resource reference (input shape, no metadata) and arrays
  of it as `array`. Reachability is Ash's own manifest walker; struct-argument resource
  discovery is asserted on the real manifest's action inputs and `TypeFacts.embedded_resources/1`.
  TS-text-only tests are loud skips in `struct_argument_gap_test.exs`; the `InputFormatter`
  test is ported against `Rpc.InputFormatter`.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Compiler.TypeFacts
  alias AshSurface.Ported.{RFP, Rpc, Todo, TodoMetadata, User}
  alias AshSurface.RuntimeParity.Rpc.{InputFormatter, Support}

  describe "type facts for struct arguments" do
    test "struct with instance_of pointing to Ash resource is a resource reference" do
      facts = TypeFacts.analyze(Ash.Type.Struct, instance_of: User)
      assert facts.kind == "resource"
      assert facts.definition["type"]["instance_of"] == inspect(User)
    end

    test "array of struct with instance_of is an array of resource references" do
      facts = TypeFacts.analyze({:array, Ash.Type.Struct}, items: [instance_of: User])
      assert facts.kind == "array"
      assert facts.definition["type"]["items"]["type"]["instance_of"] == inspect(User)
    end

    test "struct without instance_of falls back to the plain struct kind" do
      facts = TypeFacts.analyze(Ash.Type.Struct, [])
      assert facts.kind == "struct"
    end

    test "embedded resources keep the embedded_resource kind" do
      facts = TypeFacts.analyze(TodoMetadata, [])
      assert facts.kind == "embedded_resource"
    end
  end

  describe "struct argument casting" do
    test "cast_map_to_struct creates struct with valid fields only" do
      input_map = %{
        name: "Test User",
        email: "test@example.com",
        invalid_field: "should be ignored"
      }

      struct_keys = User.__struct__() |> Map.keys() |> MapSet.new()

      valid_attrs =
        input_map
        |> Enum.filter(fn {key, _value} -> MapSet.member?(struct_keys, key) end)
        |> Enum.into(%{})

      result = struct(User, valid_attrs)

      assert %User{} = result
      assert result.name == "Test User"
      assert result.email == "test@example.com"
      refute Map.has_key?(Map.from_struct(result), :invalid_field)
    end
  end

  describe "Reachability discovers struct argument resources" do
    test "reachability discovers resources used as struct arguments" do
      {reachable, _} = Ash.Info.Manifest.Generator.Reachability.find_reachable([Todo])
      assert is_list(reachable)
      assert User in reachable
    end

    test "struct argument resources are found on the real manifest's action inputs" do
      actions = RFP.manifest().action_lookup

      for name <- [:assign_to_user, :assign_to_users] do
        action = Map.fetch!(actions, {Todo, name})

        assert Enum.any?(
                 action.inputs,
                 &(&1.type.module in [Ash.Type.Struct, :array] or
                     &1.type.kind in [:resource, :array])
               )
      end

      assert Ash.Resource.Info.action(Todo, :assign_to_user).arguments
             |> Enum.any?(&(&1.constraints[:instance_of] == User))
    end

    test "TodoMetadata is reachable via the compiler's embedded closure" do
      closure =
        Todo
        |> Ash.Resource.Info.public_attributes()
        |> Enum.map(&TypeFacts.analyze(&1.type, &1.constraints).definition)
        |> TypeFacts.embedded_resources()

      assert Map.has_key?(closure, inspect(TodoMetadata))
    end
  end

  describe "InputFormatter struct argument casting" do
    test "format processes input data for User resource" do
      Rpc.install()

      assert {:ok, formatted} =
               InputFormatter.format(
                 %{"name" => "Test User", "email" => "test@example.com"},
                 User,
                 :create,
                 :camel_case,
                 Support.resource_lookup()
               )

      assert is_map(formatted)
      assert formatted[:name] == "Test User"
      assert formatted[:email] == "test@example.com"
    end
  end

  describe "struct argument behaviour pinned beyond kind" do
    test "a resource struct reference names its resource and is flagged resource?" do
      type = TypeFacts.analyze(Ash.Type.Struct, instance_of: User).definition["type"]
      assert type["resource"] == inspect(User)
      assert type["resource?"] == true
    end

    test "a struct whose instance_of is not a resource is flagged resource? false" do
      facts = TypeFacts.analyze(Ash.Type.Struct, instance_of: URI)
      assert facts.kind == "struct"
      assert facts.definition["type"]["instance_of"] == "URI"
      assert facts.definition["type"]["resource?"] == false
    end

    test "array of resource structs keeps the item kind resource and the item resource" do
      items =
        TypeFacts.analyze({:array, Ash.Type.Struct}, items: [instance_of: User]).definition[
          "type"
        ]["items"]["type"]

      assert items["kind"] == "resource"
      assert items["resource?"] == true
    end

    test "InputFormatter converts nested struct-argument keys to atoms and passes unknown keys" do
      Rpc.install()

      assert {:ok, formatted} =
               InputFormatter.format(
                 %{"assignee" => %{"id" => "x", "name" => "n"}, "bogusKey" => 1},
                 Todo,
                 :assign_to_user,
                 :camel_case,
                 Support.resource_lookup()
               )

      assert formatted == %{"bogusKey" => 1, assignee: %{id: "x", name: "n"}}
    end

    test "InputFormatter maps every element of an array of struct arguments" do
      Rpc.install()

      assert {:ok, %{assignees: [%{id: "1", name: "a"}, %{id: "2", name: "b"}]}} =
               InputFormatter.format(
                 %{
                   "assignees" => [
                     %{"id" => "1", "name" => "a"},
                     %{"id" => "2", "name" => "b"}
                   ]
                 },
                 Todo,
                 :assign_to_users,
                 :camel_case,
                 Support.resource_lookup()
               )
    end

    test "InputFormatter maps camelCase accepted attributes to snake_case internal names" do
      Rpc.install()

      assert {:ok, %{address_line_1: "1 Main"}} =
               InputFormatter.format(
                 %{"addressLine1" => "1 Main"},
                 User,
                 :create,
                 :camel_case,
                 Support.resource_lookup()
               )
    end
  end

  describe "struct argument facts pinned for embedded closure and field_names" do
    test "an embedded resource type is flagged resource? true and names its module" do
      type = TypeFacts.analyze(TodoMetadata, []).definition["type"]
      assert type["resource?"] == true
      assert type["resource"] == inspect(TodoMetadata)
      assert type["module"] == inspect(TodoMetadata)
    end

    test "a struct argument's resource closure includes every public attribute, even non-writable" do
      defn = TypeFacts.analyze(Ash.Type.Struct, instance_of: User).definition
      names = TypeFacts.embedded_resources([defn])[inspect(User)] |> Enum.map(& &1["name"])

      assert "id" in names

      assert Enum.sort(names) ==
               ["active", "addressLine1", "email", "id", "is_super_admin", "name"]
    end

    test "a map NewType with typescript_field_names exposes its wire-name map" do
      type = TypeFacts.analyze(AshSurface.Ported.RouteSettings, []).definition["type"]
      assert type["kind"] == "map"
      assert type["field_names"] == %{"enabled?" => "enabled", "level_1" => "level1"}
    end
  end
end
