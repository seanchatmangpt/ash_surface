defmodule Playground.Editorial do
  @moduledoc "Demo domain for the history lane: paper trail + archival + state machine."
  use Ash.Domain, otp_app: :playground, extensions: [AshPaperTrail.Domain]

  resources do
    resource Playground.Editorial.Article
  end
end
