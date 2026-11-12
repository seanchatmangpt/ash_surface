defmodule AshSurface.Ported.Codegen.RelationshipMarkersTest do
  @moduledoc """
  Adaptation of ash_typescript `codegen/relationship_markers_test.exs`.

  The reference greps generated TypeScript for per-relationship marker properties
  (`__pagination`, `__filterInput`, `__sortField`) and for `UnifiedFieldSelection<..., F, S>`
  flags. ash_surface emits Zod (README: no `.ts`), where the same facts decide which keys the
  relationship load envelope admits. Each reference test is ported as: real Ash relationship
  -> `ResourceFacts` relationship facts -> `RelationshipSchema.render_load_schema/1` ->
  accept/reject cases executed under node with real zod.

  Marker mapping: `__pagination` = which of limit/offset/page arms are admitted;
  `__filterInput` = `filter` key admitted; `__sortField` = `sort` key admitted; to-one
  relationships carry none of them. The `enable_filter?`/`enable_sort?` flags map to the
  projection options of `ResourceFacts`.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.{RelationshipSchema, ResourceFacts}

  defmodule Comment do
    use Ash.Resource,
      domain: nil,
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    ets do
      private?(true)
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:body, :string, public?: true)
      attribute(:todo_id, :uuid, public?: true)
    end

    actions do
      # primary read: offset + keyset (mixed)
      read :read do
        primary?(true)

        pagination do
          offset?(true)
          keyset?(true)
          required?(false)
          default_limit(10)
        end
      end

      read :read_offset do
        pagination do
          offset?(true)
          keyset?(false)
          required?(false)
          default_limit(10)
        end
      end

      read :read_keyset do
        pagination do
          offset?(false)
          keyset?(true)
          required?(false)
          default_limit(10)
        end
      end

      read(:read_unpaginated)
    end
  end

  defmodule User do
    use Ash.Resource,
      domain: nil,
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    ets do
      private?(true)
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
    end

    actions do
      read :read do
        primary?(true)

        pagination do
          offset?(true)
          keyset?(true)
          required?(false)
          default_limit(10)
        end
      end
    end
  end

  defmodule Commenter do
    use Ash.Resource,
      domain: nil,
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    ets do
      private?(true)
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:todo_id, :uuid, public?: true)
      attribute(:user_id, :uuid, public?: true)
    end

    actions do
      defaults([:read])
    end
  end

  defmodule Todo do
    use Ash.Resource,
      domain: nil,
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false,
      extensions: [AshSurface.Resource]

    ets do
      private?(true)
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:title, :string, public?: true)
      attribute(:user_id, :uuid, public?: true)
    end

    relationships do
      has_many :comments, AshSurface.Ported.Codegen.RelationshipMarkersTest.Comment do
        destination_attribute(:todo_id)
        public?(true)
      end

      has_many :unfilterable_comments,
               AshSurface.Ported.Codegen.RelationshipMarkersTest.Comment do
        destination_attribute(:todo_id)
        public?(true)
        filterable?(false)
      end

      has_many :unsortable_comments, AshSurface.Ported.Codegen.RelationshipMarkersTest.Comment do
        destination_attribute(:todo_id)
        public?(true)
        sortable?(false)
      end

      has_many :unpaginated_comments, AshSurface.Ported.Codegen.RelationshipMarkersTest.Comment do
        destination_attribute(:todo_id)
        public?(true)
        read_action(:read_unpaginated)
      end

      has_many :offset_comments, AshSurface.Ported.Codegen.RelationshipMarkersTest.Comment do
        destination_attribute(:todo_id)
        public?(true)
        read_action(:read_offset)
      end

      has_many :keyset_comments, AshSurface.Ported.Codegen.RelationshipMarkersTest.Comment do
        destination_attribute(:todo_id)
        public?(true)
        read_action(:read_keyset)
      end

      many_to_many :commenters, AshSurface.Ported.Codegen.RelationshipMarkersTest.User do
        through(AshSurface.Ported.Codegen.RelationshipMarkersTest.Commenter)
        source_attribute_on_join_resource(:todo_id)
        destination_attribute_on_join_resource(:user_id)
        public?(true)
      end

      belongs_to :user, AshSurface.Ported.Codegen.RelationshipMarkersTest.User do
        public?(true)
        attribute_writable?(true)
      end
    end

    actions do
      defaults([:read])

      read(:list_todos_no_filter)
      read(:list_todos_no_sort)
      read(:list_todos_no_filter_no_sort)
    end

    surface do
      projection :read
      projection :list_todos_no_filter, enable_filter?: false
      projection :list_todos_no_sort, enable_sort?: false
      projection :list_todos_no_filter_no_sort, enable_filter?: false, enable_sort?: false
    end
  end

  setup_all do
    facts = AshSurface.Ported.AshNames.facts(Todo, Ash.Resource.Info.action(Todo, :read))
    rels = Map.new(facts.relationships, &{&1["name"], &1})
    {:ok, zod, _descriptors} = RelationshipSchema.render_load_schema(facts.relationships)
    %{facts: facts, rels: rels, zod: zod}
  end

  # Executed under real zod: does the load envelope admit `{<rel>: <value>}`?
  defp admits?(zod, rel, value) do
    js =
      "import {z} from 'zod'; const s = #{zod}; " <>
        "const r = s.safeParse(JSON.parse(process.argv[1])); process.stdout.write(String(r.success));"

    {out, 0} =
      System.cmd("node", ["--input-type=module", "-e", js, Jason.encode!(%{rel => value})],
        cd: File.cwd!(),
        stderr_to_stdout: true
      )

    out == "true"
  end

  @fields %{fields: ["body"]}

  test "paginated filterable sortable relationship gets all three markers", %{
    rels: rels,
    zod: zod
  } do
    assert %{"pagination" => "mixed", "filterable" => true, "sortable" => true} = rels["comments"]
    assert rels["comments"]["destination"] =~ "Comment"
    assert rels["comments"]["cardinality"] == "many"

    assert admits?(zod, "comments", Map.put(@fields, :filter, %{body: "x"}))
    assert admits?(zod, "comments", Map.put(@fields, :sort, "-body"))
    assert admits?(zod, "comments", Map.put(@fields, :page, %{limit: 5, offset: 0}))
    assert admits?(zod, "comments", Map.put(@fields, :page, %{limit: 5, after: "c"}))
  end

  test "unfilterable relationship omits only __filterInput", %{rels: rels, zod: zod} do
    assert %{"filterable" => false, "sortable" => true, "pagination" => "mixed"} =
             rels["unfilterable_comments"]

    refute admits?(zod, "unfilterable_comments", Map.put(@fields, :filter, %{body: "x"}))
    assert admits?(zod, "unfilterable_comments", Map.put(@fields, :sort, "body"))
    assert admits?(zod, "unfilterable_comments", Map.put(@fields, :page, %{limit: 5}))
  end

  test "unsortable relationship omits only __sortField", %{rels: rels, zod: zod} do
    assert %{"sortable" => false, "filterable" => true} = rels["unsortable_comments"]

    refute admits?(zod, "unsortable_comments", Map.put(@fields, :sort, "body"))
    assert admits?(zod, "unsortable_comments", Map.put(@fields, :filter, %{body: "x"}))
  end

  test "unpaginated relationship omits only __pagination", %{rels: rels, zod: zod} do
    assert %{"pagination" => "none", "filterable" => true} = rels["unpaginated_comments"]

    refute admits?(zod, "unpaginated_comments", Map.put(@fields, :page, %{limit: 5}))
    refute admits?(zod, "unpaginated_comments", Map.put(@fields, :limit, 5))
    assert admits?(zod, "unpaginated_comments", Map.put(@fields, :filter, %{body: "x"}))
  end

  test "pure pagination variants get the matching __pagination marker", %{rels: rels, zod: zod} do
    assert rels["offset_comments"]["pagination"] == "offset"
    assert admits?(zod, "offset_comments", Map.put(@fields, :page, %{limit: 5, offset: 1}))
    refute admits?(zod, "offset_comments", Map.put(@fields, :page, %{limit: 5, after: "c"}))

    assert rels["keyset_comments"]["pagination"] == "keyset"
    assert admits?(zod, "keyset_comments", Map.put(@fields, :page, %{limit: 5, after: "c"}))
    refute admits?(zod, "keyset_comments", Map.put(@fields, :page, %{limit: 5, offset: 1}))
  end

  test "many_to_many relationships get markers like has_many", %{rels: rels, zod: zod} do
    assert %{"cardinality" => "many", "pagination" => "mixed", "filterable" => true} =
             rels["commenters"]

    assert rels["commenters"]["destination"] =~ "User"
    assert admits?(zod, "commenters", %{fields: ["name"], filter: %{name: "x"}, sort: "name"})
    assert admits?(zod, "commenters", %{fields: ["name"], page: %{limit: 2}})
  end

  test "Fields types carry the action's enable flags", %{facts: _} do
    flags = fn action ->
      f = AshSurface.Ported.AshNames.facts(Todo, Ash.Resource.Info.action(Todo, action))
      {f.enable_filter?, f.enable_sort?, f.filter_entries != nil, f.sortable_fields != nil}
    end

    # enable_filter?: false, enable_sort?: true
    assert flags.(:list_todos_no_filter) == {false, true, false, true}
    # enable_sort?: false, enable_filter?: true
    assert flags.(:list_todos_no_sort) == {true, false, true, false}
    # both disabled
    assert flags.(:list_todos_no_filter_no_sort) == {false, false, false, false}
    # defaults stay enabled (source compatibility)
    assert flags.(:read) == {true, true, true, true}
  end

  test "to-one relationships never get markers", %{rels: rels, zod: zod} do
    assert %{"cardinality" => "one", "pagination" => "none"} = rels["user"]

    assert admits?(zod, "user", %{fields: ["name"]})
    refute admits?(zod, "user", %{fields: ["name"], filter: %{name: "x"}})
    refute admits?(zod, "user", %{fields: ["name"], sort: "name"})
    refute admits?(zod, "user", %{fields: ["name"], page: %{limit: 1}})
  end
end
