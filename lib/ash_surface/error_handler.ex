defmodule AshSurface.ErrorHandler do
  @moduledoc """
  Behaviour for custom error handlers.

  A handler receives an error map (already transformed from the raw exception) and a
  context map (`:domain`, `:resource`, `:action`, `:actor`, ...). It returns the
  transformed error map, or `nil` to drop the error.

  Handlers chain resource -> domain -> default; the default is the identity.
  """

  @callback handle_error(error :: map(), context :: map()) :: map() | nil

  @doc "Identity handler used as the last link of the chain."
  @spec handle_error(map() | nil, map()) :: map() | nil
  def handle_error(error, _context) when is_map(error) or is_nil(error), do: error

  @doc """
  Runs `error` through the handler chain: `resource_handler`, then `domain_handler`,
  then the default identity. Handlers are modules, `{module, function, extra_args}`
  tuples, or `nil`. A `nil` result short-circuits the chain.
  """
  @spec chain(map() | nil, map(), [module() | {module(), atom(), list()} | nil]) :: map() | nil
  def chain(error, context, handlers) do
    handlers
    |> Enum.reject(&is_nil/1)
    |> Kernel.++([__MODULE__])
    |> Enum.reduce_while(error, fn
      _handler, nil -> {:halt, nil}
      handler, acc -> {:cont, invoke(handler, acc, context)}
    end)
  end

  # No `apply/3` (no_local_do_test): resolve a remote capture, call it with 0..3 extra args.
  defp invoke({mod, fun, extra}, error, context) when is_list(extra) and length(extra) <= 3 do
    f = Function.capture(mod, fun, 2 + length(extra))

    case extra do
      [] -> f.(error, context)
      [a] -> f.(error, context, a)
      [a, b] -> f.(error, context, a, b)
      [a, b, c] -> f.(error, context, a, b, c)
    end
  end

  defp invoke(mod, error, context) when is_atom(mod), do: mod.handle_error(error, context)
end
