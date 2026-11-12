defmodule AshSurface.Ported.Rpc.RunAction.GenericActionsGapTest do
  use ExUnit.Case, async: true

  describe "get_custom_data_list action (array of unconstrained maps)" do
    @tag skip:
           "T6b gap: asserts generated TypeScript text; AshSurface generates no .ts/.d.ts (needs a Zod/IR adaptation)"
    test "generated result type is Array<Record<string, any>>" do
      :ok
    end

    @tag skip:
           "T6b gap: asserts generated TypeScript text; AshSurface generates no .ts/.d.ts (needs a Zod/IR adaptation)"
    test "non-array unconstrained map result type remains Record<string, any>" do
      :ok
    end
  end

  describe "NewType wrapping map return type (get_suggestion)" do
    @tag skip:
           "T6b gap: asserts generated TypeScript text; AshSurface generates no .ts/.d.ts (needs a Zod/IR adaptation)"
    test "codegen generates fields type for NewType map return" do
      :ok
    end
  end

  describe "array of NewType wrapping map return type (list_suggestions)" do
    @tag skip:
           "T6b gap: asserts generated TypeScript text; AshSurface generates no .ts/.d.ts (needs a Zod/IR adaptation)"
    test "codegen generates fields type for array of NewType map return" do
      :ok
    end
  end
end
