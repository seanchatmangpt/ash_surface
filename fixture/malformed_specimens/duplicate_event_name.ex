# verifier_court.exs.tmpl specimen -- deliberately malformed. The court compiles this
# source with Code.compile_string/1 and REQUIRES a compile-time refusal. Never compile
# this file outside the court.
#
# VERIFIER: unique_event_name
# EXPECT-RAISE: Spark.Error.DslError
# EXPECT-MESSAGE: unique_event_name
# REFUSAL-CONDITION: the aex:Verifier row `unique_event_name` -- verify.ex.tmpl's
#   with-chain clause `:ok <- check_unique_event_name(compiled)` must refuse two
#   :event entities sharing the same :name. The :event entity carries NO Spark
#   :identifier, so Spark's own VerifyEntityUniqueness does NOT fire here: this
#   refusal is attributable to check_unique_event_name/1 ALONE, which is exactly what
#   makes it a precise vacuity witness (a mutant with the clause removed lets this
#   specimen compile cleanly, and the court must fail naming this verifier).
#
#   NOTE: as verify.ex.tmpl renders it today, check_unique_event_name/1 is an honest
#   TODO stub returning :ok -- so on a stock render this specimen compiles cleanly and
#   the court FAILS naming `unique_event_name`. That is the court doing its job: the
#   stub is a vacuous verifier until the TODO is filled with a real check.
defmodule Specimen.DuplicateEventName do
  use Court.Dsl

  audit do
    event("alpha")
    event("alpha")
  end
end
