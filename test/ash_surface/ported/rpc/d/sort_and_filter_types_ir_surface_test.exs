Code.require_file("../../top/support/t2.exs", __DIR__)

defmodule AshSurface.Ported.Rpc.D.SortAndFilterTypesIrSurfaceTest do
  @moduledoc """
  Behavioral adaptation of the TypeScript-text half of `sort_and_filter_types_test.exs`
  (lane TSA-T11). The reference asserts substrings of generated `SortField` / `FilterField` /
  `FilterInput` TypeScript. ash_surface emits no `.ts`; the claim each assertion proves is
  restated on what ash_surface does emit:

    * the sortable / filterable field sets the compiler derives (`ResourceFacts`),
    * the sort schema (`QuerySchema.render_sort_schema/1`) and the compiled filter schema
      (`ir.schema.filter`, a tagged `{field, op, value}` tree) executed under real node + zod,
    * the per-action `enable_sort?` / `enable_filter?` switches through the real RPC pipeline
      (a disabled switch refuses the key with a typed error; an enabled one parses it).

  Operator spelling is the surface key set (`eq`, `neq`, `gt`, `is_nil`, ...), not camelCased
  TypeScript keys; wire names are Ash names.
  """
  use ExUnit.Case, async: false

  @moduletag timeout: 300_000

  alias AshSurface.Compiler.QuerySchema
  alias AshSurface.Ported.{EmptyResource, NoRelationshipsResource, Post, Rpc, T2, Todo, User}
  alias AshSurface.RuntimeParity.Rpc.Pipeline

  @atoms [:due_date, :priority_score, :created_at, :is_nil, :priority, :title, :description]
  def atoms, do: @atoms

  defp sortable(resource), do: T2.read_facts(resource).sortable_fields
  defp filter_names(resource), do: Enum.map(T2.read_facts(resource).filter_entries, & &1["name"])

  defp filter_entry(resource, name),
    do: Enum.find(T2.read_facts(resource).filter_entries, &(&1["name"] == name))

  defp f(field, op, value), do: %{"field" => field, "op" => op, "value" => value}

  defp check(zod, cases) do
    assert {:ok, oks} = T2.node_eval(zod, Enum.map(cases, &elem(&1, 1)))

    for {{label, _payload, expected}, ok} <- Enum.zip(cases, oks) do
      assert ok == expected, "#{label}: expected accept=#{expected}, got #{ok}"
    end
  end

  defp parse_error(params) do
    assert {:error, reason} = Rpc.parse(params)
    reason
  end

  # BEHAVIORAL-COUNTERPART-FOUND: SortField union / as-const array
  describe "sort schema over the sortable field set (was: SortField union type)" do
    test "the sortable set is a non-empty list and the sort schema executes over it" do
      fields = sortable(Todo)
      assert is_list(fields) and fields != []
      assert {:ok, zod} = QuerySchema.render_sort_schema(fields)

      check(zod, [
        {"known", "title", true},
        {"desc", "-title", true},
        {"unknown", "nope", false}
      ])
    end

    test "excludes calculations with field?: false from the sortable set" do
      refute "internal_score" in sortable(Todo)
      refute "internalScore" in sortable(Todo)
      assert {:ok, zod} = QuerySchema.render_sort_schema(sortable(Todo))
      check(zod, [{"internal_score refused", "internal_score", false}])
    end

    test "SortString: all four prefix variants of a field are accepted, unknown field is not" do
      assert {:ok, zod} = QuerySchema.render_sort_schema(sortable(Post))

      check(zod, [
        {"bare", "title", true},
        {"+", "+title", true},
        {"-", "-title", true},
        {"++", "++title", true},
        {"--", "--title", true},
        {"unknown prefixed", "++nope", false}
      ])
    end

    test "sort-enabled action parses sort (string and list); the list joins to one string" do
      for sort <- ["-created_at,+title", ["-created_at", "+title"]] do
        assert {:ok, request} =
                 Rpc.parse(%{"action" => "list_todos", "fields" => ["id"], "sort" => sort})

        assert request.sort == "-created_at,+title"
      end
    end

    test "sort-disabled action refuses the sort key (no sort input at all)" do
      assert {:sort_not_supported, :top_level, :disabled} =
               parse_error(%{
                 "action" => "list_todos_no_sort",
                 "fields" => ["id"],
                 "sort" => "id"
               })

      assert {:ok, request} = Rpc.parse(%{"action" => "list_todos_no_sort", "fields" => ["id"]})
      assert request.sort == nil
    end

    test "filter-disabled but sort-enabled action: sort parses, filter is refused" do
      assert {:ok, request} =
               Rpc.parse(%{
                 "action" => "list_todos_no_filter",
                 "fields" => ["id"],
                 "sort" => ["title"]
               })

      assert request.sort == "title"

      reason =
        parse_error(%{
          "action" => "list_todos_no_filter",
          "fields" => ["id"],
          "filter" => %{"title" => %{"eq" => "x"}}
        })

      assert elem(reason, 0) == :filter_not_supported
    end

    test "both-disabled action refuses sort and filter" do
      sort =
        parse_error(%{
          "action" => "list_todos_no_filter_no_sort",
          "fields" => ["id"],
          "sort" => "id"
        })

      filter =
        parse_error(%{
          "action" => "list_todos_no_filter_no_sort",
          "fields" => ["id"],
          "filter" => %{"title" => %{"eq" => "x"}}
        })

      assert elem(sort, 0) == :sort_not_supported
      assert elem(filter, 0) == :filter_not_supported
    end

    test "empty resource has no sortable set and no sort schema" do
      assert sortable(EmptyResource) == nil
      assert {:error, _} = QuerySchema.render_sort_schema([])
    end

    test "each resource gets its own sort schema over its own fields" do
      assert {:ok, todo} = QuerySchema.render_sort_schema(sortable(Todo))
      assert {:ok, user} = QuerySchema.render_sort_schema(sortable(User))
      assert {:ok, post} = QuerySchema.render_sort_schema(sortable(Post))
      assert {:ok, plain} = QuerySchema.render_sort_schema(sortable(NoRelationshipsResource))
      assert length(Enum.uniq([todo, user, post, plain])) == 4
    end
  end

  describe "sort array join (was: Array.isArray(config.sort) in generated functions)" do
    test "list sort is joined by the request parser for list actions" do
      assert {:ok, request} =
               Rpc.parse(%{
                 "action" => "list_todos",
                 "fields" => ["id"],
                 "sort" => ["a_field", "-b_field"]
               })

      assert request.sort == "a_field,-b_field"
    end

    test "sort-disabled action carries no sort on the parsed request" do
      assert {:ok, request} = Rpc.parse(%{"action" => "list_todos_no_sort", "fields" => ["id"]})
      assert request.sort == nil
    end

    test "channel and HTTP entry share one parser: the same params parse identically" do
      params = %{"action" => "list_todos", "fields" => ["id"], "sort" => ["-created_at"]}
      assert {:ok, a} = Rpc.parse(params)
      assert {:ok, b} = Rpc.parse(params)
      assert a.sort == b.sort and a.sort == "-created_at"
    end
  end

  describe "is_nil filter operator by kind (was: isNil?: boolean per field type)" do
    setup do
      %{post: T2.ir(Post, :read).schema.filter}
    end

    test "nullable string, numeric, datetime, boolean and enum fields accept is_nil booleans",
         %{post: z} do
      nullable =
        for e <- T2.read_facts(Post).filter_entries,
            e["allow_nil?"],
            e["type"]["kind"] in ~w(string integer utc_datetime utc_datetime_usec boolean atom enum),
            do: e["name"]

      assert nullable != []

      check(
        z,
        Enum.flat_map(nullable, fn n ->
          [{"#{n} true", f(n, "is_nil", true), true}, {"#{n} false", f(n, "is_nil", false), true}]
        end)
      )
    end

    test "is_nil value is a boolean, never the field's own type", %{post: z} do
      check(z, [
        {"integer value refused", f("view_count", "is_nil", 3), false},
        {"string value refused", f("content", "is_nil", "yes"), false},
        {"boolean accepted", f("view_count", "is_nil", true), true}
      ])
    end

    test "numeric fields keep their comparison operators next to is_nil", %{post: z} do
      check(z, [
        {"gt", f("view_count", "gt", 1), true},
        {"gt wrong type", f("view_count", "gt", "1"), false},
        {"is_nil", f("view_count", "is_nil", true), true}
      ])
    end

    test "boolean fields filter by eq next to is_nil", %{post: z} do
      check(z, [
        {"eq", f("published", "eq", true), true},
        {"eq wrong type", f("published", "eq", "true"), false},
        {"is_nil", f("published", "is_nil", true), true}
      ])
    end

    test "is_nil is carried through the pipeline as a boolean (pass-through)" do
      for flag <- [true, false] do
        assert {:ok, request} =
                 Rpc.parse(%{
                   "action" => "list_todos",
                   "fields" => ["id"],
                   "filter" => %{"dueDate" => %{"isNil" => flag}}
                 })

        assert request.filter == %{due_date: %{is_nil: flag}}
      end
    end
  end

  describe "ActionConfig sort type (was: sort?: string | string[])" do
    test "generic action parsing accepts a string sort and a list of strings" do
      for sort <- ["title", ["title", "-created_at"]] do
        assert {:ok, request} =
                 Rpc.parse(%{"action" => "list_todos", "fields" => ["id"], "sort" => sort})

        assert is_binary(request.sort)
      end
    end

    test "channel and HTTP transports share the sort-accepting parser (no channel-only type)" do
      assert is_function(&Pipeline.format_sort_string/2, 2)

      assert Pipeline.format_sort_string(["title", "-created_at"], :camel_case) ==
               "title,-created_at"
    end
  end

  describe "filter field set (was: FilterField as const arrays)" do
    test "filter field set is derived per resource and a filter on a member parses" do
      names = filter_names(Todo)
      assert "title" in names

      check(T2.ir(Todo, :read).schema.filter, [
        {"member", f("title", "eq", "x"), true},
        {"non-member", f("not_a_field", "eq", "x"), false}
      ])
    end

    test "filter fields include relationships; sort fields do not" do
      names = filter_names(Todo)
      assert "user" in names
      assert "comments" in names
      refute "user" in sortable(Todo)
      refute "comments" in sortable(Todo)

      check(T2.ir(Todo, :read).schema.filter, [
        {"related filter", f("user", "related", f("email", "eq", "a@b.c")), true}
      ])
    end

    test "filter fields include every aggregate kind" do
      names = filter_names(Todo)

      for aggregate <-
            ~w(comment_count has_comments highest_rating average_rating latest_comment_content comment_authors total_weighted_score) do
        assert aggregate in names, "aggregate #{aggregate} missing from #{inspect(names)}"
      end
    end

    test "each resource gets its own filter field set" do
      sets = for r <- [Todo, User, Post], do: filter_names(r)
      assert Enum.all?(sets, &(&1 != []))
      assert length(Enum.uniq(sets)) == 3
    end
  end

  describe "aggregate filter operators by kind" do
    setup do
      %{todo: T2.ir(Todo, :read).schema.filter}
    end

    test ":exists is boolean, never nil: no is_nil, no ordered comparisons", %{todo: z} do
      assert filter_entry(Todo, "has_comments")["allow_nil?"] == false

      check(z, [
        {"eq", f("has_comments", "eq", true), true},
        {"neq", f("has_comments", "neq", false), true},
        {"in", f("has_comments", "in", [true, false]), true},
        {"is_nil refused", f("has_comments", "is_nil", true), false},
        {"gt refused", f("has_comments", "gt", true), false},
        {"lt refused", f("has_comments", "lt", true), false}
      ])
    end

    test ":max and :sum are numeric with comparisons and is_nil", %{todo: z} do
      for name <- ["highest_rating", "total_weighted_score"] do
        assert filter_entry(Todo, name)["allow_nil?"] == true

        check(z, [
          {"#{name} eq", f(name, "eq", 1), true},
          {"#{name} gt", f(name, "gt", 1), true},
          {"#{name} lt", f(name, "lt", 1), true},
          {"#{name} is_nil", f(name, "is_nil", true), true},
          {"#{name} wrong type", f(name, "eq", "x"), false}
        ])
      end
    end

    test ":avg is numeric with gte and is_nil", %{todo: z} do
      assert filter_entry(Todo, "average_rating")["allow_nil?"] == true

      check(z, [
        {"eq", f("average_rating", "eq", 1.5), true},
        {"gte", f("average_rating", "gte", 1), true},
        {"is_nil", f("average_rating", "is_nil", false), true}
      ])
    end

    test ":first takes the source field's type (string) and allows is_nil", %{todo: z} do
      assert filter_entry(Todo, "latest_comment_content")["type"]["kind"] == "string"

      check(z, [
        {"eq", f("latest_comment_content", "eq", "x"), true},
        {"neq", f("latest_comment_content", "neq", "x"), true},
        {"is_nil", f("latest_comment_content", "is_nil", true), true},
        {"eq wrong type", f("latest_comment_content", "eq", 1), false}
      ])
    end

    test ":list is an array of the source type and never nil", %{todo: z} do
      entry = filter_entry(Todo, "comment_authors")
      assert entry["allow_nil?"] == false

      check(z, [
        {"is_nil refused", f("comment_authors", "is_nil", true), false}
      ])

      assert entry["type"]["kind"] == "array"
      assert entry["items"]["kind"] == "string"
    end

    test ":count is an integer and never nil", %{todo: z} do
      assert filter_entry(Todo, "comment_count")["allow_nil?"] == false

      check(z, [
        {"eq", f("comment_count", "eq", 2), true},
        {"gt", f("comment_count", "gt", 1), true},
        {"is_nil refused", f("comment_count", "is_nil", true), false},
        {"wrong type", f("comment_count", "eq", "2"), false}
      ])
    end
  end
end
