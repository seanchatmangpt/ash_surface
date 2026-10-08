defmodule SparkClosureConsumer.Example.Post do
  @moduledoc """
  Minimal Ash resource patch target for the idempotence court scenarios. No
  extensions pre-installed: installing is the act under court.
  """
  use Ash.Resource,
    domain: SparkClosureConsumer.Example,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key :id
  end
end
