defmodule AshSurface.Ported.RpcRunActionUntypedMapsSurfaceTest do
  @moduledoc """
  Non-actuating counterpart of `rpc_run_action_untyped_maps_test.exs`: the two attribute
  round-trip tests (create/update accepting `custom_data`) are asserted as request-parse of the
  untyped-map input plus result shaping of a hand-built `Todo`. The merge tests exercise the
  `update_with_untyped_data` change function (action execution) and stay in the gap file.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.{Rpc, RpcFixtures}
  import RpcFixtures, only: [todo: 1]

  test "update action accepts custom_data attribute directly" do
    new_custom_data = %{"replacedKey" => "replaced_value", "directUpdate" => true}
    t = todo(title: "Updated Todo with Custom Data", custom_data: new_custom_data)

    params = %{
      "action" => "update_todo",
      "identity" => t.id,
      "input" => %{"title" => t.title, "customData" => new_custom_data},
      "fields" => ["id", "customData"]
    }

    assert {:ok, request} = Rpc.parse(params)
    assert request.input[:custom_data] == new_custom_data

    result = Rpc.run(params, t)
    assert result["success"] == true
    assert result["data"]["customData"] == new_custom_data
    refute Map.has_key?(result["data"]["customData"], "initialKey")
  end

  test "create action accepts custom_data attribute" do
    custom_data = %{
      "creationKey" => "creation_value",
      "numbers" => [1, 2, 3, 4, 5],
      "settings" => %{"theme" => "dark", "notifications" => true}
    }

    t = todo(title: "New Todo with Custom Data", custom_data: custom_data)

    params = %{
      "action" => "create_todo",
      "input" => %{"title" => t.title, "userId" => t.user_id, "customData" => custom_data},
      "fields" => ["id", "title", "customData"]
    }

    assert {:ok, request} = Rpc.parse(params)
    assert request.input[:custom_data] == custom_data

    result = Rpc.run(params, t)
    assert result["success"] == true
    assert result["data"]["customData"] == custom_data
    assert result["data"]["customData"]["creationKey"] == "creation_value"
    assert result["data"]["customData"]["numbers"] == [1, 2, 3, 4, 5]
    assert result["data"]["customData"]["settings"]["theme"] == "dark"
    assert result["data"]["customData"]["settings"]["notifications"] == true
  end

  test "untyped map arguments reach the parsed request unchanged" do
    additional = %{
      "new_key" => "new_value",
      "list" => [1, 2, 3],
      "nested_object" => %{"level2" => %{"level3" => "deep_value"}}
    }

    params = %{
      "action" => "update_todo_with_untyped_data",
      "identity" => "22222222-2222-2222-2222-222222222222",
      "input" => %{"additionalData" => additional, "metadataUpdate" => nil},
      "fields" => ["id", "customData"]
    }

    assert {:ok, request} = Rpc.parse(params)
    assert request.input[:additional_data] == additional
  end

  describe "untyped map shaping (mutation-killing)" do
    alias AshSurface.RuntimeParity.Rpc.ValueFormatter

    test "untyped map is passed through verbatim on output: keys not renamed, nesting intact" do
      t = todo(custom_data: %{some_key: 1, nested_map: %{inner_key: [1, 2], flag: true}})

      result =
        Rpc.run(%{"action" => "list_todos", "fields" => ["customData"]}, [t])

      assert result["data"] == [
               %{
                 "customData" => %{
                   some_key: 1,
                   nested_map: %{inner_key: [1, 2], flag: true}
                 }
               }
             ]
    end

    # Reference parity (RAM): ~/ash_typescript lib/ash_typescript/rpc/value_formatter.ex
    # `kind when kind in [:struct, :map]` cond, final `true -> value` (lines ~170-183): a map with
    # no `fields` constraint is returned verbatim in BOTH directions under EVERY formatter;
    # result_processor.ex extract_typed_map_value/4 `template == [] and fields == []` ->
    # normalize_primitive(value) (line ~458) keeps keys too. Only the wrapping field name
    # ("customData") follows the formatter.
    test "untyped map keys are verbatim under camel/snake/pascal, both directions (reference parity)" do
      AshSurface.Ported.Rpc.install()

      lookups =
        AshSurface.RuntimeParity.RequestedFields.Compat.resource_lookup(
          AshSurface.RuntimeParity.Rpc.Support.handle()
        )

      ty = Ash.Info.Manifest.Generator.TypeResolver.resolve(Ash.Type.Map, [])
      v = %{"a_b" => %{c_d: [%{e_f: 1}]}, some_key: 1}

      for {formatter, {wrapper, data_key}} <- [camel_case: {"customData", "data"}, snake_case: {"custom_data", "data"}, pascal_case: {"CustomData", "Data"}] do
        for dir <- [:input, :output] do
          assert ValueFormatter.format(v, ty, [], formatter, dir, lookups) == v
        end

        result =
          AshSurface.FieldName.with_formatter(formatter, fn ->
            Rpc.run(%{"action" => "list_todos", "fields" => [wrapper]}, [todo(custom_data: v)])
          end)

        assert result[data_key] == [%{wrapper => v}], "formatter #{formatter}: #{inspect(result)}"
      end
    end

    test "nil custom_data stays nil and empty map stays empty" do
      r1 = Rpc.run(%{"action" => "list_todos", "fields" => ["customData"]}, [todo(custom_data: nil)])
      assert r1["data"] == [%{"customData" => nil}]
      r2 = Rpc.run(%{"action" => "list_todos", "fields" => ["customData"]}, [todo(custom_data: %{})])
      assert r2["data"] == [%{"customData" => %{}}]
    end

    test "untyped map input keys parse to snake_case atoms-at-top, string keys preserved inside" do
      params = %{
        "action" => "update_todo_with_untyped_data",
        "identity" => "22222222-2222-2222-2222-222222222222",
        "input" => %{"additionalData" => %{"deep_key" => %{"X" => 1}}},
        "fields" => ["id"]
      }

      assert {:ok, request} = Rpc.parse(params)
      assert request.input[:additional_data] == %{"deep_key" => %{"X" => 1}}
      refute Map.has_key?(request.input, :additionalData)
    end

    test "ValueFormatter map input keeps keys unrenamed for an untyped Ash.Type.Map" do
      AshSurface.Ported.Rpc.install()

      lookups =
        AshSurface.RuntimeParity.RequestedFields.Compat.resource_lookup(
          AshSurface.RuntimeParity.Rpc.Support.handle()
        )

      ty = Ash.Info.Manifest.Generator.TypeResolver.resolve(Ash.Type.Map, [])
      v = %{"a_b" => 1, "cD" => %{"e_f" => 2}}
      assert ValueFormatter.format(v, ty, [], :camel_case, :input, lookups) == v
    end

    test "untyped map fragment under zod accepts records, rejects arrays and scalars" do
      f =
        AshSurface.Compiler.ZodType.fragment(
          AshSurface.Compiler.TypeFacts.analyze(Ash.Type.Map, []).definition
        )

      root = Path.expand("../../../../..", __DIR__)

      script = """
      import { z } from "zod";
      const s = #{f};
      console.log(JSON.stringify(#{Jason.encode!([%{"k" => [1]}, %{}, [], "s", 1, nil])}.map((v) => s.safeParse(v).success)));
      """

      {out, 0} = System.cmd("node", ["--input-type=module", "-e", script], cd: root)
      assert Jason.decode!(out) == [true, true, false, false, false, false]
    end
  end
end
