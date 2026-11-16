defmodule AshShadcn.JsonApi do
  @moduledoc "JSON:API helpers: generated OpenAPI spec and the route table."
  @prefix "/admin/api/json"

  def prefix, do: @prefix

  def spec, do: Playground.JsonApiRouter.spec() |> Jason.encode!() |> Jason.decode!()

  def routes do
    for resource <- Ash.Domain.Info.resources(Playground.Blog),
        route <- AshJsonApi.Resource.Info.routes(resource) do
      %{
        resource: inspect(resource),
        method: route.method |> to_string() |> String.upcase(),
        path: @prefix <> route.route,
        action: route.action,
        type: route.type
      }
    end
  end
end
