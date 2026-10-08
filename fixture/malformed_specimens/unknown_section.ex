# verifier_court.exs.tmpl specimen -- deliberately malformed. The court compiles this
# source with Code.compile_string/1 and REQUIRES a compile-time refusal. Never compile
# this file outside the court.
#
# VERIFIER: section_surface
# EXPECT-RAISE: CompileError
# EXPECT-MESSAGE: undefined function nonexistent_section/1
# REFUSAL-CONDITION: extension.ex.tmpl renders exactly the spec's aex:DslSection rows
#   as section macros; calling an unknown section (`nonexistent_section`) must be a
#   compile error ("undefined function nonexistent_section/1 (there is no such
#   import)"). If it compiles, the extension surface is open-ended instead of
#   spec-closed.
defmodule Specimen.UnknownSection do
  use Court.Dsl

  nonexistent_section do
    event("alpha")
  end
end
