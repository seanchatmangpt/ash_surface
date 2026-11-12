defmodule AshSurface.Ported.Top.TypescriptFilterGapTest do
  @moduledoc """
  Loud skip for the one ash_typescript `typescript_filter_test.exs` behavior ash_surface does not
  have after GU-T2 (string ordering, enum narrowing, relationship entries and whole-array eq/in
  are converted in `typescript_filter_test.exs`). Not listed on a ledger row.
  """
  use ExUnit.Case, async: true

  @tag skip:
         "GAP typescript_filter operator formatting: operator keys are the surface spelling (neq, starts_with); output_field_formatter camelCasing (notEq, stringStartsWith) is not applied"
  test "operator and field names are formatted with the configured formatter" do
    flunk("capability missing: formatter applied to filter operator names")
  end
end
