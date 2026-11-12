defmodule AshSurface.Ported.Rpc.Rba.ConfigDefaultsTest do
  @moduledoc "Pins unset-env defaults of AshSurface.Config (skeptic wave3 repair)."
  use ExUnit.Case, async: false

  alias AshSurface.Config

  @keys [:always_regenerate, :not_found_error?, :typed_controller_mode, :phoenix_import_path, :run_endpoint]

  setup do
    snap = for k <- @keys, do: {k, Application.fetch_env(:ash_surface, k)}
    for k <- @keys, do: Application.delete_env(:ash_surface, k)

    on_exit(fn ->
      for {k, res} <- snap do
        case res do
          {:ok, v} -> Application.put_env(:ash_surface, k, v)
          :error -> Application.delete_env(:ash_surface, k)
        end
      end
    end)
  end

  test "accessor defaults with env unset" do
    assert Config.always_regenerate() === false
    assert Config.not_found_error?() === true
    assert Config.typed_controller_mode() === :full
    assert Config.phoenix_import_path() === "phoenix"
    assert Config.run_endpoint() === "/rpc/run"
  end

  test "parity_value defaults with env unset" do
    assert Config.parity_value(:not_found_error?) === true
    assert Config.parity_value(:typed_controller_mode) === :full
    assert Config.parity_value(:phoenix_import_path) === "phoenix"
    assert Config.parity_value(:run_endpoint) === "/rpc/run"
  end

  test "env values override defaults" do
    Application.put_env(:ash_surface, :always_regenerate, true)
    Application.put_env(:ash_surface, :not_found_error?, false)
    assert Config.always_regenerate() === true
    assert Config.not_found_error?() === false
  end
end
