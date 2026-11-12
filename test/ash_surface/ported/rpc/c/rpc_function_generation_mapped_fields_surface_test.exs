defmodule AshSurface.Ported.Rpc.C.RpcFunctionGenerationMappedFieldsSurfaceTest do
  @moduledoc """
  Adaptation of the reference rpc_function_generation_mapped_fields tests (22 asserted
  generated TypeScript text). The `Task` fixture maps field `archived?` -> `isArchived` and the
  `mark_completed` argument `is_task_completed_now?` -> `isCompleted`. ash_surface emits no
  `.ts`; the behavior proven by each `CreateTaskInput` / `updateTask(...)` / validation / result
  type assertion is asserted on:

    * the compiled IR input Zod of the real `Task` actions, parsed under node + real zod
      (mapped names present, snake/question-mark spellings absent, required vs optional)
    * the non-actuating RPC pipeline (`Rpc.parse/1`, `Rpc.run/2`, `RpcValidate.validate/2`):
      mapped wire names reach the action input, success/error envelopes
    * the error Zod of the IR (every key the runtime emits is declared)

  Tests 013 and 019 (channel function signatures) remain loud skips in the gap file.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported, as: P
  alias AshSurface.Ported.{Rpc, RpcValidate, Tsa10}
  alias AshSurface.RuntimeParity.Rpc.Pipeline

  defmodule WithMeta do
    use Ash.Resource,
      domain: nil,
      data_layer: Ash.DataLayer.Simple,
      validate_domain_inclusion?: false,
      extensions: [AshSurface.Resource]

    attributes do
      uuid_primary_key(:id, public?: true)
      attribute(:title, :string, public?: true)
    end

    actions do
      defaults([:read])

      create :with_meta do
        accept([:title])
        argument(:metadata, AshSurface.Ported.TaskMetadata, allow_nil?: true)
      end
    end

    surface do
      projection :with_meta
    end
  end

  @uuid "6fa459ea-ee8a-3ca4-894e-db77e160355e"

  setup_all do
    irs =
      Tsa10.irs([
        {P.Task, :create},
        {P.Task, :update},
        {P.Task, :mark_completed},
        {P.Task, :read},
        {WithMeta, :with_meta}
      ])

    %{irs: irs}
  end

  defp input_zod(irs, action) do
    ir = Tsa10.ir!(irs, P.Task, action)
    ir.schema.zod |> String.split("_inputSchema = ") |> Enum.at(1) |> String.split(";\n") |> hd()
  end

  defp accepts(irs, action, cases), do: Tsa10.node_eval(input_zod(irs, action), cases)

  defp keys(irs, action), do: Tsa10.ir!(irs, P.Task, action).schema.input |> Map.keys()

  describe "RPC action input type generation with mapped field names" do
    test "001 create action input type uses mapped field names", %{irs: irs} do
      assert "title" in keys(irs, :create)
      assert accepts(irs, :create, [%{"title" => "t"}, %{}]) == [true, false]
      refute Enum.any?(keys(irs, :create), &(&1 =~ "archived"))
    end

    test "002 update action input type uses mapped field names", %{irs: irs} do
      ks = keys(irs, :update)
      assert "isArchived" in ks
      refute "archived?" in ks
      refute "is_archived" in ks

      assert accepts(irs, :update, [%{"isArchived" => true}, %{"isArchived" => "yes"}]) == [
               true,
               false
             ]
    end

    test "003 action with mapped argument uses mapped argument name in input type", %{irs: irs} do
      ks = keys(irs, :mark_completed)
      assert ks == ["isCompleted"]
      refute Enum.any?(ks, &(&1 =~ "completed?" or &1 =~ "is_task_completed"))
      assert accepts(irs, :mark_completed, [%{"isCompleted" => true}]) == [true]
    end

    test "004 input type required fields are not marked optional", %{irs: irs} do
      assert accepts(irs, :mark_completed, [%{}, %{"isCompleted" => false}]) == [false, true]
      refute Tsa10.ir!(irs, P.Task, :mark_completed).schema.input["isCompleted"]["optional"]
    end

    test "005 input type optional fields are marked optional", %{irs: irs} do
      assert accepts(irs, :update, [%{}, %{"isArchived" => false}, %{"title" => "x"}]) ==
               [true, true, true]

      assert Tsa10.ir!(irs, P.Task, :update).schema.input["isArchived"]["optional"] == true
    end
  end

  describe "RPC action result type generation with mapped names" do
    test "006 result type success case uses mapped field names" do
      record = struct(P.Task, %{id: @uuid, title: "t", archived?: true})

      result =
        Rpc.run(
          %{
            "action" => "update_task",
            "identity" => @uuid,
            "input" => %{"isArchived" => true},
            "fields" => ["id", "title", "isArchived"]
          },
          record
        )

      assert %{"success" => true, "data" => data} = result
      assert data == %{"id" => @uuid, "title" => "t", "isArchived" => true}
      refute Map.has_key?(data, "archived?")
    end

    test "007 result type error case uses AshRpcError array" do
      result =
        Rpc.run(
          %{
            "action" => "update_task",
            "identity" => @uuid,
            "input" => %{"title" => "t"},
            "fields" => ["id"]
          },
          {:error, Ash.Error.to_ash_error(%Ash.Error.Query.NotFound{resource: P.Task})}
        )

      assert %{"success" => false, "errors" => [_ | _] = errors} = result
      assert Enum.all?(errors, &is_map/1)
    end

    test "008 AshRpcError declares every key the runtime can emit", %{irs: irs} do
      zod = Tsa10.ir!(irs, P.Task, :update).schema.error["zod"]

      errors =
        [
          Ash.Error.to_ash_error(%Ash.Error.Query.NotFound{resource: P.Task}),
          Ash.Error.to_ash_error(%Ash.Error.Changes.Required{field: :title, resource: P.Task}),
          Ash.Error.to_ash_error(%Ash.Error.Changes.InvalidAttribute{
            field: :title,
            message: "bad",
            value: 1
          })
        ]
        |> Enum.flat_map(fn e ->
          %{"success" => false, "errors" => errs} =
            Rpc.run(
              %{"action" => "update_task", "identity" => @uuid, "fields" => ["id"]},
              {:error, e}
            )

          errs
        end)

      assert errors != []
      keys = errors |> Enum.flat_map(&Map.keys/1) |> Enum.uniq() |> Enum.sort()
      assert "type" in keys and "message" in keys

      # every emitted error parses under the IR's declared error shape
      assert Tsa10.node_eval(zod, errors) == List.duplicate(true, length(errors))
      # and an undeclared shape does not (the check is not vacuous)
      assert Tsa10.node_eval(zod, [%{"unrelated" => 1}]) == [false]
    end
  end

  describe "RPC action function generation with mapped names" do
    test "009 action function has correct type signature with mapped input" do
      # `input` is optional; `identity` is required for an update
      assert {:ok, no_input} = Rpc.parse(%{"action" => "update_task", "fields" => ["id"]})
      assert no_input.input == %{}

      assert {:ok, with_identity} =
               Rpc.parse(%{
                 "action" => "update_task",
                 "fields" => ["id"],
                 "identity" => @uuid,
                 "input" => %{"isArchived" => true}
               })

      assert with_identity.identity == @uuid
      assert {:error, _} = Pipeline.resolve_identity(no_input)
    end

    test "010 action function sends correct payload structure" do
      assert {:ok, request} =
               Rpc.parse(%{
                 "action" => "update_task",
                 "fields" => ["id"],
                 "identity" => @uuid,
                 "input" => %{"isArchived" => true, "title" => "x"}
               })

      assert request.action.name == :update
      # the wire name `isArchived` is mapped back to the attribute `archived?`
      assert request.input == %{archived?: true, title: "x"}
    end

    test "011 validation function uses mapped input type" do
      record = struct(P.Task, %{id: @uuid, title: "t", archived?: false})

      assert %{"success" => true} =
               RpcValidate.validate(
                 %{
                   "action" => "update_task",
                   "identity" => @uuid,
                   "input" => %{"isArchived" => true}
                 },
                 record: record
               )

      assert %{"success" => false, "errors" => [_ | _]} =
               RpcValidate.validate(
                 %{
                   "action" => "update_task",
                   "identity" => @uuid,
                   "input" => %{"isArchived" => "not-a-boolean"}
                 },
                 record: record
               )
    end

    test "012 validation function returns correct result type" do
      record = struct(P.Task, %{id: @uuid, title: "t", archived?: false})

      ok =
        RpcValidate.validate(
          %{"action" => "update_task", "identity" => @uuid, "input" => %{"title" => "x"}},
          record: record
        )

      assert ok == %{"success" => true}
    end
  end

  describe "channel-based RPC function generation with mapped names" do
    test "014 channel function sends correct payload structure", %{irs: irs} do
      # the payload mapping the channel function carries is the same wire contract: the mapped
      # `isCompleted` is required and neither original spelling is accepted as the input name
      assert accepts(irs, :mark_completed, [
               %{"isCompleted" => true},
               %{},
               %{"is_task_completed_now?" => true}
             ]) == [true, false, false]

      assert {:ok, request} =
               Rpc.parse(%{
                 "action" => "mark_completed_task",
                 "fields" => ["id"],
                 "identity" => @uuid,
                 "input" => %{"isCompleted" => true}
               })

      assert request.input == %{is_task_completed_now?: true}
      refute Map.has_key?(request.input, :isTaskCompletedNow?)
    end
  end

  describe "comprehensive RPC function mapping coverage" do
    test "015 all Task action input types use mapped field/argument names", %{irs: irs} do
      assert keys(irs, :create) |> Enum.all?(&(not String.ends_with?(&1, "?")))
      assert "isArchived" in keys(irs, :update)
      assert keys(irs, :mark_completed) == ["isCompleted"]
    end

    test "016 all validation functions use mapped input types" do
      record = struct(P.Task, %{id: @uuid, title: "t", archived?: false})

      assert %{"success" => true} =
               RpcValidate.validate(
                 %{
                   "action" => "mark_completed_task",
                   "identity" => @uuid,
                   "input" => %{"isCompleted" => true}
                 },
                 record: record
               )

      assert %{"success" => false} =
               RpcValidate.validate(
                 %{"action" => "mark_completed_task", "identity" => @uuid, "input" => %{}},
                 record: record
               )
    end
  end

  describe "function consistency with TypeScript client" do
    test "017 RPC functions use the same input types as type definitions", %{irs: irs} do
      # the names the IR input declares are exactly the names the pipeline accepts
      declared = keys(irs, :update) |> Enum.sort()

      for name <- declared do
        zod_value = if name == "isArchived", do: true, else: sample(name)

        assert {:ok, request} =
                 Rpc.parse(%{
                   "action" => "update_task",
                   "fields" => ["id"],
                   "identity" => @uuid,
                   "input" => %{name => zod_value}
                 })

        assert map_size(request.input) == 1
      end
    end

    test "018 validation functions use shared validation result type" do
      record = struct(P.Task, %{id: @uuid, title: "t", archived?: false})

      ok =
        RpcValidate.validate(
          %{
            "action" => "mark_completed_task",
            "identity" => @uuid,
            "input" => %{"isCompleted" => true}
          },
          record: record
        )

      bad =
        RpcValidate.validate(
          %{"action" => "mark_completed_task", "identity" => @uuid, "input" => %{}},
          record: record
        )

      # one result shape for every action: `success`, plus `errors` on failure
      assert Map.keys(ok) == ["success"]
      assert Enum.sort(Map.keys(bad)) == ["errors", "success"]
    end
  end

  describe "edge cases and special scenarios" do
    test "020 read actions use filter directly without input type", %{irs: irs} do
      ir = Tsa10.ir!(irs, P.Task, :read)
      assert ir.schema.input == %{}
      assert is_binary(ir.schema.filter)

      assert {:ok, request} =
               Rpc.parse(%{
                 "action" => "list_tasks",
                 "fields" => ["id"],
                 "filter" => %{"title" => %{"eq" => "x"}}
               })

      assert request.filter != nil
    end

    test "021 unmapped fields appear correctly alongside mapped fields", %{irs: irs} do
      ks = keys(irs, :update)
      assert "title" in ks and "isArchived" in ks
      refute "archived?" in ks
      assert accepts(irs, :update, [%{"title" => "a", "isArchived" => true}]) == [true]
    end
  end

  describe "embedded resource input schemas" do
    test "022 TaskMetadata input schema uses mapped field names", %{irs: irs} do
      ir = Tsa10.ir!(irs, WithMeta, :with_meta)
      zod = ir.schema.zod
      assert zod =~ "createdBy"
      assert zod =~ "isPublic"
      refute zod =~ "created_by?"
      refute zod =~ "is_public?"

      input_zod =
        zod |> String.split("_inputSchema = ") |> Enum.at(1) |> String.split(";\n") |> hd()

      assert Tsa10.node_eval(input_zod, [
               %{"metadata" => %{"createdBy" => "u"}},
               %{"metadata" => %{"createdBy" => "u", "isPublic" => true}},
               %{"metadata" => %{"isPublic" => true}}
             ]) == [true, true, false]
    end
  end

  defp sample("title"), do: "x"
  defp sample(_), do: nil
end
