defmodule AshSurface.Ported.Rpc.E.StructFieldFilteringSurfaceTest do
  @moduledoc """
  Port of ash_typescript `rpc/struct_field_filtering_test.exs` (6 tests) onto
  `RuntimeParity.Rpc.ResultProcessor` with real `StructFilterUser` structs (no data layer).
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.StructFilterUser, as: User
  alias AshSurface.RuntimeParity.Rpc.{ResultProcessor, Support}

  setup_all do
    AshSurface.Ported.Rpc.install()
    lookups = AshSurface.RuntimeParity.RequestedFields.Compat.resource_lookup(Support.handle())
    %{lookups: lookups}
  end

  defp user(attrs) do
    struct(
      User,
      Map.merge(
        %{
          id: Ash.UUID.generate(),
          name: "Test User",
          email: "test@example.com",
          secret: "secret_value",
          internal_notes: "internal_notes"
        },
        attrs
      )
    )
  end

  test "001 filters struct fields to only public attributes when no selection is specified" do
    result = ResultProcessor.normalize_value_for_json(user(%{}))

    assert Map.has_key?(result, :id)
    assert Map.has_key?(result, :name)
    assert Map.has_key?(result, :email)
    refute Map.has_key?(result, :secret)
    refute Map.has_key?(result, :internal_notes)
  end

  test "002 respects field selection when processing struct fields", %{lookups: l} do
    result = ResultProcessor.process(user(%{}), [:name], User, l)

    assert Map.has_key?(result, :name)
    refute Map.has_key?(result, :id)
    refute Map.has_key?(result, :email)
    refute Map.has_key?(result, :secret)
  end

  test "003 handles nested struct fields by filtering to public attributes", %{lookups: l} do
    record = %{
      id: Ash.UUID.generate(),
      name: "Main User",
      email: "main@example.com",
      self_struct: user(%{name: "Nested User", email: "nested@example.com"})
    }

    result = ResultProcessor.process(record, [:id, :name, :email, :self_struct], User, l)

    assert Map.has_key?(result, :id)
    assert Map.has_key?(result, :name)
    assert Map.has_key?(result, :email)
    assert is_map(result[:self_struct])
    assert Map.has_key?(result[:self_struct], :id)
    assert Map.has_key?(result[:self_struct], :name)
    assert Map.has_key?(result[:self_struct], :email)
    refute Map.has_key?(result[:self_struct], :secret)
    refute Map.has_key?(result[:self_struct], :internal_notes)
  end

  test "004 supports field selection on nested struct fields", %{lookups: l} do
    record = %{
      id: Ash.UUID.generate(),
      name: "Main User",
      self_struct: user(%{name: "Nested User"})
    }

    result = ResultProcessor.process(record, [:id, :name, {:self_struct, [:name]}], User, l)

    assert Map.has_key?(result, :id)
    assert Map.has_key?(result, :name)
    assert is_map(result[:self_struct])
    assert Map.has_key?(result[:self_struct], :name)
    refute Map.has_key?(result[:self_struct], :id)
    refute Map.has_key?(result[:self_struct], :email)
    refute Map.has_key?(result[:self_struct], :secret)
  end

  test "005 handles arrays of structs by filtering each to public attributes", %{lookups: l} do
    rows = [user(%{name: "User 1"}), user(%{name: "User 2"})]
    result = ResultProcessor.process(rows, [], User, l)

    assert length(result) == 2

    Enum.each(result, fn u ->
      assert Map.has_key?(u, :id)
      assert Map.has_key?(u, :name)
      assert Map.has_key?(u, :email)
      refute Map.has_key?(u, :secret)
      refute Map.has_key?(u, :internal_notes)
    end)
  end

  test "006 handles arrays of structs with field selection", %{lookups: l} do
    result = ResultProcessor.process([user(%{name: "User 1"})], [:name], User, l)

    assert [u] = result
    assert Map.has_key?(u, :name)
    refute Map.has_key?(u, :id)
    refute Map.has_key?(u, :email)
    refute Map.has_key?(u, :secret)
  end
end
