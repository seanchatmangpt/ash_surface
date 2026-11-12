defmodule AshSurface.Projectors.JS.ZodGuardTest do
  @moduledoc """
  Courts for the constraint chains lanes L04/L05 emit: `.enum`, `.min`,
  `.max`, `.int`, `.regex` with `.optional().nullable()` suffixes, plus the
  standing refusal set (constructor, dunder, `__proto__` key, function
  literals, template literals).
  """
  use ExUnit.Case, async: true

  alias AshSurface.Projectors.JS.ZodGuard

  @admitted [
    ~s{z.enum(["a","b"])},
    "z.number().int().min(1).max(100)",
    "z.string().min(1).regex(/^[a-z]+$/)",
    ~s{z.enum(["a","b"]).optional().nullable()},
    "z.number().int().min(1).max(100).optional().nullable()",
    "z.string().min(1).regex(/^[a-z]+$/).optional().nullable()",
    "z.string().regex(/^[a-z]+$/i)",
    "z.enum([\"a\",\"b\"], { errorMap: z.string() })"
  ]

  @refused [
    # constructor / Function-constructor reach
    {"z.string().constructor()", :zod_denied_member},
    # dunder members
    {"z.string().__proto__", :zod_denied_member},
    {"z.string().__defineGetter__(\"x\")", :zod_denied_member},
    # __proto__ as object key (bare + escaped string spelling)
    {"z.object({ \"__proto__\": z.string() })", :zod_denied_key},
    {"z.object({ \"\\u005f\\u005fproto__\": z.string() })", :zod_denied_key},
    # arbitrary function literals
    {"z.string().transform(function(){ return 1 })", :zod_denied_member},
    # `=` is not a token in the grammar, so the arrow fails as unadmitted text.
    {"z.string().refine((v) => true)", :zod_unadmitted_text},
    # template literals (with and without interpolation)
    {"z.string().regex(`^[a-z]+$`)", :zod_unadmitted_text},
    {"z.string().regex(`^[a-z]+${1}$`)", :zod_unadmitted_text},
    # computed member access / non-z roots
    # `z` not followed by `.` is a bare-z refusal (computed access unreachable).
    {"z[string]", :zod_bare_z},
    {"process.env.HOME", :zod_expected_z},
    # operators (`+` is untokenized text, not a value)
    {"z.string().min(1+1)", :zod_unadmitted_text}
  ]

  test "admits the L04/L05 constraint chains" do
    for src <- @admitted do
      assert {:ok, :expression, ^src} = ZodGuard.admit(src)
    end
  end

  test "refuses injection vectors with typed reasons" do
    for {src, reason_tag} <- @refused do
      assert {:error, reason} = ZodGuard.admit(src)
      reason_atom = if is_tuple(reason), do: elem(reason, 0), else: reason

      assert reason_atom == reason_tag,
             "expected #{reason_tag} for #{src}, got: #{inspect(reason)}"
    end
  end
end
