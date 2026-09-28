defmodule AshSurface.Projector.IR do
  @moduledoc """
  The single projector contract: every projector (JavaScript, ARIA, LiveView,
  Expo, VoiceKiosk) declares `@behaviour AshSurface.Projector.IR` and
  implements `project_ir/2`.

  ## The contract

      project_ir(input, opts) :: {:ok, artifacts, meta} | {:error, reason}

  `input` is a single IR value or a list (see `t:input/0`): either
  `%AshSurface.IR{}` per-action structs, or `#{"ash_surface.surface"}` node
  maps carrying a whole verified surface. A projector admits the input kinds it
  understands and refuses every other kind with a typed error; it never prunes
  silently. Surface-consuming projectors (Expo, VoiceKiosk) recover the
  surface with `to_surface/1`, which re-verifies the content-addressed digest
  at the boundary. `AshSurface.project/3` is the public facade over a
  `%AshSurface.Surface{}`: it wraps the surface with `from_surface/1` and
  dispatches through `project/3` here. There is no second projector behaviour.

  ## Canonical IR shape (declared locally)

  [Corrected by gapfix-docs-truth-013: "no upstream IR owner exists yet" is
  superseded — `lib/ash_surface/ir.ex` (`AshSurface.IR`, five-section struct
  carrier) is admitted. This module remains the declaration point for the
  *node-map* shape below: a `:kind`-tagged plain map is a different,
  documented subject from the `%AshSurface.IR{}` struct, so the declaration
  stays here rather than moving.] An IR node is a plain map with a `:kind`
  namespace and an Ash fact section under `:ash`:

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

  @typedoc "Anything a projector may be handed: node maps and/or per-action IR structs."
  @type input :: ir() | AshSurface.IR.t() | [ir() | AshSurface.IR.t()]

  @doc """
  Projects IR into consumer artifacts.

  `irs` is a single IR value or a list. Implementations refuse input kinds
  they do not admit with typed errors instead of silently pruning them.
  Returns `{:ok, artifacts, meta}`; `artifacts` is projector-specific (a
  filename-to-source map for the code projectors, a contract map for ARIA and
  LiveView).
  """
  @callback project_ir(irs :: input(), opts :: keyword()) ::
              {:ok, artifacts :: term(), meta :: map()} | {:error, term()}

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
  discarded on success. The claimed `digest` must equal the recomputed
  content address of the IR's `contract` (`AshSurface.contract_digest/1`),
  otherwise `{:error, {:surface_digest_mismatch, claimed, actual}}`.
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
  Dispatch entry point: runs any module implementing the `project_ir/2`
  callback over `irs`.

  Anything that is not a module exporting `project_ir/2` is refused with a
  typed `{:unknown_projector_kind, _}` error.
  """
  @spec project(module(), input(), keyword()) :: {:ok, term(), map()} | {:error, term()}
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
        surface = %AshSurface.Surface{
          manifest: manifest,
          contract: contract,
          digest: digest,
          action_ids: action_ids
        }

        # Trust boundary: the digest is a verified fact, not a claim. IR is
        # data that crossed a boundary; recompute the content address.
        with :ok <- AshSurface.verify_surface_digest(surface), do: {:ok, surface}

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
