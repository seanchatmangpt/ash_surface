defmodule AshSurface.Projectors.JSSchemaWiringTest do
  @moduledoc """
  w3-02 courts: filter/sort/page/response schemas and capability flags reach
  the generated artifact, every string passes ZodGuard, and the artifact
  executes under real Node + real zod 4 (no mocks).
  """
  use ExUnit.Case, async: false

  alias AshSurface.{IR, Compiler.QuerySchema, Projectors.JS, Projectors.JS.ZodGuard}

  @tmp AshSurface.TestTmp.scoped(Path.expand("../../../_build/test/js_schema_wiring_w302", __DIR__))
  @root Path.expand("../../..", __DIR__)
  @flags %{"get" => true, "keyset" => false}

  setup do
    File.rm_rf!(@tmp)
    File.mkdir_p!(Path.join(@tmp, "node_modules"))
    File.ln_s!(Path.join(@root, "node_modules/zod"), Path.join(@tmp, "node_modules/zod"))
    :ok
  end

  defp ir do
    {:ok, sort} = QuerySchema.render_sort_schema(["title", "inserted_at"])
    {:ok, page} = QuerySchema.render_pagination_schema()

    IR.new(
      ash: %IR.Ash{
        resource: "Todo",
        action: :list,
        action_type: :read,
        policies: [%{"authorityBoundary" => "OBSERVE"}]
      },
      schema: %IR.Schema{
        zod: "z.object({status: z.string().optional()})",
        filter: "z.object({title: z.string().optional()}).strict()",
        sort: sort,
        page: page,
        response_zod: "z.object({id: z.string()})",
        capability_flags: @flags
      }
    )
  end

  test "all new strings are ZodGuard-admitted and embedded, regex is RegExp" do
    assert {:ok, %{"ash_surface_client.mjs" => code}, _} = JS.project_ir(ir())
    %IR.Schema{} = s = ir().schema

    for z <- [s.filter, s.sort, s.page, s.response_zod],
        do: assert({:ok, :expression, _} = ZodGuard.admit(z))

    assert code =~ "Todo_list_filter_schema"
    assert code =~ "Todo_list_sort_schema"
    assert code =~ "Todo_list_page_schema"
    assert code =~ "Todo_list_response_schema"
    # S1-F: sort renders a regex LITERAL (zod 4 `.regex(str)` throws); pinned via the
    # public QuerySchema output, which must appear verbatim in the artifact.
    assert s.sort =~ ~r{\.regex\(/}
    assert code =~ s.sort
    refute code =~ "new RegExp("
    refute code =~ ~r/\.regex\("/
    assert code =~ ~s(import { z } from "zod";)
  end

  test "deterministic" do
    assert JS.project_ir(ir()) == JS.project_ir(ir())
  end

  test "unadmitted filter zod is refused" do
    bad = update_in(ir().schema.filter, fn _ -> "process.exit(1)" end)

    assert {:error, {:unadmitted_zod, "Todo.list", _}} =
             JS.project_ir(%{ir() | schema: bad.schema} |> then(fn _ -> bad end))
  end

  test "node executes generated schemas under real zod" do
    assert {:ok, _, _} = JS.project_ir(ir(), target_dir: @tmp)
    spec = Path.join(@tmp, "spec.json")

    File.write!(
      spec,
      Jason.encode!(%{
        targetDir: @tmp,
        prefix: "ash_surface_client",
        id: "Todo.list",
        flags: @flags,
        cases: %{
          sortSchema: %{
            valid: ["title", "-inserted_at", "+title,-inserted_at"],
            invalid: ["bogus", "title,", 5]
          },
          filterSchema: %{valid: [%{}, %{title: "a"}], invalid: [%{title: 1}, %{x: 1}]},
          pageSchema: %{
            valid: [%{limit: 10}, %{limit: 5, offset: 0}],
            invalid: [%{limit: 0}, %{limit: 501}, %{}]
          },
          responseSchema: %{valid: [%{id: "1"}], invalid: [%{}]}
        }
      })
    )

    {out, status} =
      System.cmd("node", ["test/js/generated_schema_wiring_runner.mjs", spec],
        stderr_to_stdout: true,
        cd: @root,
        env: [{"MIX_BUILD_ROOT", "_build-w302"}]
      )

    assert status == 0, out
    assert out =~ "GENERATED_SCHEMA_WIRING_PASS"
  end
end
