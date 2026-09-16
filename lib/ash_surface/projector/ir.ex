defmodule AshSurface.Projector.IR do
  @moduledoc """
  IR-era projector behaviour and the adapter that carries existing
  `AshSurface.Projector` modules into it unchanged.

  ## Canonical IR shape (declared locally)

  No upstream IR owner exists yet, so this module is the declaration point for
  the canonical node shape. An IR is a plain map with a `:kind` namespace and
  an Ash fact section under `:ash`:

      %{
        kind: "ash_surface.surface",
        ash: %{
          manifest: %Ash.Info.Manifest{},
          contract: map(),
          digest: String.t(),
          action_ids: [String.t()]
        }
      }

  `ash_surface.surface` nodes carry exactly the four facts of a verified
  `AshSurface.Surface`. Re-extraction is fact assembly, never re-derivation:
  Ash ships no manifest deserializer and none is invented here, so a legacy
  projector wrapped by this adapter observes the identical surface it would
  have received before the IR era.
  """

  @surface_ir_kind "ash_surface.surface"

  @typedoc "Ash fact section of an `#{@surface_ir_kind}` IR node."
  @type surface_facts :: %{
          required(:manifest) => Ash.Info.Manifest.t(),
          required(:contract) => map(),
          required(:digest) => String.t(),
          required(:action_ids) => [String.t()]
        }

  @type ir :: %{
          required(:kind) => String.t(),
          required(:ash) => term(),
          optional(atom()) => term()
        }

  @doc """
  Projects IR into a consumer artifact.

  `irs` is a single IR node or a list of IR nodes. Implementations refuse
  unknown node kinds with typed errors instead of silently pruning them.
  """
  @callback project_ir(irs :: ir() | [ir()], opts :: keyword()) ::
              {:ok, term(), map()} | {:error, term()}

  defmodule ManifestProjector do
    @moduledoc """
    Adapter that runs an existing `AshSurface.Projector`-behaviour module over IR.

    Manifest facts are re-extracted from the `ash` section of the surface IR
    and the wrapped projector's `project/2` is invoked with them, unchanged.
    Dispatch through `AshSurface.Projector.IR.project/3`.
    """

    defstruct [:projector]

    @type t :: %__MODULE__{projector: module()}

    @doc """
    Re-extracts the surface from `irs` and delegates to the wrapped legacy
    projector, passing `opts` through untouched.
    """
    @spec project_ir(
            t(),
            AshSurface.Projector.IR.ir() | [AshSurface.Projector.IR.ir()],
            keyword()
          ) ::
            {:ok, term(), map()} | {:error, term()}
    def project_ir(%__MODULE__{projector: projector}, irs, opts) do
      with {:ok, surface} <- AshSurface.Projector.IR.to_surface(irs) do
        projector.project(surface, opts)
      end
    end
  end

  alias __MODULE__.ManifestProjector

  @doc """
  Wraps an existing `AshSurface.Projector`-behaviour module for IR-era
  projection.

  Anything that is not a module exporting `project/2` is refused with a typed
  `{:unknown_projector_kind, _}` error — a projector module that exists but
  implements no legacy behaviour is an unknown kind, not a silent no-op.
  """
  @spec from_manifest_projector(term()) ::
          {:ok, ManifestProjector.t()} | {:error, {:unknown_projector_kind, term()}}
  def from_manifest_projector(projector) when is_atom(projector) do
    Code.ensure_loaded(projector)

    if function_exported?(projector, :project, 2) do
      {:ok, %ManifestProjector{projector: projector}}
    else
      {:error, {:unknown_projector_kind, projector}}
    end
  end

  def from_manifest_projector(other), do: {:error, {:unknown_projector_kind, other}}

  @doc "Builds the canonical `#{@surface_ir_kind}` IR from a verified surface."
  @spec from_surface(AshSurface.Surface.t()) :: {:ok, ir()}
  def from_surface(%AshSurface.Surface{} = surface) do
    {:ok,
     %{
       kind: @surface_ir_kind,
       ash: %{
         manifest: surface.manifest,
         contract: surface.contract,
         digest: surface.digest,
         action_ids: surface.action_ids
       }
     }}
  end

  @doc """
  Re-extracts a verified `AshSurface.Surface` from IR.

  Accepts a single IR node or a list. Exactly one `#{@surface_ir_kind}` node
  with complete `ash` facts is admissible — the legacy projection unit is one
  surface. Zero nodes, duplicate nodes, foreign kinds, or incomplete facts are
  refused with typed errors instead of silently pruned. A mixed collection —
  one surface node beside foreign nodes — is refused as a whole with
  `{:foreign_ir, foreign_nodes}`; the foreign remainder is never silently
  discarded on success.
  """
  @spec to_surface(ir() | [ir()]) :: {:ok, AshSurface.Surface.t()} | {:error, term()}
  def to_surface(irs) when is_list(irs) do
    with :ok <- validate_ir_elements(irs) do
      irs
      |> Enum.split_with(&surface_ir?/1)
      |> surface_from_split()
    end
  end

  def to_surface(%{} = ir), do: to_surface([ir])
  def to_surface(other), do: {:error, {:invalid_irs, other}}

  @doc """
  IR-era dispatch entry point.

  Accepts an adapter from `from_manifest_projector/1` or any module
  implementing the `project_ir/2` callback. Anything else is refused with a
  typed `{:unknown_projector_kind, _}` error.
  """
  @spec project(ManifestProjector.t() | module(), ir() | [ir()], keyword()) ::
          {:ok, term(), map()} | {:error, term()}
  def project(%ManifestProjector{} = adapter, irs, opts),
    do: ManifestProjector.project_ir(adapter, irs, opts)

  def project(projector, irs, opts) when is_atom(projector) do
    Code.ensure_loaded(projector)

    if function_exported?(projector, :project_ir, 2) do
      projector.project_ir(irs, opts)
    else
      {:error, {:unknown_projector_kind, projector}}
    end
  end

  def project(other, _irs, _opts), do: {:error, {:unknown_projector_kind, other}}

  defp validate_ir_elements(irs) do
    case Enum.find(irs, &(not is_map(&1))) do
      nil -> :ok
      element -> {:error, {:invalid_ir, element}}
    end
  end

  defp surface_ir?(%{kind: @surface_ir_kind}), do: true
  defp surface_ir?(_), do: false

  defp surface_from_split({[%{ash: ash} = _ir], []}) when is_map(ash) do
    case ash do
      %{
        manifest: %Ash.Info.Manifest{} = manifest,
        contract: contract,
        digest: digest,
        action_ids: action_ids
      }
      when is_map(contract) and is_binary(digest) and is_list(action_ids) ->
        {:ok,
         %AshSurface.Surface{
           manifest: manifest,
           contract: contract,
           digest: digest,
           action_ids: action_ids
         }}

      _ ->
        {:error, {:invalid_surface_facts, Map.keys(ash) |> Enum.sort()}}
    end
  end

  defp surface_from_split({[%{} = _ir], []}),
    do: {:error, {:invalid_surface_facts, []}}

  defp surface_from_split({[_ir], foreign_irs}),
    do: {:error, {:foreign_ir, foreign_irs}}

  defp surface_from_split({[], rest}),
    do: {:error, {:missing_surface_ir, length(rest)}}

  defp surface_from_split({surface_irs, _rest}),
    do: {:error, {:duplicate_surface_irs, length(surface_irs)}}
end
