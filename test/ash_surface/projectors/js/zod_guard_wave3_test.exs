defmodule AshSurface.Projectors.JS.ZodGuardWave3Test do
  use ExUnit.Case, async: true

  alias AshSurface.Projectors.JS.ZodGuard

  test "M3: empty regex body and comment-shaped regex are refused" do
    for src <- [
          "z.string().regex(//)",
          "z.string().regex(/*x*/)",
          "z.string().regex(//i)",
          "z.string().regex(/**/)"
        ] do
      assert {:error, _} = ZodGuard.admit(src), src
    end

    assert {:ok, :expression, _} = ZodGuard.admit("z.string().regex(/\\*a/)")
    assert {:ok, :expression, _} = ZodGuard.admit("z.string().regex(/a*/)")
  end

  test "M4: global-state members are refused" do
    for src <- [
          "z.config({jitless: true})",
          "z.globalRegistry.clear()",
          "z.core.config({})",
          "z.string().register(z.globalRegistry)",
          "z.locales",
          "z.string().meta({})",
          "z.toJSONSchema(z.string())",
          "z.string().transform(1)"
        ] do
      assert {:error, {:zod_denied_member, _}} = ZodGuard.admit(src), src
    end
  end
end
