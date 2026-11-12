defmodule AshSurface.Compiler.RelationshipSelectionSchemaTest do
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.{RelationshipSchema, SelectionSchema}
  alias AshSurface.Projectors.JS.ZodGuard

  defp rels do
    [
      %{
        "name" => "author",
        "destination" => "User",
        "cardinality" => "one",
        "primitive_fields" => ["name", "id"]
      },
      %{
        "name" => "comments",
        "destination" => "Comment",
        "cardinality" => "many",
        "primitive_fields" => [%{"name" => "body"}],
        "relationships" => [
          %{
            "name" => "likes",
            "destination" => "Like",
            "cardinality" => "many",
            "relationships" => [%{"name" => "who", "destination" => "U", "cardinality" => "one"}]
          }
        ]
      }
    ]
  end

  test "destination primitive enum, sorted; absent facts fall back to string" do
    {:ok, zod, _} = RelationshipSchema.render_load_schema(rels())

    assert zod =~
             ~s|"author": z.union([z.literal(true), z.object({fields: z.array(z.enum(["id", "name"])).min(1)})|

    assert zod =~ ~s|z.array(z.enum(["body"])).min(1)|
    assert zod =~ "fields: z.array(z.string()).min(1)"
    assert {:ok, _, _} = ZodGuard.admit(zod)
  end

  test "many carries query envelope with exclusive pagination; one does not" do
    {:ok, zod, _} = RelationshipSchema.render_load_schema(rels())
    [author_part | _] = String.split(zod, ~s|"comments":|)
    refute author_part =~ "filter:"
    refute author_part =~ "limit:"
    assert zod =~ "filter: z.partialRecord(z.enum([\"body\"]), z.unknown()).optional()"
    {:ok, flat, _} = RelationshipSchema.render_load_schema(Enum.take(rels(), -1), max_depth: 0)
    # one strict base declaring limit/offset/page + an exclusivity intersection
    assert flat =~ "z.intersection(z.object({"
    assert flat =~ "limit:" and flat =~ "offset:" and flat =~ "page:"
    assert flat =~ "page: z.never().optional()"
    assert length(String.split(flat, "z.array(z.enum(")) == 2
  end

  test "depth bound: static expansion, no z.lazy" do
    {:ok, d2, _} = RelationshipSchema.render_load_schema(rels())
    assert d2 =~ ~s|"likes"|
    assert d2 =~ ~s|"who"|
    {:ok, d0, _} = RelationshipSchema.render_load_schema(rels(), max_depth: 0)
    refute d0 =~ "likes"
    {:ok, d1, _} = RelationshipSchema.render_load_schema(rels(), max_depth: 1)
    assert d1 =~ "likes"
    refute d1 =~ "who"
    refute d2 =~ "lazy"
  end

  test "deterministic and validation errors" do
    assert RelationshipSchema.render_load_schema(rels()) ==
             RelationshipSchema.render_load_schema(rels())

    assert {:error, {:invalid_primitive_fields, "a"}} =
             RelationshipSchema.render_load_schema([%{"name" => "a", "primitive_fields" => [1]}])

    assert {:error, :no_relationships} = RelationshipSchema.render_load_schema([])
  end

  test "selection embeds relationship load; legacy 2-arity unchanged" do
    assert {:ok, ~s|z.object({fields: z.array(z.enum(["a"]))}).strict()|} =
             SelectionSchema.render_selection_schema(["a", "b"], ["b"])

    {:ok, zod} = SelectionSchema.render_selection_schema(["a"], [], relationships: rels())
    assert zod =~ ~s|z.object({fields: z.array(z.enum(["a"])), load: z.object({|
    assert {:ok, _, _} = ZodGuard.admit(zod)

    assert {:ok, "z.object({fields: z.array(z.never()), load:" <> _} =
             SelectionSchema.render_selection_schema([], [], relationships: rels())
  end
end
