# verifier_court.exs.tmpl specimen -- deliberately malformed. The court compiles this
# source with Code.compile_string/1 and REQUIRES a compile-time refusal. Never compile
# this file outside the court.
#
# VERIFIER: verify_section_singleton_entities
# EXPECT-RAISE: Spark.Error.DslError
# EXPECT-MESSAGE: Expected at most one snapshot in [:audit], got 2
# REFUSAL-CONDITION: extension.ex.tmpl renders `singleton_entity_keys: [:snapshot]` on
#   the :audit section; Spark's own VerifySectionSingletonEntities verifier must refuse
#   a second `snapshot` declaration ("Expected at most one snapshot in [:audit], got 2").
#   If this specimen compiles, the singleton_entity_keys wiring from the spec is broken.
defmodule Specimen.DuplicateSingleton do
  use Court.Dsl

  audit do
    snapshot("one")
    snapshot("two")
  end
end
