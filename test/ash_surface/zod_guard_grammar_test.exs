defmodule AshSurface.ZodGuardGrammarTest do
  use ExUnit.Case, async: true

  alias AshSurface.Projectors.JS.ZodGuard

  @accepted [
    "z.iso.date()",
    "z.iso.datetime()",
    "z.iso.duration()",
    "z.iso.time()",
    "z.uuid()",
    ~s|z.enum(["a", "b"])|,
    ~s|z.literal("x")|,
    "z.literal(3)",
    "z.literal(true)",
    "z.literal(null)",
    ~s|z.discriminatedUnion("kind", [z.object({kind: z.literal("a")}), z.strictObject({kind: z.literal("b")})])|,
    "z.union([z.string(), z.number().int()])",
    "z.record(z.string(), z.unknown())",
    "z.strictObject({a: z.string()})",
    "z.looseObject({a: z.string()})",
    "z.object({a: z.string()}).strict()",
    "z.string().nullable()",
    "z.string().nullish()",
    "z.string().optional()",
    "z.string().min(1).max(5)",
    "z.number().int().min(0)",
    ~S|z.string().regex(/^a\/b$/)|
  ]

  @refused [
    {"z.string().refine(x => x)", "arrow"},
    {"z.string().refine(() => 1)", "arrow"},
    {"z.string().min(foo)", "identifier"},
    {"z.union([foo, z.string()])", "identifier"},
    {"z.literal(window)", "identifier"},
    {"z.string().__proto__", "dunder"},
    {"z.string().__defineGetter__()", "dunder"},
    {"z.string().constructor()", "constructor"},
    {"z.string().prototype", "prototype"},
    {"z.string().call()", "call"},
    {"z.string().apply()", "apply"},
    {"z.string().bind()", "bind"},
    {"z.iso.date().constructor", "constructor"},
    {"z.record(z.string(), z.unknown()).call()", "call"},
    {~s|z.enum(["a"]).bind(1)|, "bind"},
    {~s|z.object({"__proto__": z.string()})|, "proto key"},
    {"z.string().min(1) + 1", "operator"},
    {"z.string().regex(/a/) ; evil()", "statement"},
    {"z", "bare z"},
    {"foo.string()", "non-z root"}
  ]

  for src <- @accepted do
    test "accepts #{src}" do
      assert {:ok, :expression, unquote(src)} = ZodGuard.admit(unquote(src))
    end
  end

  for {src, why} <- @refused do
    test "refuses #{why}: #{src}" do
      assert {:error, _} = ZodGuard.admit(unquote(src))
    end
  end
end
