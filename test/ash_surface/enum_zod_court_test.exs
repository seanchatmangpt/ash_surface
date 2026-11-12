defmodule AshSurface.EnumZodCourtTest do
  @moduledoc """
  F1-enum court: enum projection executed under real node + real zod.

  Reference (`~/ash_typescript` codegen/schema_core.ex `format_enum_values/2` +
  `ZodSchemaGenerator.format_enum/1`): values sorted by `to_string`, rendered as quoted strings
  inside `z.enum([...])`. Atoms cross the JSON wire as strings, so atom-valued `one_of` and
  `kind: "enum"` both project to the same string enum. A valid member is accepted, a non-member,
  a non-string, and the atom's inspect form (`":active"`) are rejected.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.ZodType

  @root Path.expand("../..", __DIR__)
  @golden ~s|z.enum(["active", "archived", "paused"])|
  @accept ["active", "archived", "paused"]
  @reject ["deleted", "", "Active", ":active", 1, nil, ["active"], %{}]

  defp frag_enum_kind(values),
    do: ZodType.fragment(%{"type" => %{"kind" => "enum", "values" => values}})

  defp frag_one_of(kind, values),
    do: ZodType.fragment(%{"type" => %{"kind" => kind}, "constraints" => %{"one_of" => values}})

  test "atom and string members, any order, project to the reference's sorted string z.enum" do
    assert frag_enum_kind([:paused, :active, :archived]) == @golden
    assert frag_enum_kind(["paused", "active", "archived", "active"]) == @golden
    assert frag_one_of("atom", [:paused, :active, :archived]) == @golden
    assert frag_one_of("string", ["archived", "paused", "active"]) == @golden
  end

  test "real zod: members accepted, non-members rejected; identical to the reference form" do
    script = """
    import { z } from "zod";
    const ours = #{frag_enum_kind([:paused, :active, :archived])};
    const ref = z.enum(["active", "archived", "paused"]);
    const ok = #{Jason.encode!(@accept)}.map((v) => [ours.safeParse(v).success, ref.safeParse(v).success]);
    const bad = #{Jason.encode!(@reject)}.map((v) => [ours.safeParse(v).success, ref.safeParse(v).success]);
    console.log(JSON.stringify({ ok, bad }));
    """

    {out, 0} = System.cmd("node", ["--input-type=module", "-e", script], cd: @root)
    %{"ok" => ok, "bad" => bad} = Jason.decode!(out)
    assert ok == for(_ <- @accept, do: [true, true])
    assert bad == for(_ <- @reject, do: [false, false])
  end
end
