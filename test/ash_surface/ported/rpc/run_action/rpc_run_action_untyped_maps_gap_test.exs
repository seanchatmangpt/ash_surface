defmodule AshSurface.Ported.Rpc.RunAction.UntypedMapsGapTest do
  use ExUnit.Case, async: true

  @tag skip:
         "GU7 gap: asserts the merge performed by the update_with_untyped_data action change function against persisted custom_data (action execution); AshSurface never actuates (README: it never actuates). Untyped-map attribute round-trip is covered in rpc_run_action_untyped_maps_surface_test.exs"
  test "update_with_untyped_data action accepts untyped map arguments" do
    :ok
  end

  @tag skip:
         "GU7 gap: asserts the merge performed by the update_with_untyped_data action change function against persisted custom_data (action execution); AshSurface never actuates (README: it never actuates). Untyped-map attribute round-trip is covered in rpc_run_action_untyped_maps_surface_test.exs"
  test "update_with_untyped_data action works with nil metadata_update" do
    :ok
  end

  @tag skip:
         "GU7 gap: asserts the merge performed by the update_with_untyped_data action change function against persisted custom_data (action execution); AshSurface never actuates (README: it never actuates). Untyped-map attribute round-trip is covered in rpc_run_action_untyped_maps_surface_test.exs"
  test "update_with_untyped_data action merges with nil custom_data" do
    :ok
  end

  @tag skip:
         "GU7 gap: asserts the merge performed by the update_with_untyped_data action change function against persisted custom_data (action execution); AshSurface never actuates (README: it never actuates). Untyped-map attribute round-trip is covered in rpc_run_action_untyped_maps_surface_test.exs"
  test "update_with_untyped_data action handles complex nested structures" do
    :ok
  end
end
