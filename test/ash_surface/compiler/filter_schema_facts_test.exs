defmodule AshSurface.Compiler.FilterSchemaFactsTest do
  @moduledoc "Operator catalog, operator_key/1, functions metadata, filterable gating, error tuples."
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.FilterSchema
  alias AshSurface.Projectors.JS.ZodGuard

  defp render!(inputs, opts \\ []) do
    {:ok, zod} = FilterSchema.render_filter_schema(inputs, opts)
    assert :ok = ZodGuard.expression(zod)
    zod
  end

  test "temporal, ci_string and atom kinds get ordering operators; boolean gets in" do
    for kind <-
          ~w(date time utc_datetime utc_datetime_usec datetime naive_datetime ci_string atom) do
      zod = render!([%{"name" => "f", "type" => %{"kind" => kind}}])

      for op <- ~w(gt gte lt lte eq neq in),
          do: assert(zod =~ ~s'z.enum(["f"]), op: z.literal("#{op}")', "#{kind} #{op}")
    end

    zod = render!([%{"name" => "b", "type" => %{"kind" => "boolean"}}])
    assert zod =~ ~s'z.enum(["b"]), op: z.literal("in"), value: z.array(z.boolean())'
    refute zod =~ ~s'z.literal("gt")'
  end

  test "has/has_any element fragment from items / item_type" do
    zod =
      render!([
        %{"name" => "a", "type" => %{"kind" => "array"}, "items" => %{"kind" => "integer"}},
        %{"name" => "b", "type" => %{"kind" => "array"}, "item_type" => "boolean"},
        %{"name" => "c", "type" => %{"kind" => "array"}, "items" => %{"kind" => "weird"}}
      ])

    assert zod =~ ~s'z.enum(["a"]), op: z.literal("has"), value: z.number().int()'
    assert zod =~ ~s'z.enum(["a"]), op: z.literal("has_any"), value: z.array(z.number().int())'
    assert zod =~ ~s'z.enum(["b"]), op: z.literal("has"), value: z.boolean()'
    assert zod =~ ~s'z.enum(["c"]), op: z.literal("has"), value: z.unknown()'
  end

  test "operator_key/1 maps Ash operator names to surface keys" do
    expected = %{
      "==" => "eq",
      "!=" => "neq",
      "<" => "lt",
      "<=" => "lte",
      ">" => "gt",
      ">=" => "gte",
      "in" => "in",
      "is_nil" => "is_nil"
    }

    for {ash, key} <- expected do
      assert {:ok, ^key} = FilterSchema.operator_key(ash)
      assert {:ok, ^key} = FilterSchema.operator_key(String.to_atom(ash))
    end

    assert {:ok, "contains"} = FilterSchema.operator_key("contains")
    assert :error = FilterSchema.operator_key("string_downcase")
    assert :error = FilterSchema.operator_key(nil)
    assert :error = FilterSchema.operator_key(42)
  end

  test "whitelisted functions become operators (F1-divmap), others stay metadata" do
    entry = %{
      "name" => "n",
      "type" => %{"kind" => "string"},
      "operators" => ["==", :>, "is_nil"],
      "functions" => ["string_downcase", :contains]
    }

    assert %{
             operators: ["contains", "eq", "gt", "is_nil"],
             functions: ["contains", "string_downcase"],
             unmapped: []
           } =
             FilterSchema.split_capabilities(entry)

    zod = render!([entry])
    assert zod =~ ~s'z.literal("gt")'
    assert zod =~ ~s'z.literal("is_nil")'
    refute zod =~ "string_downcase"
    assert zod =~ ~s'z.literal("contains")'
    refute zod =~ ~s'z.literal("neq")'

    assert %{unmapped: ["bogus"], operators: ["eq"]} =
             FilterSchema.split_capabilities(%{"operators" => ["eq", "bogus"]})
  end

  test "filterable: false gates fields and relationships out" do
    zod =
      render!([
        %{"name" => "keep", "type" => %{"kind" => "string"}},
        %{"name" => "hidden", "type" => %{"kind" => "string"}, "filterable" => false},
        %{
          "name" => "rel",
          "type" => %{"kind" => "map"},
          "filterable?" => false,
          "relationship" => %{
            "filter_inputs" => [%{"name" => "x", "type" => %{"kind" => "string"}}]
          }
        }
      ])

    assert zod =~ ~s'"keep"'
    refute zod =~ "hidden"
    refute zod =~ "related"

    assert {:error, :no_filterable_fields} =
             FilterSchema.render_filter_schema([
               %{"name" => "h", "type" => %{"kind" => "string"}, "filterable" => false}
             ])
  end

  test "relationship variants are kept and honor max_depth/connectives" do
    inputs = [
      %{
        "name" => "author",
        "type" => %{"kind" => "map"},
        "relationship" => %{
          "filter_inputs" => [%{"name" => "email", "type" => %{"kind" => "string"}}]
        }
      }
    ]

    zod = render!(inputs, max_depth: 0, connectives: [])
    assert zod =~ ~s'z.literal("related")'
    refute zod =~ ~s'z.literal("and")'
  end

  test "option and input error tuples" do
    i = [%{"name" => "a", "type" => %{"kind" => "string"}}]

    assert {:error, {:invalid_max_depth, 4, 3}} =
             FilterSchema.render_filter_schema(i, max_depth: 4)

    assert {:error, {:invalid_max_depth, -1, 3}} =
             FilterSchema.render_filter_schema(i, max_depth: -1)

    assert {:error, {:invalid_max_depth, "2", 3}} =
             FilterSchema.render_filter_schema(i, max_depth: "2")

    assert {:error, {:unknown_connectives, ["xor"]}} =
             FilterSchema.render_filter_schema(i, connectives: ["and", "xor"])

    assert {:error, {:invalid_connectives, :all}} =
             FilterSchema.render_filter_schema(i, connectives: :all)

    assert {:error, {:filter_opts_not_a_list, :x}} = FilterSchema.render_filter_schema(i, :x)
    assert {:error, {:filter_inputs_not_a_list, %{}}} = FilterSchema.render_filter_schema(%{}, [])

    assert {:error, {:filter_input_missing_kind, "k"}} =
             FilterSchema.render_filter_schema([%{"name" => "k", "type" => %{}}])

    assert {:error, {:filter_input_malformed, 3}} = FilterSchema.render_filter_schema([3])
  end

  test "deterministic regardless of input order" do
    a = %{"name" => "a", "type" => %{"kind" => "string"}}
    b = %{"name" => "b", "type" => %{"kind" => "string"}}
    assert render!([a, b]) == render!([b, a])
  end
end
