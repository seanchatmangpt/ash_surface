# Usage: mix run scripts/parity_inventory.exs [--regenerate]
# Thin wrapper over `mix ash_surface.parity --check-inventory | --regenerate-inventory`.
args =
  if "--regenerate" in System.argv(), do: ["--regenerate-inventory"], else: ["--check-inventory"]

Mix.Tasks.AshSurface.Parity.run(args)
