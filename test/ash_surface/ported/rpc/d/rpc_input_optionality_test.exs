defmodule AshSurface.Ported.Rpc.D.RpcInputOptionalityTest do
  @moduledoc """
  Port of ash_typescript `rpc_input_optionality_test.exs`. The reference asserts the generated
  TS input type text (`key?: T` vs `key: T`); ash_surface generates no `.ts`. The source of that
  optionality is the real `Ash.Info.Manifest` action input facts (`required?` / `allow_nil?`)
  that the compiler turns into Zod required/optional/nullable, so they are asserted directly
  on the real Article actions (`allow_nil_input` / `require_attributes`).
  """
  use ExUnit.Case, async: true

  alias AshSurface.Ported.{Article, RFP}

  defp inputs(action) do
    RFP.manifest().action_lookup
    |> Map.fetch!({Article, action})
    |> Map.fetch!(:inputs)
    |> Map.new(&{&1.name, &1})
  end

  describe "create action with allow_nil_input" do
    test "attribute in allow_nil_input is optional even when allow_nil?: false" do
      %{hero_image_url: input} = inputs(:create_with_optional_hero_image)

      # omittable AND nullable via allow_nil_input, though the attribute has allow_nil?: false
      refute input.required?
      assert input.allow_nil?
      assert Ash.Resource.Info.attribute(Article, :hero_image_url).allow_nil? == false
    end

    test "attribute not in allow_nil_input remains required when allow_nil?: false" do
      inputs = inputs(:create_with_optional_hero_image)

      for name <- [:hero_image_alt, :summary, :body] do
        assert inputs[name].required?, "#{name} must be required"
        refute inputs[name].allow_nil?
      end
    end
  end

  describe "update action with require_attributes" do
    test "attribute in require_attributes is required" do
      %{hero_image_alt: input} = inputs(:update_with_required_hero_image_alt)
      assert input.required?
      refute input.allow_nil?
    end

    test "attribute not in require_attributes is optional for update action" do
      inputs = inputs(:update_with_required_hero_image_alt)

      for name <- [:hero_image_url, :summary, :body] do
        refute inputs[name].required?, "#{name} must be optional"
        refute inputs[name].allow_nil?
      end
    end
  end
end
