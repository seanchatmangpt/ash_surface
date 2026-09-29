// Prints the JS runtime's cross-boundary vocabulary as JSON, for the Elixir
// drift test (test/ash_surface/vocabulary_drift_test.exs). Read-only: imports
// the shipped runtime and emits its exported closed sets. Ordinary .mjs.
import { VOCABULARY, STANDING_VALUES } from "../../priv/static/ash_surface_runtime.mjs";

process.stdout.write(
  JSON.stringify({ ...VOCABULARY, standingValues: [...STANDING_VALUES] }),
);
