# Hand-written MUTANT Info module for the info-parity court
# (packs/ash-extension-pack/templates/info_parity_court.exs.tmpl).
#
# It violates the spec law on purpose: its getters return CONSTANTS instead of
# reading the persisted Spark DSL state. On the un-mutated specimen the `level`
# constant (:full) happens to equal the declared value, so only the court's
# MUTATION leg -- which changes the declared value and requires the getter to
# change with it -- can kill this mutant. The court asserts that failure is
# captured; if this mutant ever passes the mutation leg, the court is vacuous.

defmodule InfoParityMutant.Info do
  @moduledoc false

  # CONSTANT: never reads Spark.Dsl.Extension at all.
  def level(_resource), do: :full

  # CONSTANT: never reads Spark.Dsl.Extension at all.
  def declared_events(_resource), do: [:read]
end
