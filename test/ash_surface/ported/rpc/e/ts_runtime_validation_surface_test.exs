defmodule AshSurface.Ported.Rpc.E.TsRuntimeValidationSurfaceTest do
  @moduledoc """
  Port of ash_typescript `rpc/ts_runtime_validation_test.exs` (1 parametrized test over 24
  `test/ts/shouldPass/*.ts` files). ash_surface ships no generated TypeScript and no
  `run_action`; the reference extracts RPC calls from the .ts files and runs them. The
  equivalent here: for every RPC entry in the installed table, request shapes of the same
  families (fields, nested selections, getBy, identity, pagination, input) parse without
  refusal. Execution is the non-actuating pipeline's stage 1 only.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.{Rpc, RpcFixtures}

  @requests [
    {"operations", %{"action" => "list_todos", "fields" => ["id", "title"]}},
    {"calculations",
     %{
       "action" => "get_todo",
       "input" => %{"id" => "x"},
       "fields" => ["id", "isOverdue", "daysUntilDue"]
     }},
    {"relationships",
     %{"action" => "list_todos", "fields" => ["id", %{"user" => ["id", "name"]}]}},
    {"embeddedResources",
     %{
       "action" => "list_todos",
       "fields" => ["id", %{"metadata" => ["category", "priorityScore"]}]
     }},
    {"get", %{"action" => "get_single_todo", "fields" => ["id", "title"]}},
    {"getBy",
     %{"action" => "get_user_by_email", "getBy" => %{"email" => "a@b.c"}, "fields" => ["id"]}},
    {"identities",
     %{
       "action" => "update_user_by_email",
       "identity" => %{"email" => "a@b.c"},
       "input" => %{},
       "fields" => ["id"]
     }},
    {"conditionalPagination",
     %{"action" => "list_todos", "fields" => ["id"], "page" => %{"limit" => 5}}},
    {"noFields", %{"action" => "destroy_todo", "identity" => "id-1"}},
    {"complexScenarios",
     %{
       "action" => "list_todos",
       "fields" => ["id", %{"comments" => ["id", %{"user" => ["id"]}]}, "commentCount"]
     }}
  ]

  for {{name, params}, idx} <- Enum.with_index(@requests) do
    @params params
    test "001.#{idx} validates request shapes from #{name}" do
      assert {:ok, request} = Rpc.parse(@params)
      assert request.action.name != nil
    end
  end

  test "001 a request shaped like the shouldPass families runs end to end over a built result" do
    result =
      Rpc.run(
        %{"action" => "list_todos", "fields" => ["id", "title"]},
        [RpcFixtures.todo(title: "A")]
      )

    assert result["success"] == true
    assert [%{"title" => "A"}] = result["data"]
  end

  # Exact stage-1 parse results per request family: the select/load/extraction template split,
  # snake_case internal names, identity/getBy/input placement.
  @expected [
    {%{"action" => "list_todos", "fields" => ["id", "title"]},
     %{
       action: :read,
       select: [:id, :title],
       load: [],
       extraction_template: [:id, :title],
       input: %{},
       identity: nil,
       get_by: nil
     }},
    {%{
       "action" => "get_todo",
       "input" => %{"id" => "x"},
       "fields" => ["id", "isOverdue", "daysUntilDue"]
     },
     %{
       action: :get_by_id,
       select: [:id],
       load: [:is_overdue, :days_until_due],
       extraction_template: [:id, :is_overdue, :days_until_due],
       input: %{id: "x"},
       identity: nil,
       get_by: nil
     }},
    {%{"action" => "get_user_by_email", "getBy" => %{"email" => "a@b.c"}, "fields" => ["id"]},
     %{
       action: :read,
       select: [:id],
       load: [],
       extraction_template: [:id],
       input: %{},
       identity: nil,
       get_by: %{email: "a@b.c"}
     }},
    {%{
       "action" => "update_user_by_email",
       "identity" => %{"email" => "a@b.c"},
       "input" => %{},
       "fields" => ["id"]
     },
     %{
       action: :update,
       select: [:id],
       load: [],
       extraction_template: [:id],
       input: %{},
       identity: %{"email" => "a@b.c"},
       get_by: nil
     }},
    {%{"action" => "destroy_todo", "identity" => "id-1"},
     %{
       action: :destroy,
       select: [],
       load: [],
       extraction_template: [],
       input: %{},
       identity: "id-1",
       get_by: nil
     }},
    {%{"action" => "list_todos", "fields" => ["id", %{"user" => ["id", "name"]}]},
     %{
       action: :read,
       select: [:id],
       load: [user: [:id, :name]],
       extraction_template: [:id, {:user, [:id, :name]}],
       input: %{},
       identity: nil,
       get_by: nil
     }}
  ]

  for {{params, expected}, idx} <- Enum.with_index(@expected) do
    @params params
    @exp expected
    test "002.#{idx} #{params["action"]} parses to the exact request shape" do
      assert {:ok, request} = Rpc.parse(@params)
      actual = Map.take(request, Map.keys(@exp))
      assert %{actual | action: actual.action.name} == @exp
    end
  end

  test "003 unknown action and unknown field are refused, not parsed" do
    assert {:error, _} = Rpc.parse(%{"action" => "no_such_action", "fields" => ["id"]})
    assert {:error, _} = Rpc.parse(%{"action" => "list_todos", "fields" => ["id", "noSuchField"]})
  end

  test "004 a calculation request runs end to end with exact camelCase output" do
    todo = Map.put(RpcFixtures.todo(title: "Calc"), :is_overdue, true)

    result =
      Rpc.run(
        %{
          "action" => "get_todo",
          "input" => %{"id" => todo.id},
          "fields" => ["id", "title", "isOverdue"]
        },
        todo
      )

    assert result["success"] == true
    assert Map.keys(result["data"]) |> Enum.sort() == ["id", "isOverdue", "title"]
    assert result["data"]["isOverdue"] == true
    assert result["data"]["title"] == "Calc"
    assert result["data"]["id"] == todo.id
  end

  describe "zod runtime validation executed in node" do
    alias AshSurface.ZodFixtures.Harness

    @valid %{
      "address" => %{"street_address" => "12345 Road", "location_id" => "LOC-1234"},
      "case_insensitive_code" => "ABC-1234",
      "company_name" => "Acme Co",
      "country_code" => "US",
      "email" => "a@b.co",
      "hex_color" => "#00ff00",
      "number_of_employees" => 10,
      "percentage" => 50,
      "phone_number" => "+12125551234",
      "price" => 9.5,
      "slug" => "my-slug",
      "some_string" => "s",
      "temperature" => 20,
      "title" => "T",
      "user_id" => "123e4567-e89b-12d3-a456-426614174000",
      "username" => "alice",
      "version" => "1.2.3"
    }

    setup do
      Application.put_env(:ash_surface_gu10, :ash_domains, [AshSurface.Ported.Domain])
      {:ok, manifest} = Ash.Info.Manifest.generate(otp_app: :ash_surface_gu10)

      {:ok, irs} =
        AshSurface.Ported.AshNames.with_verbatim(fn -> AshSurface.Compiler.compile(manifest) end)

      irs = if is_map(irs), do: Map.values(irs), else: irs

      ir =
        Enum.find(
          irs,
          &(&1.ash.resource == AshSurface.Ported.OrgTodo and &1.ash.action == :create)
        )

      [input_schema | _] = String.split(ir.schema.zod, "\n\nexport")
      %{zod_source: String.replace_prefix(input_schema, "export const ", "const ")}
    end

    defp node_accepts(zod_source, cases) do
      dir = Path.join(System.tmp_dir!(), "rai_zod_#{AshSurface.TestTmp.suffix()}")
      File.mkdir_p!(dir)
      File.ln_s!(Path.join(Harness.repo_root(), "node_modules"), Path.join(dir, "node_modules"))
      Harness.zod!()

      [name | _] = Regex.run(~r/const (\w+) =/, zod_source, capture: :all_but_first)

      File.write!(Path.join(dir, "run.mjs"), """
      import { z } from "zod";
      #{zod_source}
      const cases = #{Jason.encode!(cases)};
      process.stdout.write(JSON.stringify(cases.map((c) => #{name}.safeParse(c).success)));
      """)

      {out, 0} = Harness.run(Harness.tool!("node"), ["run.mjs"], dir)
      File.rm_rf!(dir)
      Jason.decode!(out)
    end

    test "valid payload accepted; each constraint violation rejected", %{zod_source: src} do
      bad = [
        Map.put(@valid, "title", ""),
        Map.put(@valid, "number_of_employees", 0),
        Map.put(@valid, "number_of_employees", 1.5),
        Map.put(@valid, "hex_color", "00ff00"),
        Map.put(@valid, "user_id", "not-a-uuid"),
        Map.put(@valid, "percentage", 101),
        Map.put(@valid, "country_code", "USA"),
        Map.delete(@valid, "email")
      ]

      assert node_accepts(src, [@valid | bad]) == [true | List.duplicate(false, length(bad))]
    end

    test "optional and nullable fields; passthrough keeps unknown keys", %{zod_source: src} do
      cases = [
        Map.put(@valid, "auto_complete", nil),
        Map.put(@valid, "auto_complete", true),
        Map.put(@valid, "auto_complete", "yes"),
        Map.put(@valid, "unknown_extra", 1)
      ]

      assert node_accepts(src, cases) == [true, true, false, true]
    end
  end
end
