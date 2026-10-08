defmodule SparkClosureConsumer.Example do
  @moduledoc """
  Minimal Ash domain fixture module -- the installer's domain-level patch target
  (unused by the current resource-target scenarios; kept generic for other lanes).
  """
  use Ash.Domain

  resources do
    resource SparkClosureConsumer.Example.Post
  end
end
