Code.require_file("support/t2.exs", __DIR__)

defmodule AshSurface.Ported.Top.UnionFieldFormattingTest do
  @moduledoc """
  Adaptation of ash_typescript `union_field_formatting_test.exs` (regression: union member names
  must use the configured field formatter, never a hardcoded snake_to_camel conversion). The
  reference greps generated TS for `PriorityValue?: number` etc.; ash_surface emits no TS, so the
  same law is asserted where it lives: member and attribute names run through the real
  `FieldName` formatter calculus (built-in formatters, forward and inverse over the admitted
  member set), and the emitted union Zod and Todo record schema are executed under node with the
  formatter configured explicitly (`T2.with_env`): member and attribute keys follow it.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Compiler.TypeFacts
  alias AshSurface.FieldName
  alias AshSurface.Ported.{T2, Todo}

  defp union(attr_name) do
    attr = Ash.Resource.Info.attribute(Todo, attr_name)
    TypeFacts.analyze(attr.type, attr.constraints).definition
  end

  defp members(attr_name) do
    case union(attr_name) do
      %{"type" => %{"kind" => "union", "members" => ms}} ->
        Enum.map(ms, &String.to_atom(&1["name"]))

      %{"type" => %{"kind" => "array", "items" => %{"type" => %{"members" => ms}}}} ->
        Enum.map(ms, &String.to_atom(&1["name"]))
    end
  end

  @expected %{
    pascal_case: %{
      priority_value: "PriorityValue",
      note: "Note",
      simple: "Simple",
      detailed: "Detailed",
      automated: "Automated",
      content: "Content",
      attachments: "Attachments",
      status_info: "StatusInfo"
    },
    camel_case: %{
      priority_value: "priorityValue",
      note: "note",
      simple: "simple",
      detailed: "detailed",
      automated: "automated",
      content: "content",
      attachments: "attachments",
      status_info: "statusInfo"
    },
    snake_case: %{
      priority_value: "priority_value",
      note: "note",
      simple: "simple",
      detailed: "detailed",
      automated: "automated",
      content: "content",
      attachments: "attachments",
      status_info: "status_info"
    }
  }

  describe "Union field formatting with configured formatters" do
    test "generates PascalCase union member names with :pascal_case formatter" do
      assert_formatted(:pascal_case)
      refute FieldName.compute(:priority_value, :pascal_case) == "priorityValue"
    end

    test "generates camelCase union member names with :camel_case formatter (default)" do
      assert AshSurface.Config.output_field_formatter() == :camel_case
      assert_formatted(:camel_case)
      refute FieldName.compute(:priority_value, :camel_case) == "PriorityValue"
    end

    test "generates snake_case union member names with :snake_case formatter" do
      assert_formatted(:snake_case)
      refute FieldName.compute(:priority_value, :snake_case) == "priorityValue"
    end

    test "union member formatting is one function for both output and input forms" do
      # The reference's two builders (output / input) share the formatter; here the same
      # forward `format/3` and inverse `parse_input/4` agree over the admitted member set.
      admitted = members(:content)
      assert :priority_value in admitted

      for formatter <- [:pascal_case, :camel_case, :snake_case] do
        client = FieldName.format(:priority_value, formatter)
        assert client == @expected[formatter][:priority_value]
        assert {:ok, :priority_value} = FieldName.parse_input(client, formatter, admitted)
      end

      # distinct client spellings across the whole member set (no collisions under any formatter)
      for formatter <- [:pascal_case, :camel_case, :snake_case] do
        assert {:ok, map} = FieldName.client_to_internal(admitted, formatter)
        assert map_size(map) == length(admitted)
      end
    end

    test "regression: no hardcoded snake_to_camel_case in union member or attribute naming" do
      assert FieldName.compute(:priority_value, :snake_case) == "priority_value"
      assert FieldName.compute(:note, :snake_case) == "note"
      assert FieldName.compute(:simple, :snake_case) == "simple"
      assert FieldName.compute(:status_info, :snake_case) == "status_info"
      refute FieldName.compute(:priority_value, :snake_case) == "priorityValue"
      refute FieldName.compute(:note, :snake_case) == "Note"
      refute FieldName.compute(:status_info, :snake_case) == "statusInfo"
    end
  end

  describe "emitted union Zod follows the explicitly configured formatter" do
    defp content_zod do
      attr = Ash.Resource.Info.attribute(Todo, :content)
      T2.zod_full(attr.type, attr.constraints)
    end

    test "emitted union members use PascalCase under :pascal_case" do
      T2.with_env(:output_field_formatter, :pascal_case, fn ->
        zod = content_zod()
        assert zod =~ "PriorityValue: z.number()"
        assert zod =~ "Note: z.string()"
        refute zod =~ "priority_value"

        assert {:ok, [true, true, false, false]} =
                 T2.node_eval(zod, [
                   %{"Note" => "n"},
                   %{"PriorityValue" => 3},
                   %{"priority_value" => 3},
                   %{"note" => "n"}
                 ])
      end)
    end

    test "emitted union members use camelCase under :camel_case" do
      T2.with_env(:output_field_formatter, :camel_case, fn ->
        zod = content_zod()
        assert zod =~ "priorityValue: z.number()"
        refute zod =~ "priority_value"

        assert {:ok, [true, false]} =
                 T2.node_eval(zod, [%{"priorityValue" => 3}, %{"priority_value" => 3}])
      end)
    end

    test "emitted union members and attribute names use snake_case under :snake_case" do
      T2.with_env(:output_field_formatter, :snake_case, fn ->
        assert content_zod() =~ "priority_value: z.number()"

        record = T2.record_zod(Todo)
        assert %{"keys" => keys} = T2.node_probe(record, "return { keys: Object.keys(s.shape) };")
        assert "status_info" in keys
        refute "statusInfo" in keys
      end)

      T2.with_env(:output_field_formatter, :camel_case, fn ->
        record = T2.record_zod(Todo)
        assert %{"keys" => keys} = T2.node_probe(record, "return { keys: Object.keys(s.shape) };")
        assert "statusInfo" in keys
        refute "status_info" in keys
      end)
    end

    test "content union members are keyed by member name and execute under real zod" do
      attr = Ash.Resource.Info.attribute(Todo, :content)
      zod = T2.zod_full(attr.type, attr.constraints)
      assert zod =~ "priority_value: z.number().int().min(1).max(10)"
      assert zod =~ "note: z.string()"

      assert {:ok, oks} =
               T2.node_eval(zod, [
                 %{"note" => "n"},
                 %{"priority_value" => 3},
                 %{"priority_value" => 99},
                 %{"Note" => "n"}
               ])

      assert oks == [true, true, false, false]
    end

    test "array-of-union attachments render an array of the member union" do
      attr = Ash.Resource.Info.attribute(Todo, :attachments)
      zod = T2.zod_full(attr.type, attr.constraints)
      assert zod =~ "z.array("
      assert zod =~ "file:"
      assert zod =~ "mime_type"
    end
  end

  defp assert_formatted(formatter) do
    for {name, expected} <- @expected[formatter] do
      assert FieldName.compute(name, formatter) == expected
    end

    # the real union members/attributes of Todo are exactly the names the table covers
    for member <- members(:content) ++ members(:status_info) ++ members(:attachments),
        member in [:priority_value, :note, :simple, :detailed, :automated] do
      assert FieldName.compute(member, formatter) == @expected[formatter][member]
    end
  end
end
