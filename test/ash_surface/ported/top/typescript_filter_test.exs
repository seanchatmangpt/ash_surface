Code.require_file("support/t2.exs", __DIR__)

defmodule AshSurface.Ported.Top.TypescriptFilterTest do
  @moduledoc """
  Adaptation of ash_typescript `typescript_filter_test.exs`. The reference asserts substrings of
  generated `PostFilterInput` TS text; ash_surface emits a typed-filter Zod union per read action
  (`ir.schema.filter`, a tagged `{field, op, value}` tree, not per-field operator objects). Every
  reference expectation is therefore restated as accept/reject payloads executed under real node +
  zod against the filter schema the real compiler produced for the ported `Post`/`Todo`/... fixtures.
  Operator spelling is the surface key set (`neq`, `gt`, `starts_with`, ...), not camelCased TS keys.
  Operator-name formatting is a registered divergence (fixed operator literals under every
  formatter), executed in `divergence_close/field_naming_divergence_test.exs`.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Ported.{
    EmptyResource,
    NoRelationshipsResource,
    Post,
    T2,
    Todo,
    User
  }

  setup_all do
    %{
      post: T2.ir(Post, :read).schema.filter,
      todo: T2.ir(Todo, :read).schema.filter
    }
  end

  # cases: [{label, payload, expected_accept?}] -> asserts each under one node run
  defp check(zod, cases) do
    assert {:ok, oks} = T2.node_eval(zod, Enum.map(cases, &elem(&1, 1)))

    for {{label, _payload, expected}, ok} <- Enum.zip(cases, oks) do
      assert ok == expected, "#{label}: expected accept=#{expected}, got #{ok}"
    end
  end

  defp f(field, op, value), do: %{"field" => field, "op" => op, "value" => value}

  describe "operator key mapping (real FilterSchema.operator_key/1)" do
    alias AshSurface.Compiler.FilterSchema

    test "Ash operator spellings map to the exact surface keys" do
      for {ash, key} <- [
            {"==", "eq"},
            {"!=", "neq"},
            {"<", "lt"},
            {"<=", "lte"},
            {">", "gt"},
            {">=", "gte"},
            {"in", "in"},
            {"is_nil", "is_nil"}
          ] do
        assert FilterSchema.operator_key(ash) == {:ok, key}
      end

      assert FilterSchema.operator_key(:==) == {:ok, "eq"}
    end

    test "surface keys pass through unchanged; unknown operators are refused" do
      for key <- ["contains", "starts_with", "ends_with", "has", "has_any", "related", "eq", "gte"] do
        assert FilterSchema.operator_key(key) == {:ok, key}
      end

      assert FilterSchema.operator_key("zzz") == :error
      assert FilterSchema.operator_key(nil) == :error
    end
  end

  describe "filter schema for a resource (was: generate_filter_type/1)" do
    test "generates a basic filter union with and/or/not connectives", %{post: z} do
      check(z, [
        {"leaf", f("title", "eq", "x"), true},
        {"and", %{"op" => "and", "value" => [f("title", "eq", "x"), f("view_count", "gt", 1)]},
         true},
        {"or", %{"op" => "or", "value" => [f("title", "eq", "x")]}, true},
        {"not single", %{"op" => "not", "value" => f("title", "eq", "x")}, true},
        {"nested and in or",
         %{"op" => "or", "value" => [%{"op" => "and", "value" => [f("title", "eq", "x")]}]},
         true},
        {"unknown connective", %{"op" => "xor", "value" => [f("title", "eq", "x")]}, false},
        {"and needs an array", %{"op" => "and", "value" => f("title", "eq", "x")}, false}
      ])
    end

    test "includes string attribute filters", %{post: z} do
      check(z, [
        {"eq", f("title", "eq", "a"), true},
        {"neq", f("title", "neq", "a"), true},
        {"in", f("title", "in", ["a", "b"]), true},
        {"eq wrong type", f("title", "eq", 1), false},
        {"in wrong member type", f("title", "in", ["a", 1]), false},
        {"nullable content has is_nil", f("content", "is_nil", true), true}
      ])
    end

    test "includes boolean attribute filters without ordered comparisons", %{post: z} do
      check(z, [
        {"eq", f("published", "eq", true), true},
        {"neq", f("published", "neq", false), true},
        {"in", f("published", "in", [true, false]), true},
        {"is_nil (nullable)", f("published", "is_nil", true), true},
        {"gt rejected", f("published", "gt", true), false},
        {"lt rejected", f("published", "lt", true), false},
        {"gte rejected", f("published", "gte", true), false},
        {"lte rejected", f("published", "lte", true), false}
      ])
    end

    test "includes integer attribute filters with comparison operations", %{post: z} do
      check(z, [
        {"eq", f("view_count", "eq", 3), true},
        {"gt", f("view_count", "gt", 3), true},
        {"lt", f("view_count", "lt", 3), true},
        {"in", f("view_count", "in", [1, 2]), true},
        {"float rejected for integer", f("view_count", "eq", 1.5), false}
      ])
    end

    test "includes decimal attribute filters with comparison operations", %{post: z} do
      # decimal values travel as strings (ZodType: decimal => z.string())
      check(z, [
        {"eq", f("rating", "eq", "4.5"), true},
        {"gte", f("rating", "gte", "4.5"), true},
        {"lte", f("rating", "lte", "4.5"), true},
        {"number rejected", f("rating", "eq", 4.5), false}
      ])
    end

    test "includes datetime attribute filters with comparison operations", %{post: z} do
      check(z, [
        {"eq", f("published_at", "eq", "2024-01-01T00:00:00Z"), true},
        {"gt", f("published_at", "gt", "2024-01-01T00:00:00Z"), true},
        {"lt", f("published_at", "lt", "2024-01-01T00:00:00Z"), true},
        {"non-iso rejected", f("published_at", "eq", "yesterday"), false}
      ])
    end

    test "includes constrained atom attribute filters", %{post: z} do
      check(z, [
        {"eq", f("status", "eq", "draft"), true},
        {"in", f("status", "in", ["draft", "published", "archived"]), true},
        {"non-string rejected", f("status", "eq", 1), false}
      ])
    end

    test "constrained atom attribute filters narrow eq/neq/in to the one_of values", %{post: z} do
      check(z, [
        {"eq member", f("status", "eq", "draft"), true},
        {"neq member", f("status", "neq", "archived"), true},
        {"eq outside the set", f("status", "eq", "bogus"), false},
        {"neq outside the set", f("status", "neq", "bogus"), false},
        {"in members", f("status", "in", ["draft", "published"]), true},
        {"in with an outside value", f("status", "in", ["draft", "bogus"]), false}
      ])
    end

    test "string fields expose ordered comparison operators", %{post: z} do
      check(z, [
        {"gt", f("title", "gt", "a"), true},
        {"gte", f("title", "gte", "a"), true},
        {"lt", f("title", "lt", "z"), true},
        {"lte", f("title", "lte", "z"), true},
        {"gt wrong type", f("title", "gt", 1), false},
        {"contains kept", f("title", "contains", "a"), true}
      ])
    end

    test "compiled filter schema includes relationship filters (author, comments)", %{post: z} do
      check(z, [
        {"author related email", f("author", "related", f("email", "eq", "a@b.c")), true},
        {"comments related", f("comments", "related", f("content", "contains", "x")), true},
        {"related inside and",
         %{
           "op" => "and",
           "value" => [
             f("author", "related", f("email", "eq", "a")),
             f("comments", "related", f("content", "contains", "x"))
           ]
         }, true},
        {"related unknown field", f("author", "related", f("nope", "eq", "x")), false},
        {"related wrong value type", f("author", "related", f("email", "eq", 1)), false},
        {"unknown relationship", f("nobody", "related", f("email", "eq", "a")), false},
        {"plain op on a relationship", f("author", "eq", "x"), false}
      ])

      names = Enum.map(T2.read_facts(Post).filter_entries, & &1["name"])
      assert "author" in names and "comments" in names
    end

    test "includes array attribute filters", %{post: z} do
      # element membership (has / has_any) and whole-array equality (eq / in)
      check(z, [
        {"has", f("tags", "has", "elixir"), true},
        {"has_any", f("tags", "has_any", ["a", "b"]), true},
        {"has wrong element type", f("tags", "has", 1), false},
        {"eq whole array", f("tags", "eq", ["a"]), true},
        {"eq scalar rejected", f("tags", "eq", "a"), false},
        {"eq wrong element type", f("tags", "eq", [1]), false},
        {"in array of arrays", f("tags", "in", [["a"], ["b", "c"]]), true},
        {"in flat array rejected", f("tags", "in", ["a"]), false}
      ])
    end

    test "includes map attribute filters", %{post: z} do
      check(z, [
        {"eq", f("metadata", "eq", %{"a" => 1}), true},
        {"is_nil", f("metadata", "is_nil", true), true}
      ])
    end

    test "has on an array of maps takes the element type (a map) and the schema is valid Zod", %{
      post: z
    } do
      # TS reference regression: `has?` over Array<Record<string, any>> stripped the wrong `>`;
      # here the expression must construct under zod and type the element as an object.
      check(z, [
        {"has map element", f("revisions", "has", %{"rev" => 1}), true},
        {"has_any map elements", f("revisions", "has_any", [%{"rev" => 1}]), true},
        {"has string element rejected", f("revisions", "has", "rev"), false}
      ])
    end

    test "relationship filters render a related operator over the destination's filter inputs" do
      assert {:ok, zod} =
               AshSurface.Compiler.FilterSchema.render_filter_schema([
                 %{
                   "name" => "author",
                   "type" => %{"kind" => "map"},
                   "relationship" => %{
                     "filter_inputs" => T2.read_facts(User).filter_entries
                   }
                 }
               ])

      check(zod, [
        {"related email", f("author", "related", f("email", "eq", "a@b.c")), true},
        {"related unknown field", f("author", "related", f("nope", "eq", "x")), false},
        {"related wrong type", f("author", "related", f("email", "eq", 1)), false}
      ])

      # and the resource facts mark both Post relationships filterable with their destinations
      rels = Map.new(T2.read_facts(Post).relationships, &{&1["name"], &1})
      assert rels["author"]["filterable"] and rels["author"]["destination"] == inspect(User)
      assert rels["comments"]["filterable"] and rels["comments"]["cardinality"] == "many"
    end
  end

  describe "applicable operations per type (was: get_applicable_operations/2)" do
    test "string types get basic + contains operations, is_nil only when allow_nil?", %{post: z} do
      check(z, [
        {"title eq", f("title", "eq", "a"), true},
        {"title neq", f("title", "neq", "a"), true},
        {"title in", f("title", "in", ["a"]), true},
        {"title is_nil refused (allow_nil? false)", f("title", "is_nil", true), false},
        {"content eq", f("content", "eq", "a"), true},
        {"content is_nil (allow_nil? true)", f("content", "is_nil", true), true}
      ])
    end

    test "numeric types get comparison operations plus is_nil", %{post: z} do
      check(z, [
        {"eq", f("view_count", "eq", 1), true},
        {"gt", f("view_count", "gt", 1), true},
        {"lt", f("view_count", "lt", 1), true},
        {"in", f("view_count", "in", [1]), true},
        {"is_nil", f("view_count", "is_nil", true), true}
      ])
    end

    test "boolean types get equality/membership operators but not ordered comparisons", %{post: z} do
      check(z, [
        {"eq", f("published", "eq", true), true},
        {"neq", f("published", "neq", true), true},
        {"in", f("published", "in", [true]), true},
        {"is_nil", f("published", "is_nil", true), true},
        {"gt", f("published", "gt", true), false},
        {"lt", f("published", "lt", true), false},
        {"gte", f("published", "gte", true), false},
        {"lte", f("published", "lte", true), false}
      ])
    end
  end

  describe "filters for several resources (was: generate_all_filter_types/1)" do
    test "each resource gets its own distinct filter schema", %{post: post} do
      user = T2.ir(User, :read).schema.filter
      assert is_binary(user) and is_binary(post)
      refute user == post

      check(user, [
        {"user email", f("email", "eq", "a@b.c"), true},
        {"post title on user", f("title", "eq", "x"), false}
      ])

      check(post, [
        {"post title", f("title", "eq", "x"), true},
        {"user email on post", f("email", "eq", "a@b.c"), false}
      ])
    end
  end

  describe "edge cases and error handling" do
    test "resource with no public attributes yields no filter schema (typed reason, not empty text)" do
      facts = T2.read_facts(EmptyResource)
      assert facts.filter_entries == nil
      assert facts.unknown_reasons["filter_entries"] == "no_filterable_fields"

      assert {:error, :no_filterable_fields} =
               AshSurface.Compiler.FilterSchema.render_filter_schema([])

      assert T2.ir(EmptyResource, :read).schema.filter == nil
    end

    test "resource with no relationships still filters its own fields" do
      z = T2.ir(NoRelationshipsResource, :read).schema.filter

      check(z, [
        {"name eq", f("name", "eq", "n"), true},
        {"unknown field", f("ghost", "eq", "n"), false}
      ])

      assert T2.read_facts(NoRelationshipsResource).relationships in [nil, []]
    end
  end

  describe "predicate function filters" do
    test "string fields expose contains / starts_with / ends_with", %{post: z} do
      check(z, [
        {"contains", f("title", "contains", "a"), true},
        {"starts_with", f("title", "starts_with", "a"), true},
        {"ends_with", f("title", "ends_with", "a"), true},
        {"contains non-string", f("title", "contains", 1), false}
      ])
    end

    test "array-of-string fields expose has taking one element of the item type", %{post: z} do
      check(z, [
        {"has string", f("tags", "has", "a"), true},
        {"has array rejected", f("tags", "has", ["a"]), false}
      ])
    end

    test "non-string, non-array fields do not get string/array predicates", %{post: z} do
      check(z, [
        {"contains on integer", f("view_count", "contains", "a"), false},
        {"starts_with on integer", f("view_count", "starts_with", "a"), false},
        {"ends_with on integer", f("view_count", "ends_with", "a"), false},
        {"has on integer", f("view_count", "has", 1), false},
        {"contains on boolean", f("published", "contains", "a"), false}
      ])
    end
  end

  describe "aggregate filter types" do
    test "sum aggregate over a calculation field gets numeric operations", %{todo: z} do
      check(z, [
        {"eq", f("total_weighted_score", "eq", 3), true},
        {"gt", f("total_weighted_score", "gt", 3), true},
        {"lt", f("total_weighted_score", "lt", 3), true},
        {"string rejected", f("total_weighted_score", "eq", "3"), false}
      ])
    end
  end

  describe "is_nil respects allow_nil?" do
    test "non-nullable attributes do NOT get is_nil", %{post: z} do
      check(z, [
        {"id", f("id", "is_nil", true), false},
        {"title", f("title", "is_nil", true), false}
      ])
    end

    test "nullable attributes DO get is_nil", %{post: z} do
      check(z, [
        {"content", f("content", "is_nil", true), true},
        {"published", f("published", "is_nil", true), true}
      ])
    end

    test "nullable aggregates (first/max/sum) get is_nil; non-nullable (count) do not", %{todo: z} do
      check(z, [
        {"first aggregate nullable", f("latest_comment_content", "is_nil", true), true},
        {"count aggregate never nil", f("comment_count", "is_nil", true), false},
        {"count aggregate eq", f("comment_count", "eq", 0), true}
      ])
    end
  end
end
