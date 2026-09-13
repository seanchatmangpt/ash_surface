defmodule AshSurface do
  @moduledoc """
  Manifest-first consumer surfaces for Ash applications.

  `AshSurface` does not define a second resource/action/type model. It starts from
  `Ash.Info.Manifest`, adds only projection metadata under `custom.ash_surface`,
  verifies that metadata against the exact public action set, and exposes a
  versioned, content-addressed contract for downstream projectors.

  Ash's JSON manifest serializer intentionally omits extension `custom` data and
  entrypoint config. The cross-language wrapper therefore carries only the missing
  *derived identity and projection metadata* in its own `surface` envelope while
  all resource/type/action semantics remain owned by the serialized Ash manifest.
  """

  alias Ash.Info.Manifest

  @surface_schema_version "26.9.13"
  @generator_identity "ash_surface:v26.9.13"

  defmodule Surface do
    @moduledoc "A verified Ash surface contract and its exact normalized manifest."

    @enforce_keys [:manifest, :contract, :digest, :action_ids]
    defstruct [:manifest, :contract, :digest, :action_ids]

    @type t :: %__MODULE__{
            manifest: Ash.Info.Manifest.t(),
            contract: map(),
            digest: String.t(),
            action_ids: [String.t()]
          }
  end

  defmodule Projector do
    @moduledoc """
    Behaviour for projecting a verified `AshSurface.Surface` into a consumer artifact.

    Projectors receive an already-normalized, already-verified manifest. They should
    not rediscover Ash resource/action semantics from Spark internals.
    """

    @callback project(AshSurface.Surface.t(), keyword()) ::
                {:ok, term(), map()} | {:error, term()}
  end

  @doc "Returns the version of AshSurface's wrapper contract."
  @spec schema_version() :: String.t()
  def schema_version, do: @surface_schema_version

  @doc "Builds a surface from an OTP application's public Ash manifest."
  @spec from_app(atom(), keyword()) :: {:ok, Surface.t()} | {:error, term()}
  def from_app(otp_app, opts \\ []) when is_atom(otp_app) do
    with {:ok, manifest} <- Manifest.generate(otp_app: otp_app) do
      from_manifest(manifest, opts)
    end
  end

  @doc """
  Builds and verifies a surface from an existing `Ash.Info.Manifest`.

  `:profile` is projection metadata only. Its optional `"actions"` map is keyed by
  `action_id/1`; unknown action ids are refused instead of silently becoming a
  second application model.
  """
  @spec from_manifest(Manifest.t(), keyword()) :: {:ok, Surface.t()} | {:error, term()}
  def from_manifest(%Manifest{} = manifest, opts \\ []) do
    raw_profile = Keyword.get(opts, :profile, %{})
    action_ids = manifest.entrypoints |> Enum.map(&action_id/1) |> Enum.sort()

    with :ok <- validate_profile(raw_profile),
         profile <- normalize_data(raw_profile),
         :ok <- validate_profile_actions(profile, action_ids),
         decorated <- decorate_manifest(manifest, profile),
         contract <- contract(decorated, profile),
         digest <- digest(contract) do
      {:ok,
       %Surface{
         manifest: decorated,
         contract: contract,
         digest: digest,
         action_ids: action_ids
       }}
    end
  end

  @doc "Projects a verified surface through a declared projector module."
  @spec project(Surface.t(), module(), keyword()) :: {:ok, term(), map()} | {:error, term()}
  def project(%Surface{} = surface, projector, opts \\ []) when is_atom(projector) do
    if function_exported?(projector, :project, 2) do
      projector.project(surface, opts)
    else
      {:error, {:unsupported_projector, projector}}
    end
  end

  @doc "Returns the stable identity of an exact manifest entrypoint."
  @spec action_id(Ash.Info.Manifest.Entrypoint.t()) :: String.t()
  def action_id(%Ash.Info.Manifest.Entrypoint{resource: resource, action: action}) do
    "#{module_name(resource)}##{action.name}"
  end

  @doc "Returns the path to the framework-neutral JavaScript runtime adapter."
  @spec runtime_path() :: String.t()
  def runtime_path do
    Application.app_dir(:ash_surface, "priv/static/ash_surface_runtime.mjs")
  end

  @doc "Reads the framework-neutral JavaScript runtime adapter."
  @spec runtime_source() :: {:ok, binary()} | {:error, File.posix()}
  def runtime_source, do: File.read(runtime_path())

  defp contract(%Manifest{} = manifest, profile) do
    %{
      "surfaceSchemaVersion" => @surface_schema_version,
      "ashManifestSchemaVersion" => Manifest.schema_version(),
      "generatorIdentity" => @generator_identity,
      "manifest" => Ash.Info.Manifest.JsonSerializer.to_map(manifest),
      "surface" => surface_envelope(manifest, profile)
    }
  end

  defp surface_envelope(%Manifest{} = manifest, profile) do
    actions_profile = Map.get(profile, "actions", %{})

    actions =
      manifest.entrypoints
      |> Enum.map(fn entrypoint ->
        id = action_id(entrypoint)
        act_prof = Map.get(actions_profile, id, %{})

        # Infer authority boundary default from action type
        default_boundary =
          case entrypoint.action.type do
            :read -> "OBSERVE"
            _ -> "DO"
          end

        authority_boundary = Map.get(act_prof, "authorityBoundary", default_boundary)
        do_authority = Map.get(act_prof, "doAuthority", authority_boundary == "DO")

        %{
          "id" => id,
          "semanticId" => Map.get(act_prof, "semanticId", "ash:#{id}"),
          "resource" => module_name(entrypoint.resource),
          "action" => to_string(entrypoint.action.name),
          "authorityBoundary" => authority_boundary,
          "doAuthority" => do_authority,
          "receiptRequired" => Map.get(act_prof, "receiptRequired", true),
          "evidenceRequired" => Map.get(act_prof, "evidenceRequired", false),
          "possibleRefusals" => Map.get(act_prof, "possibleRefusals", []),
          "profile" => act_prof
        }
      end)
      |> Enum.sort_by(& &1["id"])

    %{
      "profile" => Map.delete(profile, "actions"),
      "actions" => actions
    }
  end

  defp decorate_manifest(%Manifest{} = manifest, profile) do
    actions_profile = Map.get(profile, "actions", %{})

    entrypoints =
      Enum.map(manifest.entrypoints, fn entrypoint ->
        id = action_id(entrypoint)
        action_profile = Map.get(actions_profile, id, %{})
        action = entrypoint.action

        surface_custom = %{
          "id" => id,
          "profile" => action_profile
        }

        custom = Map.put(action.custom || %{}, :ash_surface, surface_custom)
        %{entrypoint | action: %{action | custom: custom}}
      end)

    root_custom =
      Map.put(manifest.custom || %{}, :ash_surface, %{
        "schemaVersion" => @surface_schema_version,
        "profile" => Map.delete(profile, "actions")
      })

    %{manifest | entrypoints: entrypoints, custom: root_custom}
  end

  defp validate_profile(profile) when is_map(profile), do: validate_json_data(profile)
  defp validate_profile(_), do: {:error, :profile_must_be_a_map}

  defp validate_json_data(value)
       when is_binary(value) or is_number(value) or is_boolean(value) or is_nil(value) or
              is_atom(value),
       do: :ok

  defp validate_json_data(value) when is_list(value) do
    Enum.reduce_while(value, :ok, fn item, :ok ->
      case validate_json_data(item) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_json_data(value) when is_map(value) do
    Enum.reduce_while(value, :ok, fn {key, item}, :ok ->
      cond do
        not (is_binary(key) or is_atom(key)) ->
          {:halt, {:error, {:profile_key_not_serializable, key}}}

        true ->
          case validate_json_data(item) do
            :ok -> {:cont, :ok}
            error -> {:halt, error}
          end
      end
    end)
  end

  defp validate_json_data(value), do: {:error, {:profile_value_not_serializable, value}}

  defp validate_profile_actions(profile, action_ids) do
    actions = Map.get(profile, "actions", %{})

    cond do
      not is_map(actions) ->
        {:error, :profile_actions_must_be_a_map}

      true ->
        known = MapSet.new(action_ids)

        unknown =
          actions
          |> Map.keys()
          |> Enum.reject(&MapSet.member?(known, &1))
          |> Enum.sort()

        if unknown == [], do: :ok, else: {:error, {:unknown_action_profile, unknown}}
    end
  end

  defp digest(contract) do
    contract
    |> canonical_term()
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp canonical_term(term) when is_map(term) do
    term
    |> Enum.map(fn {key, value} -> {to_string(key), canonical_term(value)} end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  defp canonical_term(term) when is_list(term), do: Enum.map(term, &canonical_term/1)
  defp canonical_term(term), do: term

  defp normalize_data(value)
       when is_binary(value) or is_number(value) or is_boolean(value) or is_nil(value),
       do: value

  defp normalize_data(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_data(value) when is_list(value), do: Enum.map(value, &normalize_data/1)

  defp normalize_data(value) when is_map(value) do
    Map.new(value, fn {key, item} -> {normalize_key(key), normalize_data(item)} end)
  end

  defp normalize_data(value), do: value

  defp normalize_key(key) when is_binary(key), do: key
  defp normalize_key(key) when is_atom(key), do: Atom.to_string(key)
  defp normalize_key(key), do: to_string(key)

  defp module_name(module), do: module |> Module.split() |> Enum.join(".")
end
