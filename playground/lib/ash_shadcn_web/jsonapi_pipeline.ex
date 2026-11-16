defmodule AshShadcnWeb.JsonApiPipeline do
  @moduledoc "Scope-resolvable forward target for the JSON:API pipeline."
  defdelegate init(opts), to: AshShadcn.JsonApi.Pipeline
  defdelegate call(conn, opts), to: AshShadcn.JsonApi.Pipeline
end
