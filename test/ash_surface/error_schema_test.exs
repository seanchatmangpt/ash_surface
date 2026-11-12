defmodule AshSurface.ErrorSchemaTest do
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.ErrorSchema
  alias AshSurface.IR.ErrorShape
  alias AshSurface.Projectors.JS.ZodGuard

  test "closed enum has 20 types including catch-all and the 5 identity/pagination types" do
    assert length(ErrorShape.types()) == 20

    for t <-
          ~w(invalid_identity missing_identity sort_not_supported pagination_not_supported invalid_pagination),
        do: assert(ErrorShape.valid_type?(t))

    assert "unknown_error" in ErrorShape.types()
  end

  test "normalize_type maps unknown to unknown_error" do
    assert ErrorShape.normalize_type(:not_found) == "not_found"
    assert ErrorShape.normalize_type("weird") == "unknown_error"
    assert ErrorShape.normalize_type(nil) == "unknown_error"
    assert ErrorShape.new("weird").type == "unknown_error"
  end

  test "render admits every expression and covers all variants" do
    assert {:ok, r} = ErrorSchema.render(%{create: [:title, "body", :title]})
    assert map_size(r.variants) == 20
    assert r.union =~ ~s(z.discriminatedUnion("type", [)

    for expr <- [r.base, r.union | Map.values(r.variants)],
        do: assert(:ok = ZodGuard.expression(expr))

    assert r.field_errors["create"] ==
             "z.object({body: z.array(z.string()).optional(), title: z.array(z.string()).optional()}).strict()"
  end

  test "unknown_error is the last union member and output is deterministic" do
    last = ErrorSchema.union() |> String.split("z.object({type: z.literal(") |> List.last()
    assert last =~ ~s("unknown_error")
    assert ErrorSchema.union() == ErrorSchema.union()
  end

  test "variant of unrecognised type becomes unknown_error" do
    assert ErrorSchema.variant("zzz") == ErrorSchema.variant("unknown_error")
  end
end
