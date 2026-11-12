defmodule AshSurface.RpcFormatterScopeTest do
  @moduledoc """
  Lane RP: the process-scoped formatter (`AshSurface.FieldName.with_formatter/2`, the scope of the
  `:output_field_formatter` compile option) applies in-process to the non-actuating RPC parse and
  format, so a compile-time formatter and the runtime formatter cannot disagree inside the scope.
  Outside any scope `AshSurface.Config` rules (camel_case default).
  """
  use ExUnit.Case, async: false

  alias AshSurface.FieldName
  alias AshSurface.Ported.Rpc

  defp params(field), do: %{"action" => "list_todos", "fields" => [field]}

  defp unknown?(result), do: match?({:error, {:unknown_field, :created_at, _, _}}, result)

  test "default scope: camel spelling resolves" do
    assert {:ok, _} = Rpc.parse(params("createdAt"))
  end

  test "converse: pascal_case scope resolves Pascal spelling, refuses camel spelling" do
    FieldName.with_formatter(:pascal_case, fn ->
      assert {:ok, _} = Rpc.parse(params("CreatedAt"))
      assert unknown?(Rpc.parse(params("createdAt")))
    end)
  end

  test "snake_case scope: snake spelling resolves, camel spelling is a typed refusal" do
    FieldName.with_formatter(:snake_case, fn ->
      assert {:ok, _} = Rpc.parse(params("created_at"))
      result = Rpc.parse(params("createdAt"))
      assert unknown?(result)
    end)
  end

  test "snake_case scope emits snake output keys; camel scope emits camel" do
    row = %{id: "x", created_at: ~U[2024-01-15 10:00:00Z]}

    snake =
      FieldName.with_formatter(:snake_case, fn ->
        Rpc.run(params("created_at"), [row])
      end)

    assert snake["success"] == true
    assert [%{"created_at" => _}] = snake["data"]

    camel = Rpc.run(params("createdAt"), [row])
    assert [%{"createdAt" => _}] = camel["data"]
  end

  test "scope restores after the block (no leak into the camel default)" do
    FieldName.with_formatter(:snake_case, fn -> :ok end)
    assert {:ok, _} = Rpc.parse(params("createdAt"))
    assert FieldName.scoped_formatter() == nil
  end
end
