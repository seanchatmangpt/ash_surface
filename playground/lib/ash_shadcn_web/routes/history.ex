defmodule AshShadcnWeb.Routes.History do
  @moduledoc "Lane `history` routes (inside scope \"/admin/api\", module AshShadcnWeb)."
  defmacro routes do
    quote do
      get "/resources/:resource/records/:id/versions", HistoryController, :versions
      get "/resources/:resource/state_machine", HistoryController, :state_machine
      get "/resources/:resource/archived", HistoryController, :archived
      post "/resources/:resource/archived/:id/restore", HistoryController, :restore
    end
  end
end
