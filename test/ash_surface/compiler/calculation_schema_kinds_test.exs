defmodule AshSurface.Compiler.CalculationSchemaKindsTest do
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.CalculationSchema, as: CS
  alias AshSurface.Projectors.JS.ZodGuard

  @kinds [:count, :avg, :max, :min, :sum, :first, :last, :exists, :list, :custom]

  defp facts(extra \\ %{}),
    do: for(k <- @kinds, do: Map.merge(%{name: "a_#{k}", kind: k, field_kind: :integer}, extra))

  test "every kind renders through both functions, admitted" do
    assert {:ok, out} = CS.render_aggregate_schemas(facts())
    assert length(out) == length(@kinds)
    for {_, zod} <- out, do: assert({:ok, _, _} = ZodGuard.admit(zod))
    assert {:ok, lines} = CS.render_aggregate_metadata(facts())
    assert length(lines) == length(@kinds)
    assert Map.keys(CS.result_kinds()) |> Enum.sort() == Enum.sort(@kinds)
  end

  test "nullability law" do
    {:ok, out} = CS.render_aggregate_schemas(facts())
    z = Map.new(out)
    for k <- [:sum, :avg, :first, :last, :min, :max], do: assert(z["a_#{k}"] =~ "nullable()")
    for k <- [:count, :exists, :list], do: refute(z["a_#{k}"] =~ "nullable()")
    refute z["a_custom"] =~ "nullable()"
    assert z["a_custom"] =~ "z.any()"
  end

  test "custom honours allow_nil?" do
    {:ok, [{_, z}]} = CS.render_aggregate_schemas([%{name: "c", kind: :custom, allow_nil?: true}])
    assert z =~ "z.any()" and z =~ "nullable()"
  end

  test "string-keyed facts and determinism" do
    sk =
      for f <- facts(),
          do:
            Map.new(f, fn {k, v} ->
              {to_string(k), if(is_atom(v) and k == :kind, do: v, else: v)}
            end)

    assert CS.render_aggregate_schemas(sk) == CS.render_aggregate_schemas(facts())
    assert CS.render_aggregate_schemas(facts()) == CS.render_aggregate_schemas(facts())
  end

  test "complex field_definition delegates to EmbeddedSchema" do
    defn = %{"type" => %{"kind" => "map"}}

    {:ok, [{_, z}]} =
      CS.render_aggregate_schemas([%{name: "f", kind: :first, field_definition: defn}])

    assert z =~ "nullable()"
    assert {:ok, _, _} = ZodGuard.admit(z)
  end

  test "calculation result schemas: nullable, kind, ref" do
    {:ok, out} =
      CS.render_calculation_result_schemas([
        %{name: "s", return_kind: :string},
        %{name: "n", return_kind: :integer, allow_nil?: true},
        %{name: "r", return_kind: :resource, return_ref: "My.Todo", allow_nil?: true},
        %{"name" => "r2", "return_kind" => "string", "return_ref" => "My.Todo"}
      ])

    z = Map.new(out)
    refute z["s"] =~ "nullable()"
    assert z["n"] =~ "nullable()"
    assert z["r"] =~ "nullable()"
    refute z["r2"] =~ "nullable()"
    for {_, zod} <- out, do: assert({:ok, _, _} = ZodGuard.admit(zod))

    assert CS.render_calculation_result_schemas([%{name: "s", return_kind: :string}]) ==
             CS.render_calculation_result_schemas([%{name: "s", return_kind: :string}])
  end
end
