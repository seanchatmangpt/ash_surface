defmodule AshSurface.TS.ZodRuntimeTest do
  @moduledoc "Real node: the generated Zod schemas parse valid and reject invalid payloads."
  use ExUnit.Case, async: false

  alias AshSurface.ZodFixtures.Harness

  setup_all do
    node = Harness.tool!("node")
    ts_dir = Harness.workspace!(Harness.artifact!())
    on_exit(fn -> Harness.cleanup!(ts_dir) end)

    {out, status} =
      Harness.run(
        node,
        ["zod_runtime_runner.mjs", "generated/ash_surface_client.mjs", "cases.json"],
        ts_dir
      )

    assert status == 0, "node runner failed:\n" <> out
    %{results: Jason.decode!(out)}
  end

  test "every case outcome matches its expectation", %{results: results} do
    assert results != []

    for r <- results do
      expected = r["expect"] == "pass"

      assert r["success"] == expected,
             "#{r["label"]}: expected #{r["expect"]}, issues=#{inspect(r["issues"])}"
    end
  end
end
