defmodule AshSurface.ZodGuardRegexTest do
  use ExUnit.Case, async: true

  alias AshSurface.Projectors.JS.ZodGuard

  @admitted [
    "z.string().regex(/a/i)",
    "z.string().regex(/[/]/)",
    "z.string().regex(/a/dgimsuvy)",
    "z.string().regex(/a/)",
    "z.object({a: z.string()}).strict()",
    "z.object({a: z.string()}).passthrough()",
    "z.number().gt(1).lt(5).min(1).max(5)",
    "z.iso.datetime()",
    "z.uuid()",
    ~s|z.enum(["a","b"])|,
    ~s|z.literal("a")|,
    "z.union([z.string(), z.number()])",
    ~s|z.discriminatedUnion("t", [z.object({t: z.literal("a")})])|,
    "z.record(z.string(), z.any())",
    "z.unknown()",
    "z.number().max(1.0e20)",
    "z.number().max(1e+21)"
  ]

  for src <- @admitted do
    test "admits #{src}" do
      assert {:ok, :expression, _} = ZodGuard.admit(unquote(src))
    end
  end

  test "refuses bad flags" do
    assert {:error, {:zod_regex_flags, "zz"}} = ZodGuard.admit("z.string().regex(/a/zz)")
    assert {:error, {:zod_regex_flags, "ii"}} = ZodGuard.admit("z.string().regex(/a/ii)")
    assert {:error, {:zod_regex_flags, "gig"}} = ZodGuard.admit("z.string().regex(/a/gig)")
  end

  test "refuses newline in body, in class, and escaped" do
    assert {:error, _} = ZodGuard.admit("z.string().regex(/a\nb/)")
    assert {:error, _} = ZodGuard.admit("z.string().regex(/[a\nb]/)")
    assert {:error, _} = ZodGuard.admit("z.string().regex(/a\\\nb/)")
  end

  test "refuses unterminated" do
    assert {:error, _} = ZodGuard.admit("z.string().regex(/abc)")
    assert {:error, _} = ZodGuard.admit("z.string().regex(/[/)")
  end

  test "refuses U+2028/U+2029 in body and never raises on invalid UTF-8" do
    assert {:error, _} = ZodGuard.admit("z.string().regex(/a\u2028b/)")
    assert {:error, _} = ZodGuard.admit("z.string().regex(/a\u2029b/)")
    assert is_tuple(ZodGuard.admit("z.string().regex(/a" <> <<128>> <> "/)"))
  end
end
