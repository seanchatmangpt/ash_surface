defmodule AshSurface.Envelope do
  @moduledoc """
  Pure data builders for the response envelope: `%{"success" => true, "data" => d}`
  and `%{"success" => false, "errors" => [...]}`. Errors go through the public
  `AshSurface.Errors.to_errors/2` (handler chain + `ErrorFormatter` key formatting).
  """

  alias AshSurface.Errors

  @spec ok(term()) :: map()
  def ok(data), do: %{"success" => true, "data" => data}

  @spec error(term(), keyword()) :: map()
  def error(errors, opts \\ []),
    do: %{"success" => false, "errors" => Errors.to_errors(errors, opts)}
end
