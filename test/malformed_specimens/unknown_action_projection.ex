# ash_surface specimen -- deliberately malformed; compiled only by the verifier court.
#
# VERIFIER: unknown_action_projection
# EXPECT-RAISE: Spark.Error.DslError
# EXPECT-MESSAGE: unknown_action_projection
# REFUSAL-CONDITION: AshSurface.Resource.Validator refuses this surface at compile time.
defmodule Specimen.UnknownActionProjection do
  use Ash.Resource,
    domain: nil,
    data_layer: Ash.DataLayer.Simple,
    extensions: [AshSurface.Resource]

  attributes do
    uuid_primary_key(:id, public?: true)
  end

  actions do
    defaults([:read])
  end

  surface do
    projection(:ghost)
  end
end
