defmodule AshSurface do
  @moduledoc """
  Manifest-first consumer surfaces for Ash applications.

  `AshSurface` does not define a second resource/action/type model. It starts from
  `Ash.Info.Manifest`, adds only projection metadata under `custom.ash_surface`,
  verifies that metadata against the exact public action set, and exposes a
  versioned, content-addressed contract for downstream projectors.

  Ash's JSON manifest serializer intentionally omits extension `custom` data and
  entrypoint config. The cross-language wrapper therefore carries only the missing
  *delegated identity and projection metadata* in its own `surface` envelope while
  all resource/type/action semantics remain owned by the serialized Ash manifest.
  """

  alias Ash.Info.Manifest

  @surface_schema_version "26.10.1"
  @generator_identity "ash_surface:v26.10.1"

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

  ## Examples

      iex> alias Ash.Info.Manifest
      iex> manifest = %Manifest{entrypoints: []}
      iex> {:ok, surface} = AshSurface.from_manifest(manifest, profile: %{"tier" => "gold"})
      iex> {surface.action_ids, surface.contract["surface"]["profile"], byte_size(surface.digest)}
      {[], %{"tier" => "gold"}, 64}

      A profile keyed by an unknown action id is refused, never silently kept:

      iex> manifest = %Ash.Info.Manifest{entrypoints: []}
      iex> AshSurface.from_manifest(manifest, profile: %{"actions" => %{"Nope#x" => %{}}})
      {:error, {:unknown_action_profile, ["Nope#x"]}}
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

  @doc """
  Projects a verified surface through a declared projector module.

  Public facade over the single projector contract
  (`AshSurface.Projector.IR`): the surface travels as `ash_surface.surface` IR
  and the projector's `project_ir/2` runs over it. A module without
  `project_ir/2` is refused with `{:unsupported_projector, module}`.
  """
  @spec project(Surface.t(), module(), keyword()) :: {:ok, term(), map()} | {:error, term()}
  def project(%Surface{} = surface, projector, opts \\ []) when is_atom(projector) do
    Code.ensure_loaded(projector)

    if function_exported?(projector, :project_ir, 2) do
      {:ok, ir} = AshSurface.Projector.IR.from_surface(surface)
      AshSurface.Projector.IR.project(projector, ir, opts)
    else
      {:error, {:unsupported_projector, projector}}
    end
  end

  @doc "Returns the stable identity of an exact manifest entrypoint."
  @spec action_id(Ash.Info.Manifest.Entrypoint.t()) :: String.t()
  def action_id(%Ash.Info.Manifest.Entrypoint{resource: resource, action: action}) do
    "#{module_name(resource)}##{action.name}"
  end

  @doc """
  Reads a delegated fact for a manifest entrypoint from its `custom.ash_surface`
  IR section.

  Delegated facts are `"semanticId"`, `"authorityBoundary"`, `"doAuthority"`,
  and `"receiptRequired"` (see `AshSurface.IR.delegated_facts/0`). The value
  comes from the manifest's `custom.ash_surface` metadata when a delegating
  authority stored it there and is `nil` otherwise. AshSurface never
  re-derives delegated facts.
  """
  @spec delegated(Ash.Info.Manifest.Entrypoint.t(), String.t()) :: term() | nil
  def delegated(%Ash.Info.Manifest.Entrypoint{} = entrypoint, fact) do
    AshSurface.IR.delegated(entrypoint, fact)
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
    serialized_manifest = Ash.Info.Manifest.JsonSerializer.to_map(manifest)
    manifest_digest = digest(serialized_manifest)

    %{
      "surfaceSchemaVersion" => @surface_schema_version,
      "ashManifestSchemaVersion" => Manifest.schema_version(),
      "generatorIdentity" => @generator_identity,
      "manifestDigest" => manifest_digest,
      "marketplaceIdentity" => "ggen-marketplace:v26.10.1",
      "manifest" => serialized_manifest,
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

        # v26.10.1 delegation: semanticId, authorityBoundary, doAuthority, and
        # receiptRequired are delegated facts read from the IR section
        # (custom.ash_surface). They are nil when not delegated — never
        # re-derived here.
        %{
          "id" => id,
          "semanticId" => AshSurface.IR.delegated(entrypoint, "semanticId"),
          "resource" => module_name(entrypoint.resource),
          "action" => to_string(entrypoint.action.name),
          "authorityBoundary" => AshSurface.IR.delegated(entrypoint, "authorityBoundary"),
          "doAuthority" => AshSurface.IR.delegated(entrypoint, "doAuthority"),
          "receiptRequired" => AshSurface.IR.delegated(entrypoint, "receiptRequired"),
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

        # Ash.Info.Manifest.Action.custom is contractually map() (struct
        # default %{}); no nil fallback exists or is needed (dialyzer
        # guard_fail, gapfix-dialyzer-010).
        custom = Map.put(action.custom, :ash_surface, surface_custom)
        %{entrypoint | action: %{action | custom: custom}}
      end)

    # Manifest.custom is contractually map() (struct default %{}); same
    # no-nil-fallback reasoning as the action custom above.
    root_custom =
      Map.put(manifest.custom, :ash_surface, %{
        "schemaVersion" => @surface_schema_version,
        "profile" => Map.delete(profile, "actions")
      })

    %{manifest | entrypoints: entrypoints, custom: root_custom}
  end

  defp validate_profile(profile) when is_map(profile), do: validate_json_data(profile)
  defp validate_profile(_), do: {:error, :profile_must_be_a_map}

  # A binary must be valid UTF-8 (keys and values): Jason cannot encode
  # anything else, so admitting it yields a contract that cannot serialize.
  defp validate_json_data(value) when is_binary(value) do
    if String.valid?(value),
      do: :ok,
      else: {:error, {:profile_value_not_serializable, value}}
  end

  defp validate_json_data(value)
       when is_number(value) or is_boolean(value) or is_nil(value) or is_atom(value),
       do: :ok

  # An improper list ([1 | 2]) is not JSON data and would raise in Enum.
  defp validate_json_data(value) when is_list(value) do
    if proper_list?(value),
      do: validate_json_items(value),
      else: {:error, {:profile_value_not_serializable, value}}
  end

  # Structs (DateTime, MapSet, ...) are not JSON data: refused before the map
  # clause, which would otherwise enumerate them (Protocol.UndefinedError /
  # FunctionClauseError instead of a typed error).
  defp validate_json_data(value) when is_struct(value),
    do: {:error, {:profile_value_not_serializable, value}}

  defp validate_json_data(value) when is_map(value) do
    Enum.reduce_while(value, :ok, fn {key, item}, :ok ->
      cond do
        not (is_binary(key) or is_atom(key)) or (is_binary(key) and not String.valid?(key)) ->
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

        if unknown == [],
          do: validate_action_profiles(actions),
          else: {:error, {:unknown_action_profile, unknown}}
    end
  end

  defp proper_list?([]), do: true
  defp proper_list?([_head | tail]), do: proper_list?(tail)
  defp proper_list?(_improper_tail), do: false

  defp validate_json_items(value) do
    Enum.reduce_while(value, :ok, fn item, :ok ->
      case validate_json_data(item) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  # Each per-action profile must be a map, and the fields the JS contract
  # schema types (surfaceActionSchema in priv/static/ash_surface_runtime.mjs:
  # `evidenceRequired: z.boolean()`, `possibleRefusals: z.array(z.string()...)`)
  # must carry those types when present. Every declared refusal is a
  # "REFUSED_"-prefixed code with a named reason — the same law as the JS
  # refusalCodeSchema (/^REFUSED_.+/) and AshSurface.Standing's REFUSED_*
  # class — so Elixir never emits a contract the consumer runtime rejects.
  # Dispatch outcomes such as UNKNOWN_AFTER_DISPATCH are not refusals.
  defp validate_action_profiles(actions) do
    actions
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.find_value(:ok, fn {id, action_profile} ->
      validate_action_profile(id, action_profile)
    end)
  end

  defp validate_action_profile(id, action_profile) when not is_map(action_profile),
    do: {:error, {:action_profile_must_be_a_map, id, action_profile}}

  defp validate_action_profile(id, action_profile) do
    evidence = Map.get(action_profile, "evidenceRequired", false)
    refusals = Map.get(action_profile, "possibleRefusals", [])

    cond do
      not is_boolean(evidence) ->
        {:error, {:evidence_required_must_be_boolean, id, evidence}}

      not (is_list(refusals) and Enum.all?(refusals, &is_binary/1)) ->
        {:error, {:possible_refusals_must_be_strings, id, refusals}}

      bad = Enum.reject(refusals, &refusal_code?/1) |> Enum.take(1) |> List.first() ->
        {:error, {:possible_refusal_not_a_refusal_code, id, bad}}

      true ->
        nil
    end
  end

  defp refusal_code?(code), do: AshSurface.Vocabulary.refusal_code?(code)

  @doc """
  The content address of a contract map: lowercase sha256 hex over the
  canonical (string-keyed, sorted) term encoding.

  This is the exact function `from_manifest/2` uses to mint `Surface.digest`,
  exposed so the digest is a *verifiable fact*: anything that receives a
  `%Surface{}` from outside the constructor (IR, episodes) recomputes it
  instead of trusting the claimed value.

  ## Examples

      iex> digest = AshSurface.contract_digest(%{"a" => 1})
      iex> {byte_size(digest), digest == AshSurface.contract_digest(%{a: 1})}
      {64, true}
  """
  @spec contract_digest(map()) :: String.t()
  def contract_digest(contract), do: digest(contract)

  @doc """
  Verifies that `surface.digest` is the content address of `surface.contract`.

  Returns `:ok` or `{:error, {:surface_digest_mismatch, claimed, actual}}`.

  ## Examples

      iex> {:ok, surface} = AshSurface.from_manifest(%Ash.Info.Manifest{entrypoints: []})
      iex> AshSurface.verify_surface_digest(surface)
      :ok

      iex> {:ok, surface} = AshSurface.from_manifest(%Ash.Info.Manifest{entrypoints: []})
      iex> forged = %{surface | digest: String.duplicate("a", 64)}
      iex> {:error, {:surface_digest_mismatch, claimed, actual}} = AshSurface.verify_surface_digest(forged)
      iex> {claimed, actual == surface.digest}
      {String.duplicate("a", 64), true}
  """
  @spec verify_surface_digest(Surface.t()) ::
          :ok | {:error, {:surface_digest_mismatch, term(), String.t()}}
  def verify_surface_digest(%Surface{contract: contract, digest: claimed}) do
    actual = contract_digest(contract)

    if claimed == actual,
      do: :ok,
      else: {:error, {:surface_digest_mismatch, claimed, actual}}
  end

  defp digest(contract), do: AshSurface.Digest.content_digest(contract)
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
