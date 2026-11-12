defmodule AshSurface.Compiler.IRWiringTest do
  @moduledoc """
  Wave 3 / w3-01: the normalized action carries resource facts and
  `Fragments.enrich/2` renders them with the Phase-A renderers. Real Ash
  fixture resources, real compile, real codec; no doubles.
  """
  use ExUnit.Case, async: true

  alias Ash.Info.Manifest
  alias AshSurface.Compiler
  alias AshSurface.IR.Codec
  alias AshSurface.Projector.IREntry
  alias AshSurface.Projectors.JS.ZodGuard
  alias AshSurface.ZodFixtures.{CalcAgg, IdentityTenant, Paging, Relations}

  defp compile!(domain) do
    assert {:ok, irs} = Compiler.compile(domain)

    Map.new(irs, fn ir ->
      {"#{ir.ash.resource |> inspect() |> String.split(".") |> List.last()}.#{ir.ash.action}", ir}
    end)
  end

  defp zod_strings(value) when is_binary(value), do: [value]

  defp zod_strings(%{} = map) when not is_struct(map),
    do: map |> Map.values() |> Enum.flat_map(&zod_strings/1)

  defp zod_strings(_), do: []

  describe "response_zod (record schema wiring)" do
    test "read and create carry a non-nil record schema; no_record_schema reason is gone" do
      irs = compile!(Paging.Domain)
      schema = irs["Row.mixed"].schema
      assert is_binary(schema.response_zod)
      assert schema.response_zod =~ "z.object"
      refute Map.get(schema.nil_reasons || %{}, "response_zod")

      creates =
        for {_id, ir} <- irs, ir.ash.action_type == "create", do: ir.schema.response_zod

      assert Enum.all?(creates, &is_binary/1)
    end
  end

  describe "query fragments from resource fields" do
    setup do: %{irs: compile!(Paging.Domain)}

    test "sort comes from sortable resource fields, honouring sortable?: false", %{irs: irs} do
      sort = irs["Row.mixed"].schema.sort
      assert sort =~ "name"
      assert sort =~ "rank"
      assert sort =~ "onlyFilter" == false
      refute sort =~ "secret"

      assert irs["Row.mixed"].schema.facts["sortable_fields"] |> Enum.sort() ==
               ["id", "name", "onlySort", "rank"]
    end

    test "filter comes from filterable resource fields, honouring filterable?: false", %{irs: irs} do
      filter = irs["Row.mixed"].schema.filter
      assert filter =~ "onlyFilter"
      assert filter =~ "rank"
      refute filter =~ "onlySort"
      refute filter =~ "secret"
    end

    test "pagination facts carry default_limit and max_page_size; max_limit reaches the envelope",
         %{irs: irs} do
      schema = irs["Row.mixed"].schema

      assert %{
               "default_limit" => 25,
               "max_page_size" => 100,
               "offset?" => true,
               "keyset?" => true
             } = schema.facts["pagination"]

      assert schema.page =~ ".max(100)"
    end

    test "create action: query fragments are nil with typed reasons", %{irs: irs} do
      schema = irs["Row.create"].schema
      assert schema.filter == nil and schema.sort == nil and schema.page == nil
      assert schema.nil_reasons["filter"] == "not_a_read_action"
      assert schema.nil_reasons["sort"] == "not_a_read_action"
      assert schema.nil_reasons["page"] == "not_a_read_action"
    end

    test "unpaginated read: page nil with reason no_pagination", %{irs: irs} do
      assert irs["Row.list_all"].schema.page == nil
      assert irs["Row.list_all"].schema.nil_reasons["page"] == "no_pagination"
    end
  end

  describe "get, identities, tenant" do
    setup do: %{irs: compile!(IdentityTenant.Domain)}

    test "get_by action: get input, identities, nil sort/filter with reasons", %{irs: irs} do
      schema = irs["Account.get_by_email"].schema
      assert schema.facts["get?"] == true
      assert schema.facts["get_by"] == ["email"]
      assert schema.get["input"] =~ "email"
      assert Map.has_key?(schema.get["identities"], "unique_email")
      assert schema.sort == nil
      assert schema.nil_reasons["sort"] == "get_action_has_no_sort"
      assert schema.nil_reasons["filter"] == "get_action_has_no_filter"
    end

    test "non-get read has no get fragment", %{irs: irs} do
      assert irs["Account.read"].schema.get == nil
      assert irs["Account.read"].schema.nil_reasons["get"] == "not_a_get_action"
    end

    test "attribute multitenancy yields a tenant parameter (required-ness is Config's); none otherwise",
         %{irs: irs} do
      assert irs["TenantNote.read"].schema.tenant =~ "z.string().min(1)"
      assert irs["TenantNote.read"].schema.facts["multitenancy"]["strategy"] == "attribute"
      assert irs["Account.read"].schema.tenant == nil
      assert irs["Account.read"].schema.nil_reasons["tenant"] == "no_tenant_parameter"
    end

    test "identities carry key kinds and the primary key", %{irs: irs} do
      facts = irs["Account.read"].schema.facts

      assert Enum.any?(
               facts["identities"],
               &(&1["name"] == "org_handle" and length(&1["keys"]) == 2)
             )

      assert facts["primary_key"] == ["id"]
    end
  end

  describe "relationships, calculations, aggregates" do
    test "load envelope and relationship facts follow public_relationships" do
      irs = compile!(Relations.Domain)
      schema = irs["Author.read"].schema
      posts = Enum.find(schema.facts["relationships"], &(&1["name"] == "posts"))
      profile = Enum.find(schema.facts["relationships"], &(&1["name"] == "profile"))
      assert posts["cardinality"] == "many"
      assert profile["cardinality"] == "one"
      assert schema.load =~ "posts"
      assert schema.selection =~ "load"
    end

    test "calculation and aggregate facts render load, results and aggregate schemas" do
      irs = compile!(CalcAgg.Domain)
      schema = irs["Item.read"].schema
      assert schema.calculations["load"] =~ "padded"
      assert Map.has_key?(schema.calculations["results"], "shout")

      assert Map.keys(schema.aggregates) |> Enum.sort() ==
               ~w(allLabels avgPrice firstLabel hasLines lineCount maxPrice minPrice totalQty)

      padded = Enum.find(schema.facts["calculations"], &(&1["name"] == "padded"))

      assert [%{"name" => "prefix", "allow_nil?" => false, "has_default?" => false}] =
               padded["arguments"]

      count = Enum.find(schema.facts["aggregates"], &(&1["name"] == "lineCount"))
      assert count["kind"] == "count"
    end
  end

  describe "invariants over every fixture domain" do
    setup do
      irs =
        [Paging.Domain, IdentityTenant.Domain, Relations.Domain, CalcAgg.Domain]
        |> Enum.flat_map(&(&1 |> compile!() |> Map.values()))

      %{irs: irs}
    end

    test "every emitted zod string is admitted by ZodGuard", %{irs: irs} do
      for ir <- irs,
          fragment <-
            [
              ir.schema.filter,
              ir.schema.sort,
              ir.schema.page,
              ir.schema.tenant,
              ir.schema.load,
              ir.schema.selection,
              ir.schema.response_zod,
              ir.schema.validation_error
            ] ++
              zod_strings(ir.schema.get) ++
              zod_strings(ir.schema.calculations["results"]) ++
              zod_strings(ir.schema.calculations && Map.delete(ir.schema.calculations, "results")) ++
              zod_strings(ir.schema.aggregates) ++
              zod_strings(ir.schema.error),
          is_binary(fragment) and String.starts_with?(fragment, "z.") do
        assert {:ok, :expression, _} = ZodGuard.admit(fragment),
               "refused: #{String.slice(fragment, 0, 120)}"
      end
    end

    test "every honest-nil fragment records a typed reason", %{irs: irs} do
      keys =
        ~w(filter sort page get tenant load selection calculations aggregates validation_error)

      for ir <- irs, key <- keys, Map.get(ir.schema, String.to_existing_atom(key)) == nil do
        assert ir.schema.nil_reasons[key] != nil,
               "#{ir.ash.resource}.#{ir.ash.action}: nil #{key} without reason"
      end
    end

    test "to_map/from_map closes and IREntry exposes the new facts", %{irs: irs} do
      for ir <- irs do
        map = ir |> Codec.to_map() |> Jason.encode!() |> Jason.decode!()
        assert {:ok, back} = Codec.from_map(map)
        assert Codec.to_map(back) == map

        [entry] = IREntry.entries(ir)
        assert entry.facts == ir.schema.facts
        assert entry.nil_reasons == ir.schema.nil_reasons
        assert entry.get == ir.schema.get
        assert entry.tenant == ir.schema.tenant
        assert entry.load_zod == ir.schema.load
        assert entry.selection_zod == ir.schema.selection
      end
    end

    test "compilation is deterministic", %{irs: irs} do
      again =
        [Paging.Domain, IdentityTenant.Domain, Relations.Domain, CalcAgg.Domain]
        |> Enum.flat_map(&(&1 |> compile!() |> Map.values()))

      assert Enum.map(irs, &Codec.to_map/1) == Enum.map(again, &Codec.to_map/1)
    end
  end

  describe "manifest path" do
    test "manifest entrypoints carry the same resource facts, with manifest pagination" do
      manifest = %Manifest{
        entrypoints: [
          %Manifest.Entrypoint{
            resource: IdentityTenant.Account,
            action: %Manifest.Action{
              name: :read,
              type: :read,
              get?: false,
              inputs: [],
              metadata: [],
              pagination: %Manifest.Pagination{
                offset?: true,
                keyset?: false,
                required?: false,
                countable?: true,
                default_limit: 20,
                max_page_size: 50
              }
            }
          }
        ]
      }

      assert {:ok, [ir]} = Compiler.compile(manifest)
      assert ir.schema.facts["pagination"]["max_page_size"] == 50
      assert ir.schema.page =~ ".max(50)"
      assert ir.schema.facts["sortable_fields"] == ["email", "handle", "id", "org"]
      assert ir.schema.filter =~ "email"
    end

    test "a non-resource module degrades to nil facts with the typed reason" do
      facts = AshSurface.Compiler.ResourceFacts.build(Enum, %{name: :read, type: :read})
      assert facts.unknown_reasons["resource"] == "resource_not_introspectable"
      assert facts.filter_entries == nil and facts.sortable_fields == nil and facts.get? == false

      schema =
        AshSurface.Compiler.IR.Fragments.enrich(
          %AshSurface.IR.Schema{},
          Map.merge(%{action_type: :read, inputs: [], id: "Enum.read"}, facts)
        )

      assert schema.filter == nil
      assert schema.nil_reasons["filter"] == "resource_not_introspectable"
      assert schema.nil_reasons["sort"] == "resource_not_introspectable"
    end
  end
end
