defmodule AshShadcnWeb.Realtime.Socket do
  @moduledoc "Admin realtime socket. Clients join `admin:<ResourceModule>` channels."
  use Phoenix.Socket

  channel "admin:*", AshShadcnWeb.Realtime.Channel

  @impl true
  def connect(_params, socket, _connect_info), do: {:ok, socket}

  @impl true
  def id(_socket), do: nil
end
