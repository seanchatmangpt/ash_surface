defmodule AshSurface.Config.ConsumerCourtsTest do
  @moduledoc """
  Consumer-effect courts (wave3-f1cc): a config key is only a capability when a
  reader in lib/ changes observable output. Real Ash resource, real facts, real env.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Compiler.ResourceFacts

  defmodule Res do
    use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Simple

    attributes do
      uuid_primary_key :id, public?: true
    end

    actions do
      read :by_id do
        get? true
      end
    end
  end

  setup do
    prior = Application.fetch_env(:ash_surface, :not_found_error?)

    on_exit(fn ->
      case prior do
        {:ok, v} -> Application.put_env(:ash_surface, :not_found_error?, v)
        :error -> Application.delete_env(:ash_surface, :not_found_error?)
      end
    end)
  end

  test "config.key.not_found_error? decides the get fact when no projection declares it" do
    action = Ash.Resource.Info.action(Res, :by_id)

    Application.delete_env(:ash_surface, :not_found_error?)
    assert %{get?: true, not_found_error?: true} = ResourceFacts.build(Res, action)

    Application.put_env(:ash_surface, :not_found_error?, false)
    assert %{get?: true, not_found_error?: false} = ResourceFacts.build(Res, action)
  end
end
