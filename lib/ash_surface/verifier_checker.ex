defmodule AshSurface.VerifierChecker do
  @moduledoc """
  Port of ash_typescript `VerifierChecker`. Spark reports a failing verifier as
  a compile warning; at codegen time ash_surface wants a hard error. This
  re-runs `AshSurface.Resource.Verify` against each module's persisted DSL
  state and aggregates the failures: `:ok | {:error, message}`.
  """

  @spec check_all_verifiers([module()]) :: :ok | {:error, String.t()}
  def check_all_verifiers(modules) do
    case Enum.flat_map(modules, &check_module/1) do
      [] -> :ok
      errors -> {:error, Enum.map_join(errors, "\n\n", &format/1)}
    end
  end

  defp check_module(module) do
    if AshSurface.Resource in Spark.extensions(module) do
      case AshSurface.Resource.Verify.verify(module.spark_dsl_config()) do
        :ok -> []
        {:error, error} -> [{module, error}]
      end
    else
      []
    end
  rescue
    e -> [{module, e}]
  end

  defp format({module, error}) do
    "Module: #{inspect(module)}\nVerifier: #{inspect(AshSurface.Resource.Verify)}\n" <>
      "Error: " <> if(is_exception(error), do: Exception.message(error), else: inspect(error))
  end
end
