defmodule AshSurface.Compiler.EmittedKeyCollisionCrossSectionTest do
  @moduledoc "Wave-3 RN: SK-fw defects 1 and 2 (calc-argument and destination collisions)."
  use ExUnit.Case, async: true

  alias AshSurface.Compiler

  defmodule CalcDomain do
    use Ash.Domain, validate_config_inclusion?: false
    resources do
      resource(AshSurface.Compiler.EmittedKeyCollisionCrossSectionTest.CalcRes)
    end
  end

  defmodule CalcRes do
    use Ash.Resource, domain: CalcDomain, data_layer: Ash.DataLayer.Ets, extensions: [AshSurface.Resource]
    ets do
      private?(true)
    end
    surface do
      type_name("CalcRes")
    end
    attributes do
      uuid_primary_key(:id, public?: true)
    end
    calculations do
      calculate :c1, :string, expr("x") do
        public?(true)
        argument(:pre_fix, :string)
        argument(:preFix, :string)
      end
    end
    actions do
      defaults([:read])
    end
  end

  defmodule KidDomain do
    use Ash.Domain, validate_config_inclusion?: false
    resources do
      resource(AshSurface.Compiler.EmittedKeyCollisionCrossSectionTest.Top)
      resource(AshSurface.Compiler.EmittedKeyCollisionCrossSectionTest.Kid)
    end
  end

  defmodule Kid do
    use Ash.Resource, domain: KidDomain, data_layer: Ash.DataLayer.Ets
    ets do
      private?(true)
    end
    attributes do
      uuid_primary_key(:id, public?: true)
      attribute(:foo_bar, :string, public?: true)
      attribute(:fooBar, :string, public?: true)
      attribute(:top_id, :uuid, public?: true)
    end
  end

  defmodule Top do
    use Ash.Resource, domain: KidDomain, data_layer: Ash.DataLayer.Ets, extensions: [AshSurface.Resource]
    ets do
      private?(true)
    end
    surface do
      type_name("Top")
    end
    attributes do
      uuid_primary_key(:id, public?: true)
    end
    relationships do
      has_many(:kids, AshSurface.Compiler.EmittedKeyCollisionCrossSectionTest.Kid,
        destination_attribute: :top_id,
        public?: true
      )
    end
    actions do
      defaults([:read])
    end
  end

  defmodule AggDomain do
    use Ash.Domain, validate_config_inclusion?: false
    resources do
      resource(AshSurface.Compiler.EmittedKeyCollisionCrossSectionTest.AggRes)
      resource(AshSurface.Compiler.EmittedKeyCollisionCrossSectionTest.PlainKid)
    end
  end

  defmodule PlainKid do
    use Ash.Resource, domain: AggDomain, data_layer: Ash.DataLayer.Ets
    ets do
      private?(true)
    end
    attributes do
      uuid_primary_key(:id, public?: true)
      attribute(:agg_res_id, :uuid, public?: true)
      attribute(:foo_bar, :string, public?: true)
    end
    relationships do
      has_many(:subs, AshSurface.Compiler.EmittedKeyCollisionCrossSectionTest.PlainKid,
        destination_attribute: :agg_res_id,
        public?: true
      )
    end
    aggregates do
      count(:fooBar, :subs, public?: true)
    end
  end

  defmodule AggRes do
    use Ash.Resource, domain: AggDomain, data_layer: Ash.DataLayer.Ets, extensions: [AshSurface.Resource]
    ets do
      private?(true)
    end
    surface do
      type_name("AggRes")
    end
    attributes do
      uuid_primary_key(:id, public?: true)
    end
    relationships do
      has_many(:kids, AshSurface.Compiler.EmittedKeyCollisionCrossSectionTest.PlainKid,
        destination_attribute: :agg_res_id,
        public?: true
      )
    end
    actions do
      defaults([:read])
    end
  end

  defmodule IdDomain do
    use Ash.Domain, validate_config_inclusion?: false
    resources do
      resource(AshSurface.Compiler.EmittedKeyCollisionCrossSectionTest.IdRes)
    end
  end

  defmodule IdRes do
    use Ash.Resource, domain: IdDomain, data_layer: Ash.DataLayer.Ets, extensions: [AshSurface.Resource]
    ets do
      private?(true)
    end
    surface do
      type_name("IdRes")
    end
    attributes do
      uuid_primary_key(:id, public?: true)
      attribute(:foo_bar, :string, public?: false)
      attribute(:fooBar, :string, public?: false)
    end
    identities do
      identity(:by_foo, [:foo_bar, :fooBar], pre_check_with: IdDomain)
    end
    actions do
      defaults([:read])
    end
  end

  defmodule DeepDomain do
    use Ash.Domain, validate_config_inclusion?: false
    resources do
      resource(AshSurface.Compiler.EmittedKeyCollisionCrossSectionTest.DeepTop)
      resource(AshSurface.Compiler.EmittedKeyCollisionCrossSectionTest.DeepMid)
      resource(AshSurface.Compiler.EmittedKeyCollisionCrossSectionTest.DeepKid)
    end
  end

  defmodule DeepKid do
    use Ash.Resource, domain: DeepDomain, data_layer: Ash.DataLayer.Ets
    ets do
      private?(true)
    end
    attributes do
      uuid_primary_key(:id, public?: true)
      attribute(:foo_bar, :string, public?: true)
      attribute(:fooBar, :string, public?: true)
      attribute(:mid_id, :uuid, public?: true)
    end
  end

  defmodule DeepMid do
    use Ash.Resource, domain: DeepDomain, data_layer: Ash.DataLayer.Ets
    ets do
      private?(true)
    end
    attributes do
      uuid_primary_key(:id, public?: true)
      attribute(:top_id, :uuid, public?: true)
    end
    relationships do
      has_many(:kids, AshSurface.Compiler.EmittedKeyCollisionCrossSectionTest.DeepKid,
        destination_attribute: :mid_id,
        public?: true
      )
    end
  end

  defmodule DeepTop do
    use Ash.Resource, domain: DeepDomain, data_layer: Ash.DataLayer.Ets, extensions: [AshSurface.Resource]
    ets do
      private?(true)
    end
    surface do
      type_name("DeepTop")
    end
    attributes do
      uuid_primary_key(:id, public?: true)
    end
    relationships do
      has_many(:mids, AshSurface.Compiler.EmittedKeyCollisionCrossSectionTest.DeepMid,
        destination_attribute: :top_id,
        public?: true
      )
    end
    actions do
      defaults([:read])
    end
  end

  defp collision?({:error, {:section_failed, _, r}}), do: collision?({:error, r})
  defp collision?({:error, {_, r}}) when is_tuple(r), do: collision?({:error, r})
  defp collision?({:error, {:emitted_key_collision, _, _, _}}), do: true
  defp collision?({:error, {:field_name_collision, _, _, _}}), do: true
  defp collision?(_), do: false

  test "calculation arguments pre_fix and preFix are refused" do
    result = Compiler.compile(CalcDomain)
    assert collision?(result), inspect(result)
  end

  test "destination resource with no actions and colliding fields is refused" do
    result = Compiler.compile(KidDomain)
    assert collision?(result), inspect(result)
  end

  test "destination aggregate fooBar colliding with attribute foo_bar is refused" do
    result = Compiler.compile(AggDomain)
    assert collision?(result), inspect(result)
  end

  test "identity keys foo_bar and fooBar (private attributes) are refused" do
    result = Compiler.compile(IdDomain)
    assert collision?(result), inspect(result)
  end

  test "collision two relationship hops from the root is refused" do
    result = Compiler.compile(DeepDomain)
    assert collision?(result), inspect(result)
  end
end
