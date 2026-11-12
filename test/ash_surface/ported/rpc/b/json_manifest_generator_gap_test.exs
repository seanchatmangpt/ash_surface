defmodule AshSurface.Ported.Rpc.B.JsonManifestGeneratorGapTest do
  use ExUnit.Case, async: true

  describe "files section (TS artifact paths)" do
    @tag skip:
           "GU-T9 gap: ash_surface generates no .ts files (README: \"no generated `.ts`, no `.d.ts`, no `tsc` build step\"), so the manifest has no files section of importPath/filename entries for generated TS artifacts; not representable under KD-07"
    test "has files section with generated file entries" do
      :ok
    end

    @tag skip:
           "GU-T9 gap: ash_surface generates no .ts files (README: \"no generated `.ts`, no `.d.ts`, no `tsc` build step\"), so the manifest has no files section of importPath/filename entries for generated TS artifacts; not representable under KD-07"
    test "each entry has importPath and filename" do
      :ok
    end

    @tag skip:
           "GU-T9 gap: ash_surface generates no .ts files (README: \"no generated `.ts`, no `.d.ts`, no `tsc` build step\"), so the manifest has no files section of importPath/filename entries for generated TS artifacts; not representable under KD-07"
    test "rpc file entry" do
      :ok
    end

    @tag skip:
           "GU-T9 gap: ash_surface generates no .ts files (README: \"no generated `.ts`, no `.d.ts`, no `tsc` build step\"), so the manifest has no files section of importPath/filename entries for generated TS artifacts; not representable under KD-07"
    test "types file entry" do
      :ok
    end

    @tag skip:
           "GU-T9 gap: ash_surface generates no .ts files (README: \"no generated `.ts`, no `.d.ts`, no `tsc` build step\"), so the manifest has no files section of importPath/filename entries for generated TS artifacts; not representable under KD-07"
    test "zod file entry when zod enabled" do
      :ok
    end

    @tag skip:
           "GU-T9 gap: ash_surface generates no .ts files (README: \"no generated `.ts`, no `.d.ts`, no `tsc` build step\"), so the manifest has no files section of importPath/filename entries for generated TS artifacts; not representable under KD-07"
    test "valibot file entry when valibot enabled" do
      :ok
    end

    @tag skip:
           "GU-T9 gap: ash_surface generates no .ts files (README: \"no generated `.ts`, no `.d.ts`, no `tsc` build step\"), so the manifest has no files section of importPath/filename entries for generated TS artifacts; not representable under KD-07"
    test "routes file entry when typed controllers configured" do
      :ok
    end

    @tag skip:
           "GU-T9 gap: ash_surface generates no .ts files (README: \"no generated `.ts`, no `.d.ts`, no `tsc` build step\"), so the manifest has no files section of importPath/filename entries for generated TS artifacts; not representable under KD-07"
    test "typed channels file entry when configured" do
      :ok
    end

    @tag skip:
           "GU-T9 gap: ash_surface generates no .ts files (README: \"no generated `.ts`, no `.d.ts`, no `tsc` build step\"), so the manifest has no files section of importPath/filename entries for generated TS artifacts; not representable under KD-07"
    test "basename format returns bare filename" do
      :ok
    end

    @tag skip:
           "GU-T9 gap: ash_surface generates no .ts files (README: \"no generated `.ts`, no `.d.ts`, no `tsc` build step\"), so the manifest has no files section of importPath/filename entries for generated TS artifacts; not representable under KD-07"
    test "absolute format returns absolute path" do
      :ok
    end

    @tag skip:
           "GU-T9 gap: ash_surface generates no .ts files (README: \"no generated `.ts`, no `.d.ts`, no `tsc` build step\"), so the manifest has no files section of importPath/filename entries for generated TS artifacts; not representable under KD-07"
    test "relative format (default) returns path relative to manifest" do
      :ok
    end

    @tag skip:
           "GU-T9 gap: ash_surface generates no .ts files (README: \"no generated `.ts`, no `.d.ts`, no `tsc` build step\"), so the manifest has no files section of importPath/filename entries for generated TS artifacts; not representable under KD-07"
    test "importPath is unaffected by filename format" do
      :ok
    end
  end

  describe "action type names (TS type/variant exports)" do
    @tag skip:
           "GU-T9 gap: the reference asserts generated TypeScript type names (ListTodosResult/Fields/InferResult/Config/FilterInput); ash_surface emits no TS types, so KD-07 manifest carries structural facts (pagination, enableFilter/enableSort, hasFields, input) instead, covered in json_manifest_generator_surface_test.exs"
    test "every action has a result type" do
      :ok
    end

    @tag skip:
           "GU-T9 gap: the reference asserts generated TypeScript type names (ListTodosResult/Fields/InferResult/Config/FilterInput); ash_surface emits no TS types, so KD-07 manifest carries structural facts (pagination, enableFilter/enableSort, hasFields, input) instead, covered in json_manifest_generator_surface_test.exs"
    test "has correct type names" do
      :ok
    end

    @tag skip:
           "GU-T9 gap: the reference asserts generated TypeScript type names (ListTodosResult/Fields/InferResult/Config/FilterInput); ash_surface emits no TS types, so KD-07 manifest carries structural facts (pagination, enableFilter/enableSort, hasFields, input) instead, covered in json_manifest_generator_surface_test.exs"
    test "has fields but no config type" do
      :ok
    end

    @tag skip:
           "GU-T9 gap: the reference asserts generated TypeScript type names (ListTodosResult/Fields/InferResult/Config/FilterInput); ash_surface emits no TS types, so KD-07 manifest carries structural facts (pagination, enableFilter/enableSort, hasFields, input) instead, covered in json_manifest_generator_surface_test.exs"
    test "has only result type" do
      :ok
    end

    @tag skip:
           "GU-T9 gap: the reference asserts generated TypeScript type names (ListTodosResult/Fields/InferResult/Config/FilterInput); ash_surface emits no TS types, so KD-07 manifest carries structural facts (pagination, enableFilter/enableSort, hasFields, input) instead, covered in json_manifest_generator_surface_test.exs"
    test "have fields and input types" do
      :ok
    end

    @tag skip:
           "GU-T9 gap: the reference asserts generated TypeScript type names (ListTodosResult/Fields/InferResult/Config/FilterInput); ash_surface emits no TS types, so KD-07 manifest carries structural facts (pagination, enableFilter/enableSort, hasFields, input) instead, covered in json_manifest_generator_surface_test.exs"
    test "filter disabled omits filterInput type" do
      :ok
    end
  end

  describe "variant names (TS function/schema exports)" do
    @tag skip:
           "GU-T9 gap: validation/zod/valibot/channel variant export names are TS codegen artifacts; ash_surface has no valibot projection and no generated function exports to resolve"
    test "includes validation, zod, valibot, and channel names when all enabled" do
      :ok
    end

    @tag skip:
           "GU-T9 gap: validation/zod/valibot/channel variant export names are TS codegen artifacts; ash_surface has no valibot projection and no generated function exports to resolve"
    test "every advertised function variant name resolves to a real export" do
      :ok
    end

    @tag skip:
           "GU-T9 gap: validation/zod/valibot/channel variant export names are TS codegen artifacts; ash_surface has no valibot projection and no generated function exports to resolve"
    test "input-less actions advertise no schema variant" do
      :ok
    end

    @tag skip:
           "GU-T9 gap: validation/zod/valibot/channel variant export names are TS codegen artifacts; ash_surface has no valibot projection and no generated function exports to resolve"
    test "every advertised schema name resolves to a real export" do
      :ok
    end
  end

  describe "typed controller routes" do
    # Real route maps through RouteSchema.build (no stubs); valibot has no ash_surface
    # projection, so valibot-named tests assert it is never advertised.
    alias AshSurface.Manifest.ActionManifest
    alias AshSurface.Ported, as: P
    alias AshSurface.Ported.RFP

    @str %{"type" => %{"kind" => "string"}}
    @id %{"name" => "id", "allow_nil?" => false, "type" => %{"kind" => "uuid"}}
    @routes [
      %{
        "name" => "list",
        "method" => "get",
        "path" => "/todos",
        "returns" => @str,
        "arguments" => [%{"name" => "q", "type" => %{"kind" => "string"}}],
        "description" => "List them",
        "see" => "show",
        "namespace" => "todos"
      },
      %{
        "name" => "show",
        "method" => "get",
        "path" => "/todos/:id",
        "returns" => @str,
        "arguments" => [@id],
        "zod_schema_name" => "TodoShape",
        "deprecated" => "Use list"
      },
      %{
        "name" => "create",
        "method" => "post",
        "path" => "/todos",
        "returns" => @str,
        "arguments" => [
          %{"name" => "title", "allow_nil?" => false, "type" => %{"kind" => "string"}}
        ],
        "valibot_schema_name" => "ignoredValibot"
      },
      %{"name" => "ping", "method" => "post", "path" => "/ping", "arguments" => []},
      %{
        "name" => "stats",
        "method" => "get",
        "path" => "/stats",
        "returns" => @str,
        "deprecated" => true
      }
    ]

    setup do
      built = ActionManifest.build(RFP.manifest(), P.Rpc.entries(), routes: @routes)
      m = Jason.decode!(ActionManifest.to_json(built))
      {:ok, m: m, routes: Map.new(m["routes"], &{&1["name"], &1})}
    end

    test "routes is a list", %{m: m} do
      assert is_list(m["routes"]) and length(m["routes"]) == 5
      refute Map.has_key?(ActionManifest.build(RFP.manifest(), P.Rpc.entries()), "routes")
    end

    test "each route has required fields", %{m: m} do
      for r <- m["routes"] do
        assert is_binary(r["name"]) and is_binary(r["path"])
        assert r["method"] in ["get", "post"]
        assert is_list(r["pathParams"])
        assert is_boolean(r["mutation"]) and is_boolean(r["hasInput"])
        assert r["inputKind"] in ["none", "query", "body"]
      end
    end

    test "GET routes declaring returns advertise their response", %{routes: r} do
      assert r["list"]["hasResponse"] and r["show"]["hasResponse"] and r["stats"]["hasResponse"]
    end

    test "GET routes are not mutations", %{routes: r} do
      refute r["list"]["mutation"]
      refute r["show"]["mutation"]
    end

    test "POST routes are mutations with types", %{routes: r} do
      assert r["create"]["mutation"] and r["create"]["inputKind"] == "body"
      assert r["create"]["hasInput"] and r["ping"]["mutation"]
    end

    test "routes declaring returns advertise their result type", %{routes: r} do
      assert r["create"]["hasResponse"]
      refute r["ping"]["hasResponse"]
    end

    test "route zod name honors the zod_schema_name override", %{routes: r} do
      assert r["show"]["zodSchemaName"] == "TodoShape"
      assert r["list"]["zodSchemaName"] == "listResponse"
    end

    test "mutation routes with input advertise no valibot schemas (no projection)", %{routes: r} do
      refute Enum.any?(Map.keys(r["create"]), &String.contains?(&1, "valibot"))
      assert r["create"]["hasInput"]
    end

    test "route valibot_schema_name override is never advertised", %{routes: r} do
      refute Jason.encode!(r["create"]) =~ "ignoredValibot"
    end

    test "mutation routes without input advertise no schemas at all", %{routes: r} do
      assert r["ping"]["inputKind"] == "none"
      refute r["ping"]["hasInput"] or r["ping"]["hasResponse"]
    end

    test "GET routes with query args advertise their input kind", %{routes: r} do
      assert r["list"]["inputKind"] == "query" and r["list"]["hasInput"]
    end

    test "routes without arguments carry no input", %{routes: r} do
      assert r["stats"]["inputKind"] == "none"
      refute r["stats"]["hasInput"]
    end

    test "routes with path params list them", %{routes: r} do
      assert r["show"]["pathParams"] == ["id"]
      assert r["list"]["pathParams"] == []
    end

    test "advertises descriptors and metadata, with no fetch functions", %{routes: r, m: m} do
      assert r["list"]["description"] == "List them" and r["list"]["namespace"] == "todos"
      assert r["show"]["deprecated"] == "Use list" and r["stats"]["deprecated"] == true
      refute Enum.any?(m["routes"], &Map.has_key?(&1, "fetchFunction"))

      assert_raise ArgumentError, fn ->
        ActionManifest.build(RFP.manifest(), P.Rpc.entries(),
          routes: [%{"method" => "get", "path" => "/x/:id", "name" => "x", "arguments" => []}]
        )
      end
    end
  end
end
