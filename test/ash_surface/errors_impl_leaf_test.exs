defmodule AshSurface.ErrorsImplLeafTest do
  @moduledoc "Per-leaf wire-type court for Ash error structs (parity error.impl.* ids)."
  use ExUnit.Case, async: true

  alias AshSurface.Errors
  alias AshSurface.IR.ErrorShape

  defp wire(exception) do
    [e] = Errors.to_errors(exception, formatter: :snake_case)
    assert ErrorShape.valid_type?(e["type"])
    assert is_map(e["details"])
    {Errors.classify(exception), e["type"], e["short_message"]}
  end

  test "Ash.Error.Changes.InvalidChanges reaches the wire as invalid_changes" do
    r = AshSurface.ZodFixtures.Todo
    _ = r
    assert {{"invalid_changes", "Invalid changes"}, "invalid_changes", "Invalid changes"} =
             wire(Ash.Error.Changes.InvalidChanges.exception(fields: [:a], message: "m"))
  end

  test "Ash.Error.Query.InvalidQuery reaches the wire as invalid_query" do
    r = AshSurface.ZodFixtures.Todo
    _ = r
    assert {{"invalid_query", "Invalid query"}, "invalid_query", "Invalid query"} =
             wire(Ash.Error.Query.InvalidQuery.exception(field: :a, message: "m"))
  end

  test "Ash.Error.Query.NotFound reaches the wire as not_found" do
    r = AshSurface.ZodFixtures.Todo
    _ = r
    assert {{"not_found", "Not found"}, "not_found", "Not found"} =
             wire(Ash.Error.Query.NotFound.exception(primary_key: %{id: 1}, resource: r))
  end

  test "Ash.Error.Forbidden.ForbiddenField reaches the wire as forbidden_field" do
    r = AshSurface.ZodFixtures.Todo
    _ = r
    assert {{"forbidden_field", "Forbidden field"}, "forbidden_field", "Forbidden field"} =
             wire(Ash.Error.Forbidden.ForbiddenField.exception(field: :a, resource: r))
  end

  test "Ash.Error.Changes.InvalidArgument reaches the wire as invalid_argument" do
    r = AshSurface.ZodFixtures.Todo
    _ = r
    assert {{"invalid_argument", "Invalid argument"}, "invalid_argument", "Invalid argument"} =
             wire(Ash.Error.Changes.InvalidArgument.exception(field: :a, message: "m"))
  end

  test "Ash.Error.Query.InvalidArgument reaches the wire as invalid_argument" do
    r = AshSurface.ZodFixtures.Todo
    _ = r
    assert {{"invalid_argument", "Invalid argument"}, "invalid_argument", "Invalid argument"} =
             wire(Ash.Error.Query.InvalidArgument.exception(field: :a, message: "m"))
  end

  test "Ash.Error.Action.InvalidArgument reaches the wire as invalid_argument" do
    r = AshSurface.ZodFixtures.Todo
    _ = r
    assert {{"invalid_argument", "Invalid argument"}, "invalid_argument", "Invalid argument"} =
             wire(Ash.Error.Action.InvalidArgument.exception(field: :a, message: "m"))
  end

  test "Ash.Error.Page.InvalidKeyset reaches the wire as invalid_keyset" do
    r = AshSurface.ZodFixtures.Todo
    _ = r
    assert {{"invalid_keyset", "Invalid keyset"}, "invalid_keyset", "Invalid keyset"} =
             wire(Ash.Error.Page.InvalidKeyset.exception(value: "x"))
  end

  test "Ash.Error.Query.InvalidPage reaches the wire as invalid_page" do
    r = AshSurface.ZodFixtures.Todo
    _ = r
    assert {{"invalid_page", "Invalid pagination"}, "invalid_page", "Invalid pagination"} =
             wire(Ash.Error.Query.InvalidPage.exception(page: 1))
  end

  test "Ash.Error.Invalid.TenantRequired reaches the wire as tenant_required" do
    r = AshSurface.ZodFixtures.Todo
    _ = r
    assert {{"tenant_required", "Tenant required"}, "tenant_required", "Tenant required"} =
             wire(Ash.Error.Invalid.TenantRequired.exception(resource: r))
  end

  test "Ash.Error.Invalid.InvalidPrimaryKey reaches the wire as invalid_primary_key" do
    r = AshSurface.ZodFixtures.Todo
    _ = r
    assert {{"invalid_primary_key", "Invalid primary key"}, "invalid_primary_key", "Invalid primary key"} =
             wire(Ash.Error.Invalid.InvalidPrimaryKey.exception(resource: r, value: 1))
  end
end
