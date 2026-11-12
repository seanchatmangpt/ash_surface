defmodule AshSurface.Ported.Codegen.InstallGapTest do
  @moduledoc """
  Loud, tagged skips for the ash_typescript `mix_tasks/install_test.exs` tests that have no
  ash_surface counterpart: the reference installer injects `post "/rpc/run"` and
  `post "/rpc/validate"` routes to an `AshTypescriptRpcController` into the Phoenix router.
  ash_surface has the `run_endpoint` / `validate_endpoint` / `router` config keys but ships no
  server-side RPC controller and its installer patches no router, so there is no route to add.
  """
  use ExUnit.Case, async: false

  @tag skip:
         "mix_tasks/install_test router: no ash_surface RPC controller or installer router patch"
  test "adds RPC routes with real paths to the router" do
    flunk("capability missing: ash_surface installer adds no RPC routes")
  end

  @tag skip:
         "mix_tasks/install_test router: no ash_surface RPC controller or installer router patch"
  test "falls back to the default for whichever endpoint is not configured" do
    flunk("capability missing: ash_surface installer adds no RPC routes")
  end

  @tag skip:
         "mix_tasks/install_test router: no ash_surface RPC controller or installer router patch"
  test "uses configured endpoint paths when adding RPC routes" do
    flunk("capability missing: ash_surface installer adds no RPC routes")
  end

  @tag skip:
         "mix_tasks/install_test router: no ash_surface RPC controller or installer router patch"
  test "does not add RPC routes that are already in the router" do
    flunk("capability missing: ash_surface installer adds no RPC routes")
  end
end
