defmodule AshSurface.Ported.RpcRunActionUserSurfaceTest do
  @moduledoc """
  Non-actuating counterpart of `rpc_run_action_user_test.exs` (default camelCase formatter,
  `field_names` mapping `address_line_1 -> "addressLine1"`). The pascal_case / snake_case tests
  set the global `:input_field_formatter`/`:output_field_formatter` env; the pipeline formatter
  is `Config`-driven (`Rpc.Support`), and the `field_names` mapping wins over the formatter.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.{Rpc, RpcFixtures}
  import RpcFixtures, only: [user: 1]

  test "processes address_line_1 field correctly" do
    result =
      Rpc.run(
        %{"action" => "list_users", "fields" => ["id", "name", "email", "addressLine1"]},
        [user(address_line_1: "1 Main St")]
      )

    assert result["success"] == true
    assert is_list(result["data"])

    Enum.each(result["data"], fn u ->
      assert Map.has_key?(u, "id")
      assert Map.has_key?(u, "name")
      assert Map.has_key?(u, "email")
      assert u["addressLine1"] == "1 Main St"
      refute Map.has_key?(u, "active")
      refute Map.has_key?(u, "isSuperAdmin")
    end)
  end

  defp with_formatters(formatter, fun) do
    keys = [:input_field_formatter, :output_field_formatter]
    prev = Enum.map(keys, &{&1, Application.fetch_env(:ash_surface, &1)})
    Enum.each(keys, &Application.put_env(:ash_surface, &1, formatter))

    try do
      fun.()
    after
      Enum.each(prev, fn
        {k, {:ok, v}} -> Application.put_env(:ash_surface, k, v)
        {k, :error} -> Application.delete_env(:ash_surface, k)
      end)
    end
  end

  test "processes address_line_1 field correctly with pascal_case formatter" do
    with_formatters(:pascal_case, fn ->
      # field_names mapping (address_line_1 -> "addressLine1") takes precedence over the formatter
      result =
        Rpc.run(
          %{"action" => "list_users", "fields" => ["Id", "Name", "Email", "addressLine1"]},
          [user(address_line_1: "1 Main St")]
        )

      assert result["Success"] == true
      assert is_list(result["Data"])

      Enum.each(result["Data"], fn u ->
        assert Map.has_key?(u, "Id")
        assert Map.has_key?(u, "Name")
        assert Map.has_key?(u, "Email")
        assert u["addressLine1"] == "1 Main St"
        refute Map.has_key?(u, "Active")
        refute Map.has_key?(u, "IsSuperAdmin")
      end)
    end)
  end

  test "processes address_line_1 field correctly with snake_case formatter" do
    with_formatters(:snake_case, fn ->
      result =
        Rpc.run(
          %{"action" => "list_users", "fields" => ["id", "name", "email", "addressLine1"]},
          [user(address_line_1: "1 Main St")]
        )

      assert result["success"] == true
      assert is_list(result["data"])

      Enum.each(result["data"], fn u ->
        assert Map.has_key?(u, "id")
        assert Map.has_key?(u, "name")
        assert Map.has_key?(u, "email")
        assert u["addressLine1"] == "1 Main St"
        refute Map.has_key?(u, "active")
        refute Map.has_key?(u, "is_super_admin")
      end)
    end)
  end
end
