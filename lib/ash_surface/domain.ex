defmodule AshSurface.Domain do
  @moduledoc """
  Domain-level `ash_surface` extension: a default `namespace` for every
  resource of the domain (port of ash_typescript's domain `namespace`).
  A resource-level `namespace` overrides it
  (`AshSurface.Resource.Info.effective_namespace/1`).
  """

  @surface %Spark.Dsl.Section{
    name: :surface,
    describe: "Domain-level consumer projection defaults.",
    schema: [
      namespace: [
        type: :string,
        required: false,
        doc: "Default namespace (filename) for all resources in this domain."
      ]
    ]
  }

  use Spark.Dsl.Extension,
    sections: [@surface],
    verifiers: [AshSurface.Domain.Verify]
end

defmodule AshSurface.Domain.Verify do
  @moduledoc false
  use Spark.Dsl.Verifier

  @impl true
  def verify(dsl_state) do
    with :ok <- verify_unique_type_names(dsl_state) do
      warn_unconfigured(dsl_state)
      :ok
    end
  end

  # Port of ash_typescript VerifyUniqueTypeNames: surface type names (explicit
  # `type_name`, else the resource's short module name) are unique per domain.
  defp verify_unique_type_names(dsl_state) do
    dups =
      dsl_state
      |> surface_resources()
      |> Enum.group_by(&effective_type_name/1)
      |> Enum.filter(fn {_name, resources} -> length(resources) > 1 end)
      |> Enum.sort()

    case dups do
      [] ->
        :ok

      _ ->
        detail =
          Enum.map_join(dups, "; ", fn {name, resources} ->
            "type name #{inspect(name)} is used by #{Enum.map_join(resources, ", ", &inspect/1)}"
          end)

        {:error,
         Spark.Error.DslError.exception(
           module: Spark.Dsl.Verifier.get_persisted(dsl_state, :module),
           path: [:surface],
           message: "duplicate_type_names: #{detail}"
         )}
    end
  end

  # Port of ash_typescript VerifyRpcWarnings (informational, stderr, never an
  # error): surface resources that declare no projection or typed query.
  # Gated by `AshSurface.Config.warn_on_missing_rpc_config/0`.
  defp warn_unconfigured(dsl_state) do
    if AshSurface.Config.warn_on_missing_rpc_config() do
      for resource <- surface_resources(dsl_state),
          AshSurface.Resource.Info.surface(resource) == [] do
        IO.puts(
          :stderr,
          "ash_surface warning: #{inspect(resource)} uses AshSurface.Resource but declares no surface projection"
        )
      end
    end

    :ok
  end

  defp surface_resources(dsl_state) do
    dsl_state
    |> Ash.Domain.Info.resources()
    |> Enum.filter(fn r ->
      Code.ensure_loaded?(r) and AshSurface.Resource in Spark.extensions(r)
    end)
  end

  defp effective_type_name(resource) do
    AshSurface.Resource.Info.type_name(resource) ||
      resource |> Module.split() |> List.last()
  end
end

defmodule AshSurface.Domain.Info do
  @moduledoc "Introspection for `AshSurface.Domain`."

  @doc "The domain's `surface namespace`, or nil."
  def namespace(domain), do: Spark.Dsl.Extension.get_opt(domain, [:surface], :namespace, nil)
end
