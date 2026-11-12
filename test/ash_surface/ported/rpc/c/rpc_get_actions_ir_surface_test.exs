defmodule AshSurface.Ported.Rpc.C.RpcGetActionsIrSurfaceTest do
  @moduledoc """
  Adaptation of the 7 reference rpc_get_actions tests that asserted generated TypeScript text
  (function signatures with `getBy`, absence of pagination/filter options, `| null` result
  types). ash_surface emits no `.ts`; the behavior those assertions prove is asserted on:

    * the compiled IR of real inline resources (`schema.get`, `schema.page`, `schema.filter`,
      `schema.facts.not_found_error?`), with the `get_by` zod parsed under node + real zod
    * the non-actuating RPC pipeline (a get action refuses `filter`/`sort`/`page`, requires
      every `getBy` key)
    * the TS result-type claim (`| null` iff `not_found_error?: false`) under `tsc --strict`
      over `Inference.action_types/1`, the type emitter the README keeps as a test tool
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.Rpc, as: R
  alias AshSurface.Ported.Tsa10
  alias AshSurface.Projectors.JS.Inference
  alias AshSurface.ZodFixtures.Harness

  defmodule Item do
    use Ash.Resource,
      domain: nil,
      data_layer: Ash.DataLayer.Simple,
      validate_domain_inclusion?: false,
      extensions: [AshSurface.Resource]

    attributes do
      uuid_primary_key(:id, public?: true)
      attribute(:email, :string, public?: true, allow_nil?: false)
      attribute(:user_id, :uuid, public?: true, allow_nil?: false)

      attribute(:status, :atom,
        public?: true,
        constraints: [one_of: [:pending, :finished]],
        default: :pending
      )
    end

    identities do
      identity(:unique_email, [:email])
    end

    actions do
      defaults([:read])
      read(:single, do: get?(true))
      read(:single_nullable, do: get?(true))
      read(:by_email, do: get_by(:email))
      read(:by_user_and_status, do: get_by([:user_id, :status]))
      read(:listing)
    end

    surface do
      projection :single, get?: true
      projection :single_nullable, get?: true, not_found_error?: false
      projection :by_email, get_by: [:email]
      projection :by_user_and_status, get_by: [:user_id, :status]
      projection :listing
    end
  end

  @uuid "6fa459ea-ee8a-3ca4-894e-db77e160355e"

  setup_all do
    irs =
      Tsa10.irs(
        for a <- ~w(single single_nullable by_email by_user_and_status listing)a do
          {Item, a}
        end
      )

    %{irs: irs}
  end

  test "029 get_single_todo has correct function signature in generated code", %{irs: irs} do
    ir = Tsa10.ir!(irs, Item, :single)
    assert ir.schema.capability_flags["get"] == true
    # no required input and no getBy: the get schema declares none
    assert ir.schema.get["input"] == nil

    # pipeline: the request needs only `fields`
    assert {:ok, request} = R.parse(%{"action" => "get_single_todo", "fields" => ["id"]})
    assert request.action.get? == true
    assert request.get_by in [nil, %{}, []]
  end

  test "030 get_user_by_email has correct function signature with getBy in generated code", %{
    irs: irs
  } do
    ir = Tsa10.ir!(irs, Item, :by_email)
    assert ir.schema.capability_flags["get"] == true
    input = ir.schema.get["input"]
    assert is_binary(input)
    assert input =~ "email"

    assert Tsa10.node_eval(input, [
             %{"email" => "a@example.com"},
             %{},
             %{"email" => 5}
           ]) == [true, false, false]

    assert {:error, {:missing_get_by_fields, ["email"]}} =
             R.parse(%{"action" => "get_user_by_email", "fields" => ["id"]})

    assert {:ok, request} =
             R.parse(%{
               "action" => "get_user_by_email",
               "fields" => ["id"],
               "getBy" => %{"email" => "a@example.com"}
             })

    assert request.get_by == %{email: "a@example.com"}
  end

  test "031 get_todo_by_user_and_status has correct function signature with multiple getBy fields",
       %{irs: irs} do
    ir = Tsa10.ir!(irs, Item, :by_user_and_status)
    input = ir.schema.get["input"]
    assert input =~ "user_id" or input =~ "userId"
    assert input =~ "status"

    key = if input =~ "userId", do: "userId", else: "user_id"

    assert Tsa10.node_eval(input, [
             %{key => @uuid, "status" => "pending"},
             %{key => @uuid},
             %{"status" => "pending"}
           ]) == [true, false, false]

    assert {:error, {:missing_get_by_fields, ["status"]}} =
             R.parse(%{
               "action" => "get_todo_by_user_and_status",
               "fields" => ["id"],
               "getBy" => %{"userId" => @uuid}
             })

    assert {:ok, request} =
             R.parse(%{
               "action" => "get_todo_by_user_and_status",
               "fields" => ["id"],
               "getBy" => %{"userId" => @uuid, "status" => "pending"}
             })

    assert request.get_by |> Map.keys() |> Enum.sort() == [:status, :user_id]
  end

  test "032 get actions do not have pagination or filter options", %{irs: irs} do
    for action <- [:single, :by_email, :by_user_and_status] do
      schema = Tsa10.ir!(irs, Item, action).schema
      assert schema.page == nil
      assert schema.filter == nil
      assert schema.sort == nil
    end

    # contrast: a plain list action carries all three
    listing = Tsa10.ir!(irs, Item, :listing).schema
    assert listing.filter != nil
    assert listing.sort != nil

    # runtime: the pipeline refuses each option on a get action
    base = %{"action" => "get_single_todo", "fields" => ["id"]}

    assert {:error, {:filter_not_supported, _, _}} =
             R.parse(Map.put(base, "filter", %{"title" => %{"eq" => "x"}}))

    assert {:error, {:pagination_not_supported, _, _}} =
             R.parse(Map.put(base, "page", %{"limit" => 1}))

    assert {:error, {:sort_not_supported, _, _}} = R.parse(Map.put(base, "sort", "title"))
  end

  describe "not_found_error? result type" do
    test "047 result type includes | null for not_found_error?: false actions", %{irs: irs} do
      assert Tsa10.ir!(irs, Item, :single_nullable).schema.facts["not_found_error?"] == false
      assert emitted(:single_nullable, false) =~ "| null"
      assert tsc_infers_null?(false)
    end

    test "048 result type does not include | null for default not_found_error? (true)", %{
      irs: irs
    } do
      assert Tsa10.ir!(irs, Item, :single).schema.facts["not_found_error?"] == true
      refute emitted(:single, true) =~ "| null"
      assert tsc_rejects_null?(true)
    end

    test "049 result type does not include | null for explicit not_found_error?: true", %{
      irs: irs
    } do
      assert Tsa10.ir!(irs, Item, :by_email).schema.facts["not_found_error?"] in [true, nil]
      refute emitted(:by_email, true) =~ "| null"
      assert tsc_rejects_null?(true)
    end
  end

  # -- Inference.action_types/1 + real tsc ------------------------------------------------

  defp emitted(name, not_found?) do
    Inference.action_types(%{
      name: "Get#{Macro.camelize(to_string(name))}",
      schema: "ItemSchema",
      kind: :get,
      not_found_error?: not_found?
    })
  end

  @flags ~w(--strict --noEmit --skipLibCheck --module esnext --moduleResolution bundler --target es2022)

  defp tsc(not_found?, case_body) do
    tsc = Harness.tool!("tsc")
    dir = Path.join(System.tmp_dir!(), "tsa10_tsc_#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(dir)

    try do
      File.write!(
        Path.join(dir, "schemas.ts"),
        Inference.emit([{"Item", [%{name: "id", ts: "string", primitive?: true}]}]) <>
          emitted(:probe, not_found?)
      )

      File.write!(Path.join(dir, "case.ts"), """
      import type { InferGetProbeResult } from "./schemas";
      #{case_body}
      """)

      {out, status} = Harness.run(tsc, @flags ++ ["case.ts"], dir)
      {status, out}
    after
      File.rm_rf!(dir)
    end
  end

  defp tsc_infers_null?(nf) do
    {status, out} =
      tsc(nf, """
      declare const r: InferGetProbeResult<["id"]>;
      export const asNull: typeof r = null;
      """)

    assert status == 0, out
    true
  end

  defp tsc_rejects_null?(nf) do
    {status, out} =
      tsc(nf, """
      declare const r: InferGetProbeResult<["id"]>;
      export const asNull: typeof r = null;
      """)

    assert status != 0 and out =~ "null", "expected a type error for null, got: #{out}"
    true
  end
end
