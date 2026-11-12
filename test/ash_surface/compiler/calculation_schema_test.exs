defmodule AshSurface.Compiler.CalculationSchemaTest do
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.CalculationSchema
  alias AshSurface.Projectors.JS.ZodGuard

  test "calc envelope has args and fields and is admitted" do
    {:ok, zod} =
      CalculationSchema.render_calculation_schema([
        %{
          name: "full",
          arguments: [%{name: "sep", kind: :string, constraints: %{}}],
          return_kind: :string,
          fields: ["a", "b"]
        }
      ])

    assert zod =~ "\"sep\":"
    assert zod =~ "fields: z.array(z.enum([\"a\", \"b\"])).optional()"
    assert {:ok, _, _} = ZodGuard.admit(zod)
  end

  test "aggregate result kinds" do
    {:ok, out} =
      CalculationSchema.render_aggregate_schemas([
        %{name: "n", kind: :count},
        %{name: "m", kind: :max, field_kind: :integer},
        %{name: "l", kind: :list, field_kind: :string},
        %{name: "e", kind: :exists}
      ])

    assert [{"n", n}, {"m", m}, {"l", l}, {"e", e}] = out
    assert n =~ "int()"
    assert m =~ "nullable()"
    assert l =~ "z.array("
    assert e =~ "z.boolean()"
    for {_, zod} <- out, do: assert({:ok, _, _} = ZodGuard.admit(zod))
  end
end
