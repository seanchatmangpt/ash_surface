defmodule AshSurface.TS.ZodCodegenTest do
  @moduledoc """
  Real codegen over the ETS fixture domain: the artifact is generated from a
  real Ash manifest and every emitted Zod expression is admitted by ZodGuard.
  """
  use ExUnit.Case, async: false

  alias AshSurface.ZodFixtures.Harness

  setup_all do
    %{artifact: Harness.artifact!()}
  end

  test "artifact is byte-deterministic across generations", %{artifact: a} do
    assert a == Harness.artifact!()
  end

  test "artifact exports the fixture create/read schemas", %{artifact: a} do
    assert a =~ ~s(import { z } from "zod";)
    assert a =~ "export const Todo_create_schema = z.object("
    assert a =~ "export const SCHEMAS"
  end

  test "every emitted schema expression passes ZodGuard.admit/1", %{artifact: a} do
    exprs =
      Regex.scan(~r/export const \w+_schema = (z\.object\((?:(?!export const).)*?\)\.passthrough\(\));/s, a,
        capture: :all_but_first
      )
      |> List.flatten()

    assert exprs != []

    for expr <- exprs do
      assert {:ok, _} = admit(expr)
    end
  end

  test "constraints, enum, optionality surface in the create schema", %{artifact: a} do
    [block] =
      Regex.run(~r/Todo_create_schema = (z\.object.*?\)\.passthrough\(\));/s, a,
        capture: :all_but_first
      )

    assert block =~ "title: z.string().min(1).max(80)"
    assert block =~ "points: z.number().int().min(0).max(100)"
    assert block =~ ~S{z.enum(["closed", "open"])}
    assert block =~ ".optional()"
  end

  defp admit(expr) do
    case AshSurface.Projectors.JS.ZodGuard.admit(expr) do
      :ok -> {:ok, expr}
      {:ok, :expression, _} -> {:ok, expr}
      other -> other
    end
  end
end
