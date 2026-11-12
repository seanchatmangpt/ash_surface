defmodule AshSurface.Ported.RpcRunActionVectorSurfaceTest do
  @moduledoc """
  Non-actuating counterpart of `rpc_run_action_vector_test.exs`: vector attributes are carried by
  hand-built `Todo` structs (real `Ash.Vector`) and shaped by the result processor. The
  dimensions-constraint rejection is asserted on a real `Ash.Changeset.for_create` (validation
  only, no data layer) rendered through the pipeline's error envelope.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.{Rpc, RpcFixtures}
  import RpcFixtures, only: [todo: 1]

  defp vec(list) do
    {:ok, v} = Ash.Vector.new(list)
    v
  end

  test "creates todo with a vector field and returns it as a list of numbers" do
    t = todo(title: "Todo with Embedding", embedding: vec([1.0, 2.0, 3.0]))

    result =
      Rpc.run(
        %{
          "action" => "get_todo_by_id",
          "input" => %{"id" => t.id},
          "fields" => ["id", "title", "embedding"]
        },
        t
      )

    assert result["success"] == true
    assert result["data"]["title"] == "Todo with Embedding"
    assert result["data"]["embedding"] == [1.0, 2.0, 3.0]
  end

  test "vector output is JSON-encodable" do
    t = todo(title: "Encodable Embedding", embedding: vec([0.5, -1.5, 2.25]))

    result =
      Rpc.run(
        %{
          "action" => "get_todo_by_id",
          "input" => %{"id" => t.id},
          "fields" => ["id", "embedding"]
        },
        t
      )

    assert result["success"] == true
    assert {:ok, json} = Jason.encode(result)
    assert json =~ "0.5"
  end

  test "creates todo with a null vector field" do
    t = todo(title: "Todo without Embedding", embedding: nil)

    result =
      Rpc.run(
        %{
          "action" => "get_todo_by_id",
          "input" => %{"id" => t.id},
          "fields" => ["id", "title", "embedding"]
        },
        t
      )

    assert result["success"] == true
    assert is_nil(result["data"]["embedding"])
  end

  test "reads vector fields back through a list action" do
    todos = [
      todo(title: "Listed Embedding", embedding: vec([4.0, 5.0, 6.0])),
      todo(id: "22222222-2222-2222-2222-222222222223", title: "Other", embedding: nil)
    ]

    result = Rpc.run(%{"action" => "list_todos", "fields" => ["title", "embedding"]}, todos)
    assert result["success"] == true

    assert Enum.any?(result["data"], fn todo ->
             todo["title"] == "Listed Embedding" and todo["embedding"] == [4.0, 5.0, 6.0]
           end)
  end

  test "rejects a vector that violates the dimensions constraint" do
    changeset =
      Ash.Changeset.for_create(AshSurface.Ported.Todo, :create, %{
        title: "Wrong Dimensions",
        embedding: [1.0, 2.0],
        user_id: RpcFixtures.user_id(),
        auto_complete: false
      })

    refute changeset.valid?

    result =
      changeset.errors
      |> Ash.Error.to_error_class()
      |> AshSurface.RuntimeParity.Rpc.Pipeline.error_response()

    assert result["success"] == false
    [error | _] = result["errors"]
    assert error["fields"] == ["embedding"]
    assert error["message"] =~ "must have 3 dimensions"
  end

  describe "vector value formatting (mutation-killing)" do
    alias AshSurface.RuntimeParity.Rpc.ValueFormatter

    setup do
      AshSurface.Ported.Rpc.install()

      lookups =
        AshSurface.RuntimeParity.RequestedFields.Compat.resource_lookup(
          AshSurface.RuntimeParity.Rpc.Support.handle()
        )

      ty = Ash.Info.Manifest.Generator.TypeResolver.resolve(Ash.Type.Vector, dimensions: 3)
      %{lookups: lookups, ty: ty}
    end

    test "Ash.Vector struct becomes a plain list", %{lookups: l, ty: ty} do
      assert ValueFormatter.format(vec([1.0, 2.0, 3.0]), ty, [], :camel_case, :output, l) ==
               [1.0, 2.0, 3.0]
    end

    test "from_struct'd vector (packed binary data) becomes the same list", %{lookups: l, ty: ty} do
      packed = Map.from_struct(vec([0.25, -1.0, 8.0]))
      assert ValueFormatter.format(packed, ty, [], :camel_case, :output, l) == [0.25, -1.0, 8.0]
    end

    test "inbound list passes through untouched; nil stays nil", %{lookups: l, ty: ty} do
      assert ValueFormatter.format([1.0, 2.0], ty, [], :camel_case, :input, l) == [1.0, 2.0]
      assert ValueFormatter.format(nil, ty, [], :camel_case, :output, l) == nil
    end

    test "dimensions constraint: exactly 3 accepted, 2 and 4 rejected with the count" do
      mk = fn v ->
        Ash.Changeset.for_create(AshSurface.Ported.Todo, :create, %{
          title: "D",
          embedding: v,
          user_id: RpcFixtures.user_id(),
          auto_complete: false
        })
      end

      assert mk.([1.0, 2.0, 3.0]).valid?

      for bad <- [[1.0, 2.0], [1.0, 2.0, 3.0, 4.0]] do
        cs = mk.(bad)
        refute cs.valid?
        assert Enum.any?(cs.errors, &(Exception.message(&1) =~ "3 dimensions"))
      end
    end

    test "vector list output is exact and keeps order through the pipeline" do
      t = todo(title: "Ordered", embedding: vec([3.0, 1.0, 2.0]))

      result =
        Rpc.run(%{"action" => "list_todos", "fields" => ["embedding"]}, [t])

      assert result["data"] == [%{"embedding" => [3.0, 1.0, 2.0]}]
    end

    test "vector fragment under zod accepts number arrays, rejects strings" do
      d = AshSurface.Compiler.TypeFacts.analyze(Ash.Type.Vector, dimensions: 3).definition
      f = AshSurface.Compiler.ZodType.fragment(d)
      root = Path.expand("../../../../..", __DIR__)

      script = """
      import { z } from "zod";
      const s = #{f};
      console.log(JSON.stringify(#{Jason.encode!([[1, 2, 3], [], "1,2,3", ["1"], nil])}.map((v) => s.safeParse(v).success)));
      """

      {out, 0} = System.cmd("node", ["--input-type=module", "-e", script], cd: root)
      assert Jason.decode!(out) == [true, true, false, false, false]
    end
  end
end
