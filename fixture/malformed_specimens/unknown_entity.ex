# verifier_court.exs.tmpl specimen -- deliberately malformed. The court compiles this
# source with Code.compile_string/1 and REQUIRES a compile-time refusal. Never compile
# this file outside the court.
#
# VERIFIER: entity_surface
# EXPECT-RAISE: CompileError
# EXPECT-MESSAGE: undefined function nonexistent_entity/1
# REFUSAL-CONDITION: extension.ex.tmpl renders exactly the spec's aex:DslEntity rows
#   as entity macros inside their section; calling an unknown entity inside :audit
#   must be a compile error ("undefined function nonexistent_entity/1"). If it
#   compiles, the entity surface is open-ended instead of spec-closed.
defmodule Specimen.UnknownEntity do
  use Court.Dsl

  audit do
    nonexistent_entity("alpha")
  end
end
