defmodule AshSurface.Ported.Top.FieldFormatterStructClauseTest do
  @moduledoc """
  Port of ash_typescript `field_formatter_struct_clause_test.exs`. `FieldFormatter.format_field_for_client/3`
  maps to `AshSurface.FieldName.format_field_for_client/3`; `Manifest.Custom.resolve_resource/1`
  maps to the module itself (the resource carries its persisted `surface` mapping).
  The reference's "nil struct" clause maps to the plain `FieldName.compute/2` path (ash_surface
  takes a resource module, not an optional struct).
  """
  use ExUnit.Case, async: true

  alias AshSurface.FieldName
  alias AshSurface.Ported.User

  test "built-in formatter uses the resource field_names mapping" do
    assert FieldName.format_field_for_client(:is_active?, User, :camel_case) == "isActive"

    assert FieldName.format_field_for_client(:address_line_1, User, :camel_case) ==
             "addressLine1"
  end

  test "unmapped field falls back to case conversion" do
    assert FieldName.format_field_for_client(:some_plain_field, User, :camel_case) ==
             "somePlainField"
  end

  test "no resource mapping falls back to plain case conversion" do
    assert FieldName.compute(:some_field, :camel_case) == "someField"
    # a resource module with no surface mapping behaves identically
    assert FieldName.format_field_for_client(
             :some_field,
             AshSurface.Ported.EmptyResource,
             :camel_case
           ) ==
             "someField"
  end

  # RBY re-pin (reference parity, RBS aligned FieldName.clean/1): a trailing `?` is KEPT under every
  # built-in formatter (~/ash_typescript helpers.ex:25-30,73 snake_to_camel_case never strips it;
  # an unmapped `?` name is refused upstream, a mapped name wins verbatim).
  test "question marks are kept under every built-in formatter" do
    assert FieldName.compute(:active?, :snake_case) == "active?"
    assert FieldName.compute(:is_active?, :camel_case) == "isActive?"
    assert FieldName.compute(:is_active?, :pascal_case) == "IsActive?"

    assert FieldName.format_field_for_client(
             :is_ready?,
             AshSurface.Ported.EmptyResource,
             :camel_case
           ) == "isReady?"
  end
end
