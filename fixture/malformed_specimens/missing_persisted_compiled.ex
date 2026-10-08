# verifier_court.exs.tmpl specimen -- deliberately malformed. The court compiles this
# source with Code.compile_string/1 and REQUIRES a compile-time refusal. Never compile
# this file outside the court.
#
# VERIFIER: persist_before_verify
# EXPECT-RAISE: Spark.Error.DslError
# EXPECT-MESSAGE: did not persist :audit_trail_compiled
# REFUSAL-CONDITION: verify.ex.tmpl's nil branch -- `Spark.Dsl.Verifier.get_persisted(
#   dsl_state, :audit_trail_compiled)` returns nil when the Persist transformer has not
#   run, so Verify must refuse with a Spark.Error.DslError naming the missing key
#   ("transformer did not persist :audit_trail_compiled -- Persist must run before
#   Verify").
#
# Mechanism: the court's {{ScratchTrail}} scratch extension (rendered next to the
# court, sharing the real spec's sections and entity structs but with
# `transformers: []`) runs the REAL generated `AuditTrail.Verify` against a DSL state
# where nothing was persisted. If this specimen compiles cleanly, the nil branch is
# gone and the persist-before-verify invariant is unpoliced.
defmodule Specimen.MissingPersistedCompiled do
  use Court.ScratchDsl

  audit do
    event("alpha")
  end
end
