Code.require_file("support/t2.exs", __DIR__)

defmodule AshSurface.Ported.Top.TypescriptSortTest do
  @moduledoc """
  Adaptation of ash_typescript `typescript_sort_test.exs`. The reference asserts the text of a
  generated `postSortFields` const array / `PostSortField` TS type; ash_surface generates no
  `.ts`, so the same facts are asserted on the sortable-field list the compiler derives
  (`ResourceFacts`), on the rendered sort schema (`QuerySchema.render_sort_schema/1`) and by
  executing that schema under real node + zod. Wire names are Ash names (no client formatter):
  that reference test is converted below via an explicit `T2.with_env`. Resource
  `field_names` mappings are applied verbatim (`is_active?` -> `isActive`).
  """
  use ExUnit.Case, async: false

  alias AshSurface.Compiler.QuerySchema
  alias AshSurface.Ported.{EmptyResource, NoRelationshipsResource, Post, T2, Todo, User}
  alias AshSurface.ZodFixtures.CalcAgg

  defp sortable(resource), do: T2.read_facts(resource).sortable_fields

  describe "sort schema for a resource (was: generate_sort_type/1)" do
    test "renders a guard-admitted sort schema over the sortable fields (as const array + derived type)" do
      fields = sortable(Post)
      assert is_list(fields) and fields != []

      assert {:ok, zod} = QuerySchema.render_sort_schema(fields)
      assert {:ok, :expression, ^zod} = AshSurface.Projectors.JS.ZodGuard.admit(zod)

      assert {:ok, [true, true, true, false, false]} =
               T2.node_eval(zod, ["title", "-title", "title,-id", "nope", "title,nope"])
    end

    test "array contains expected field names" do
      fields = sortable(Post)
      assert "id" in fields
      assert "title" in fields
      assert "published" in fields
    end

    test "sort schema uses mapped field names (resource field_names, verbatim)" do
      fields = sortable(User)
      assert "isActive" in fields
      assert "addressLine1" in fields
      refute "is_active?" in fields
      refute "address_line_1" in fields

      assert {:ok, zod} = QuerySchema.render_sort_schema(fields)

      assert {:ok, [true, true, false, false]} =
               T2.node_eval(zod, ["isActive", "-addressLine1", "is_active?", "address_line_1"])
    end

    test "formats field names for client under an explicitly configured formatter" do
      T2.with_env(:output_field_formatter, :camel_case, fn ->
        fields = sortable(Post)
        assert "viewCount" in fields
        assert "publishedAt" in fields
        refute "view_count" in fields

        assert {:ok, zod} = QuerySchema.render_sort_schema(fields)

        assert {:ok, [true, true, false]} =
                 T2.node_eval(zod, ["viewCount", "-publishedAt", "view_count"])

        # mapped names stay verbatim under any formatter
        assert "isActive" in sortable(User)
      end)
    end

    test "wire names are the Ash names, not a formatted rewrite (the formatter is opt-in, see the next test)" do
      fields = sortable(Post)
      assert "view_count" in fields
      assert "published_at" in fields
      assert "author_id" in fields
      refute "viewCount" in fields
    end

    test "includes public expression calculations" do
      assert {:ok, :sortable} = {:ok, sortable_calc(CalcAgg.Item, :shout)}
      assert "shout" in sortable(CalcAgg.Item)
    end

    test "runtime-only (module) calculations are excluded because Ash reports them unsortable" do
      # Divergence, Ash-truth bound: ash_typescript lists isOverdue/daysUntilDue; ash_surface
      # asks Ash.Resource.Info.sortable?/3 and refuses what the data layer cannot sort.
      refute Ash.Resource.Info.sortable?(Todo, :is_overdue, pagination_type: :offset)
      refute "is_overdue" in sortable(Todo)
      refute "days_until_due" in sortable(Todo)
    end

    test "excludes calculations with field?: false" do
      # field? false is honoured by ResourceFacts (lane T2 fix); Ash itself still reports it sortable.
      assert Ash.Resource.Info.sortable?(Todo, :internal_score, pagination_type: :offset)
      refute "internal_score" in sortable(Todo)
      assert "id" in sortable(Todo)
    end

    test "includes public aggregates" do
      fields = sortable(Todo)
      assert "comment_count" in fields
      assert "helpful_comment_count" in fields
    end

    test "resource with no sortable fields yields no sort schema" do
      assert sortable(EmptyResource) == nil
      assert {:error, _} = QuerySchema.render_sort_schema([])
    end
  end

  describe "sort schemas for multiple resources (was: generate_sort_types/1)" do
    test "each resource gets its own admitted sort schema" do
      schemas =
        for r <- [Post, NoRelationshipsResource] do
          assert {:ok, zod} = QuerySchema.render_sort_schema(sortable(r))
          {r, zod}
        end

      assert [{Post, post}, {NoRelationshipsResource, plain}] = schemas
      assert post =~ "title"
      assert plain =~ "name"
      refute post == plain
    end
  end

  defp sortable_calc(resource, name) do
    true = Ash.Resource.Info.sortable?(resource, name, pagination_type: :offset)
    :sortable
  end
end
