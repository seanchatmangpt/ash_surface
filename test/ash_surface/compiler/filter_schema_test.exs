defmodule AshSurface.Compiler.FilterSchemaTest do
  @moduledoc """
  Chicago court for `AshSurface.Compiler.FilterSchema`: the REAL ZodGuard is
  the admission collaborator (no mocks); assertions are on the rendered
  string admitted by the guard, not on call shapes.
  """

  use ExUnit.Case, async: true
  alias AshSurface.Compiler.FilterSchema
  alias AshSurface.Projectors.JS.ZodGuard

  @inputs [
    %{"name" => "name", "type" => %{"kind" => "string"}},
    %{"name" => "count", "type" => %{"kind" => "integer"}},
    %{"name" => "active", "type" => %{"kind" => "boolean"}},
    %{"name" => "org_id", "type" => %{"kind" => "uuid"}},
    %{"name" => "tags", "type" => %{"kind" => "array"}},
    %{"name" => "blob", "type" => %{"kind" => "weird_kind"}}
  ]

  # SLA minimal unblock (L04, owning lane L23): paren-delimited ~s(...) breaks
  # under nested parens — this Elixir closes the sigil at the first ")" — so
  # every multi-paren literal below is quote-delimited ~s'...' instead,
  # content unchanged from the owner's intent. Disclosed in receipts/L04.md;
  # superseded by the owner on landing.
  test "renders a guard-admitted union" do
    {:ok, zod} = FilterSchema.render_filter_schema(@inputs)
    assert :ok = ZodGuard.expression(zod)
    assert {:ok, :expression, ^zod} = ZodGuard.admit(zod)
    assert zod =~ ~s'z.object({field: z.enum(["name"]), op: z.literal("eq"), value: z.string()})'
  end

  test "operator catalog per kind" do
    {:ok, zod} = FilterSchema.render_filter_schema(@inputs)

    for op <- ["eq", "neq", "contains", "starts_with", "ends_with"] do
      assert zod =~ "z.literal(\"#{op}\")"
    end

    # string group only has `name`
    assert zod =~ ~s'z.enum(["name"]), op: z.literal("contains"), value: z.string()'

    # numeric family: gt/gte/lt/lte on integer base
    assert zod =~
             ~s'z.enum(["count"]), op: z.literal("gt"), value: z.number().int()'

    # boolean: eq/neq only
    assert zod =~ ~s'z.enum(["active"]), op: z.literal("neq"), value: z.boolean()'

    # uuid: in wraps base in z.array
    assert zod =~
             ~s'z.enum(["org_id"]), op: z.literal("in"), value: z.array(z.guid())'

    # array: has = element fragment, has_any = z.array(element)
    assert zod =~ ~s'z.enum(["tags"]), op: z.literal("has"), value: z.unknown()'

    assert zod =~
             ~s'z.enum(["tags"]), op: z.literal("has_any"), value: z.array(z.unknown())'

    # unknown kind: eq/neq/in over z.unknown()
    assert zod =~ ~s'z.enum(["blob"]), op: z.literal("eq"), value: z.unknown()'
    refute zod =~ ~s'z.enum(["blob"]), op: z.literal("gt")'
  end

  test "accepts atom-keyed IR entries" do
    {:ok, zod} =
      FilterSchema.render_filter_schema([
        %{name: "email", type: %{kind: "string"}}
      ])

    assert :ok = ZodGuard.expression(zod)
    assert zod =~ ~s'z.enum(["email"])'
  end

  test "escapes untrusted field names inside the enum literal" do
    {:ok, zod} =
      FilterSchema.render_filter_schema([
        %{"name" => ~s(bad"name), "type" => %{"kind" => "string"}}
      ])

    assert :ok = ZodGuard.expression(zod)
    assert zod =~ ~s'z.enum(["bad\\"name\"])'
  end

  test "fail-closed input errors" do
    assert {:error, {:filter_inputs_not_a_list, :nope}} =
             FilterSchema.render_filter_schema(:nope)

    assert {:error, :no_filterable_fields} = FilterSchema.render_filter_schema([])

    assert {:error, {:filter_input_missing_name, %{}}} =
             FilterSchema.render_filter_schema([%{"type" => %{"kind" => "string"}}])

    assert {:error, {:filter_input_missing_type, %{"name" => "x"}}} =
             FilterSchema.render_filter_schema([%{"name" => "x"}])
  end

  test "operator sets come from input metadata; is_nil gated on nullability" do
    {:ok, zod} =
      FilterSchema.render_filter_schema([
        %{"name" => "title", "type" => %{"kind" => "string"}, "operators" => ["eq", :lt]},
        %{"name" => "note", "type" => %{"kind" => "string"}, "allow_nil?" => true}
      ])

    assert :ok = ZodGuard.expression(zod)
    # `note` has no operator override so it keeps the string catalog (incl. lt); fields of
    # one kind+operator share one enum branch, hence both names under `lt`.
    assert zod =~ ~s'z.enum(["note", "title"]), op: z.literal("lt")'
    refute zod =~ ~s'z.enum(["title"]), op: z.literal("neq")'
    refute zod =~ ~s'"title"]), op: z.literal("contains")'
    assert zod =~ ~s'z.enum(["note"]), op: z.literal("is_nil"), value: z.boolean()'
    refute zod =~ ~s'z.enum(["title"]), op: z.literal("is_nil")'
  end

  test "logical wrappers are depth-capped at 2 with no z.lazy" do
    {:ok, zod} = FilterSchema.render_filter_schema(@inputs)
    refute zod =~ "lazy"

    count = fn op ->
      length(String.split(zod, ~s'z.literal("#{op}"), value: z.array(z.union([')) - 1
    end

    # depth 2: 1 top-level `and` + one `and` inside each of the 3 level-1 wrappers
    # plus one `and` in the related destination (logical depth 1 inside related)
    assert count.("and") == 5
    assert zod =~ ~s'op: z.literal("not"), value: z.union(['
    assert zod == elem(FilterSchema.render_filter_schema(@inputs), 1)
  end

  test "relationship facts render a related variant with destination filter" do
    {:ok, zod} =
      FilterSchema.render_filter_schema([
        %{"name" => "title", "type" => %{"kind" => "string"}},
        %{
          "name" => "author",
          "type" => %{"kind" => "map"},
          "relationship" => %{
            "filter_inputs" => [%{"name" => "email", "type" => %{"kind" => "string"}}]
          }
        }
      ])

    assert :ok = ZodGuard.expression(zod)

    assert zod =~
             ~s'z.enum(["author"]), op: z.literal("related"), value: z.union([z.object({field: z.enum(["email"])'
  end
end
