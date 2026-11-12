defmodule AshSurface.Compiler.CalculationSchemaArgsTest do
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.CalculationSchema, as: CS
  alias AshSurface.Projectors.JS.ZodGuard

  defp render(args) do
    {:ok, zod} =
      CS.render_calculation_schema([%{name: "c", arguments: args, return_kind: :string}])

    assert {:ok, _, _} = ZodGuard.admit(zod)
    zod
  end

  test "required argument makes args non-optional" do
    zod = render([%{name: "sep", kind: :string, constraints: %{}}])
    assert zod =~ "args: z.object({\"sep\": z.string()}).strict()}).strict().optional()"
  end

  test "default / allow_nil / explicit required:false keep args optional" do
    for arg <- [
          %{name: "a", kind: :string, has_default: true},
          %{name: "a", kind: :string, allow_nil?: true},
          %{name: "a", kind: :string, required: false},
          %{"name" => "a", "kind" => "string", "has_default" => true}
        ] do
      assert render([arg]) =~ "}).strict().optional()}).strict().optional()"
    end
  end

  test "explicit required:true wins over default" do
    zod = render([%{name: "a", kind: :string, required: true, has_default: true}])
    assert zod =~ "args: z.object({"
    assert zod =~ "}).strict()}).strict().optional()"
    refute zod =~ "}).strict().optional()}).strict().optional()"
  end

  test "zero args stay optional; one required among many forces required" do
    assert render([]) =~ "args: z.object({}).strict().optional()"

    zod =
      render([
        %{name: "a", kind: :string, has_default: true},
        %{name: "b", kind: :integer}
      ])

    refute zod =~ "}).strict().optional()}).strict().optional()"
  end

  @runner Path.expand("../../ts/calculation_schema_runner.mjs", __DIR__)

  @tag timeout: 60_000
  test "executed under real zod: missing required args fails, supplied passes" do
    zod = render([%{name: "sep", kind: :string}])

    cases = [
      %{label: "missing", payload: %{"c" => %{}}, expect: false},
      %{label: "supplied", payload: %{"c" => %{"args" => %{"sep" => "-"}}}, expect: true},
      %{label: "bad", payload: %{"c" => %{"args" => %{"sep" => 1}}}, expect: false}
    ]

    out = run(zod, cases)
    for {c, r} <- Enum.zip(cases, out), do: assert(r["success"] == c.expect, c.label)

    optional =
      run(
        render([%{name: "sep", kind: :string, has_default: true}]),
        [%{label: "omitted", payload: %{"c" => %{}}, expect: true}]
      )

    assert [%{"success" => true}] = optional
  end

  defp run(zod, cases) do
    dir = Path.join(System.tmp_dir!(), "calc_schema_#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    f = Path.join(dir, "in.json")
    File.write!(f, Jason.encode!(%{zod: zod, cases: cases}))
    root = Path.expand("../../..", __DIR__)
    {out, 0} = System.cmd("node", [@runner, f], cd: root)
    Jason.decode!(out)
  end
end
