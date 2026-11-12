defmodule AshSurface.Ported.Rpc.D.RuntimeSourceOfTruthGuardTest do
  @moduledoc """
  Port of ash_typescript `runtime_source_of_truth_guard_test.exs`. The reference locks that
  runtime request-pipeline modules read derived data only through `Manifest.Custom`. The
  ash_surface counterpart (`AshSurface.RuntimeParity.*`) reads ash_surface-specific derived
  data only through `RequestedFields.Compat` (the single adapter over the manifest), never
  `AshSurface.Resource.Info` / `AshSurface.Info` or `Map.get/2` on a raw rpc_action for the
  migrated concerns. `compat.ex` itself is the one allowed reader.
  """
  use ExUnit.Case, async: true

  @runtime_files [
    "lib/ash_surface/runtime_parity/requested_fields_processor.ex",
    "lib/ash_surface/runtime_parity/field_selection.ex",
    "lib/ash_surface/runtime_parity/requested_fields/atomizer.ex",
    "lib/ash_surface/runtime_parity/requested_fields/field_selector.ex",
    "lib/ash_surface/runtime_parity/requested_fields/validation.ex",
    "lib/ash_surface/runtime_parity/requested_fields/load_restrictions.ex",
    "lib/ash_surface/runtime_parity/requested_fields/introspection.ex"
  ]

  @forbidden_modules ["AshSurface.Resource.Info", "AshSurface.Info"]

  @forbidden_rpc_action_reads [
    "Map.get(rpc_action, :allowed_loads",
    "Map.get(rpc_action, :denied_loads",
    "Map.get(rpc_action, :enable_filter?",
    "Map.get(rpc_action, :enable_sort?",
    "Map.get(rpc_action, :show_metadata"
  ]

  for file <- @runtime_files do
    test "#{file} has no retired source-of-truth reads" do
      path = Path.join(File.cwd!(), unquote(file))
      assert File.exists?(path), "guarded file missing: #{unquote(file)}"
      source = File.read!(path)

      for needle <- @forbidden_modules ++ @forbidden_rpc_action_reads do
        refute String.contains?(source, needle),
               "#{unquote(file)} must not contain #{inspect(needle)} — read via Compat instead"
      end
    end
  end
end
