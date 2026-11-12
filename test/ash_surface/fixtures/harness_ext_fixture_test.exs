defmodule AshSurface.Fixtures.HarnessExtFixtureTest do
  use ExUnit.Case, async: false
  alias AshSurface.ZodFixtures.{HarnessExt, Relations}

  test "artifact!/1 compiles a non-Todo domain" do
    art = HarnessExt.artifact!(Relations.Domain)
    assert is_binary(art) and art =~ "SCHEMAS"
  end

  test "fragment runner executes a raw Zod expression" do
    cases = [
      %{label: "ok", expect: true, payload: "abc"},
      %{label: "short", expect: false, payload: "a"}
    ]

    res = HarnessExt.run_fragment!("z.string().min(2)", cases)
    assert Enum.map(res, & &1["success"]) == [true, false]
  end
end
