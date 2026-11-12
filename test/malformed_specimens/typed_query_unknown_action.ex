# ash_surface specimen -- deliberately malformed; compiled only by the verifier court.
#
# VERIFIER: typed_query_unknown_action
# EXPECT-RAISE: Spark.Error.DslError
# EXPECT-MESSAGE: typed_query_unknown_action
# REFUSAL-CONDITION: AshSurface.Resource.Validator refuses this surface at compile time.
defmodule Specimen.TypedQueryUnknownAction do
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
    typed_query(:q, :ghost, fields: [:id])
  end
end
