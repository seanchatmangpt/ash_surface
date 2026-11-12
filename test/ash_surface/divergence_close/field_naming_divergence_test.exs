Code.require_file("../ported/top/support/t2.exs", __DIR__)

defmodule AshSurface.DivergenceClose.FieldNamingDivergenceTest do
  @moduledoc """
  F1-fieldwire courts for the client-naming divergences (register rows in
  `docs/KNOWN_DIVERGENCES.md`): custom `{module, function}` formatters invert over the admitted
  field set (and a lossy one is a typed compile refusal) and operator keys stay fixed literals
  under every formatter; plus the reference-parity default (unset = camel_case). Real Ash domain
  compile, real node + real zod; no doubles.
  """
  use ExUnit.Case, async: false

  alias AshSurface.{Compiler, FieldName}
  alias AshSurface.Ported.T2
  alias AshSurface.ZodFixtures.MappedNames.{Domain, Gadget}

  defmodule Formatters do
    @moduledoc "Hand-written real custom formatters."
    def shout(field), do: field |> to_string() |> String.replace("?", "") |> String.upcase()
    def lossy(_field), do: "same"
  end

  defp compile_under(formatter) do
    opts = if is_nil(formatter), do: [], else: [output_field_formatter: formatter]
    Compiler.compile(Domain, opts)
  end

  defp read_ir(irs), do: Enum.find(irs, &(&1.ash.resource == Gadget and &1.ash.action == :read))

  describe "custom {module, function} formatter inverse (derived from the admitted set)" do
    test "wire names round-trip to server names through the carried inverse table" do
      {:ok, irs} = compile_under({Formatters, :shout})
      schema = read_ir(irs).schema
      fields = schema.facts["field_names"]["fields"]

      assert fields["IS_ACTIVE"] == "is_active?"
      assert fields["LINE_2_TEXT"] == "line_2_text"
      assert fields["PLAIN"] == "plain"

      # emitted keys are the wire names, and real zod accepts exactly them
      assert {:ok, [true, false]} =
               T2.node_eval(schema.selection, [%{fields: ["PLAIN"]}, %{fields: ["plain"]}])

      # the same inverse over the admitted set, through the runtime parser
      admitted = [:is_active?, :address_1, :line_2_text, :plain]

      assert {:ok, :line_2_text} =
               FieldName.parse_input("LINE_2_TEXT", {Formatters, :shout}, admitted)

      assert :error = FieldName.parse_input("line_2_text", {Formatters, :shout}, admitted)
    end

    test "a lossy custom formatter (two fields, one client spelling) is a typed refusal" do
      assert {:error, {:section_failed, _id, {:field_name_collision, Gadget, "same", atoms}}} =
               compile_under({Formatters, :lossy})

      assert :plain in atoms
    end
  end

  describe "operator keys are fixed literals under every formatter" do
    test "field keys are formatted, operator literals never are" do
      {:ok, irs} = compile_under(:camel_case)
      filter = read_ir(irs).schema.filter

      f = fn field, op, value -> %{field: field, op: op, value: value} end

      assert {:ok, [true, true, false, false, false]} =
               T2.node_eval(filter, [
                 f.("isActive?", "eq", true), # RBS: `?` kept (reference parity)
                 f.("line2Text", "contains", "x"),
                 f.("is_active?", "eq", true),
                 f.("isActive", "notEq", true),
                 f.("isActive", "equals", true)
               ])
    end
  end

  describe "unset :output_field_formatter is the camel_case reference default everywhere" do
    test "an unset compile equals an explicit :camel_case compile (selection keys)" do
      {:ok, unset} = compile_under(nil)
      {:ok, camel} = compile_under(:camel_case)

      for irs <- [unset, camel] do
        assert {:ok, [true, false]} =
                 T2.node_eval(read_ir(irs).schema.selection, [
                   %{fields: ["line2Text"]},
                   %{fields: ["line_2_text"]}
                 ])
      end

      assert read_ir(unset).schema.selection == read_ir(camel).schema.selection
    end
  end
end
