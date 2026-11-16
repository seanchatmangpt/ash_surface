defmodule AshShadcn.JsonApi.ActorPlug do
  @moduledoc "Demo plug: sets the Ash actor from the `x-actor-id` request header."
  @behaviour Plug
  def init(opts), do: opts

  def call(conn, _opts) do
    case Plug.Conn.get_req_header(conn, "x-actor-id") do
      [id | _] -> Ash.PlugHelpers.set_actor(conn, AshShadcn.load_actor(id))
      _ -> conn
    end
  end
end

defmodule AshShadcn.JsonApi.Pipeline do
  @moduledoc "Forward target: sets the demo actor, then dispatches to Playground.JsonApiRouter."
  @behaviour Plug
  def init(opts), do: opts

  def call(conn, _opts) do
    conn |> AshShadcn.JsonApi.ActorPlug.call([]) |> Playground.JsonApiRouter.call([])
  end
end
