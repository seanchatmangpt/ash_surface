Code.require_file("../../top/support/t1.exs", __DIR__)
Code.require_file("../../top/support/t2.exs", __DIR__)

defmodule AshSurface.Ported.Rpc.A.EmbeddedArgumentTest do
  @moduledoc """
  Adaptation of ash_typescript `embedded_argument_test.exs` (embedded resources used directly
  as action argument types). ash_surface emits Zod inside the compiled IR, not `.ts` type
  aliases: `TypeMapper.get_ts_input_type` becomes the IR's inlined input `z.object(...)`, and the
  "defined exactly once" checks become one `export const <action>_inputSchema` per action in the
  real compiled IR. Reachability is Ash's own manifest walker.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.TypeFacts
  alias AshSurface.Ported.{T1, Todo, TodoMetadata}

  describe "Reachability discovers embedded resources used as action argument types" do
    test "reachability finds TodoMetadata through action arguments" do
      {reachable, _} =
        Ash.Info.Manifest.Generator.Reachability.find_reachable([
          {Todo, [:process_metadata, :process_metadata_batch]}
        ])

      assert TodoMetadata in reachable
    end

    test "the compiler's embedded closure reaches TodoMetadata from the argument type" do
      for type <- [TodoMetadata, {:array, TodoMetadata}] do
        definition = TypeFacts.analyze(type, []).definition
        assert Map.has_key?(TypeFacts.embedded_resources([definition]), inspect(TodoMetadata))
      end
    end
  end

  describe "input schema for embedded resource arguments" do
    test "a direct embedded argument renders as an object schema (InputSchema analogue)" do
      zod = T1.ir_under(nil, Todo, :process_metadata).schema.zod
      assert zod =~ "metadata: z.object({"
    end

    test "an array of embedded resources renders as z.array(z.object(...))" do
      zod = T1.ir_under(nil, Todo, :process_metadata_batch).schema.zod
      assert zod =~ "metadataItems: z.array(z.object({"
    end
  end

  describe "compiled IR has the types without duplicates" do
    test "process_metadata input schema is declared once and carries the embedded metadata" do
      zod = T1.ir_under(nil, Todo, :process_metadata).schema.zod
      assert length(Regex.scan(~r/export const \w+_process_metadata_inputSchema =/, zod)) == 1
      assert zod =~ "metadata: z.object({"
    end

    test "process_metadata_batch input schema is declared once and carries Array<embedded>" do
      zod = T1.ir_under(nil, Todo, :process_metadata_batch).schema.zod

      assert length(Regex.scan(~r/export const \w+_process_metadata_batch_inputSchema =/, zod)) ==
               1

      assert zod =~ "metadataItems: z.array(z.object({"
    end

    test "each action has exactly one IR entry (no duplicated embedded declarations)" do
      for action <- [:process_metadata, :process_metadata_batch] do
        assert [_one] =
                 Enum.filter(
                   T1.irs_under(nil),
                   &(&1.ash.resource == Todo and &1.ash.action == action)
                 )
      end
    end

    test "the embedded TodoMetadata closure is a single entry" do
      closure =
        Todo
        |> Ash.Resource.Info.public_attributes()
        |> Enum.map(&TypeFacts.analyze(&1.type, &1.constraints).definition)
        |> TypeFacts.embedded_resources()

      assert closure |> Map.keys() |> Enum.count(&(&1 == inspect(TodoMetadata))) == 1
    end
  end
end
