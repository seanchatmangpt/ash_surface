# Tokyo-Depeg burn-in dashboard surface manifest (plan W7).
#
# This is the authored surface manifest for the burn-in observatory: it
# declares the four read-only dashboard sections as real Ash resources with
# public read actions, and the per-action surface profile (delegated facts,
# evidence requirement, REFUSED_* stream) consumed by `AshSurface.from_manifest/2`.
# The UI is projected by ash_surface's own compilers/projectors — no hand-built
# UI code anywhere in this file.
#
# Consumed by test/tokyo_depeg_surface_test.exs via Code.require_file/2.
#
# Read-only observatory law: every action is a public `:read`; the delegated
# `authorityBoundary` is "OBSERVE" and `doAuthority` is false on every action,
# so the client can never mint a DO (the JS projector refuses dispatch intents
# for non-DO boundaries and the runtime carries doAuthority false).

defmodule Tdb.BurnIn.Resources do
  @moduledoc """
  Real Ash resources backing the burn-in dashboard sections. One resource per
  section, one public read action each, backed by the ETS data layer so the
  suite stays state-based with real collaborators (no DB, no mocks).
  """

  defmodule BurnCycleStatus do
    @moduledoc "tdb:BurnCycleStatus — burn-cycle status section."
    use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Ets

    attributes do
      uuid_primary_key(:id)
      attribute(:cycle, :integer, public?: true, allow_nil?: false)
      attribute(:concurrency, :integer, public?: true, allow_nil?: false)
      attribute(:verdict, :string, public?: true, allow_nil?: true)
    end

    actions do
      read :read do
        argument :cycle, :integer, allow_nil?: true, public?: true
      end
    end
  end

  defmodule StageVerdicts do
    @moduledoc "tdb:StageVerdicts — per-stage verdicts section (6 burn stages)."
    use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Ets

    attributes do
      uuid_primary_key(:id)
      attribute(:stage, :string, public?: true, allow_nil?: false)
      attribute(:verdict, :string, public?: true, allow_nil?: false)
    end

    actions do
      read :read do
        argument :cycle, :integer, allow_nil?: true, public?: true
      end
    end
  end

  defmodule RefusalLedger do
    @moduledoc """
    tdb:RefusalLedger — the live REFUSED_* stream section. The possibleRefusals
    profile below carries the plan's five refusal classes verbatim.
    """
    use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Ets

    attributes do
      uuid_primary_key(:id)
      attribute(:refusal_code, :string, public?: true, allow_nil?: false)
      attribute(:subject, :string, public?: true, allow_nil?: false)
      attribute(:emitted_at, :utc_datetime, public?: true, allow_nil?: false)
    end

    actions do
      read :read do
        argument :since, :string, allow_nil?: true, public?: true
      end
    end
  end

  defmodule AlignmentCosts do
    @moduledoc "tdb:AlignmentCosts — OCEL alignment-cost section (Van der Aalst core)."
    use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Ets

    attributes do
      uuid_primary_key(:id)
      attribute(:trace, :string, public?: true, allow_nil?: false)
      attribute(:cost, :decimal, public?: true, allow_nil?: false)
    end

    actions do
      read :read do
        argument :trace, :string, allow_nil?: true, public?: true
      end
    end
  end
end

defmodule Tdb.BurnIn.SurfaceManifest do
  @moduledoc """
  The authored manifest + profile consumed by `AshSurface.from_manifest/2`.

  `manifest/0` builds a real `Ash.Info.Manifest` over the four section
  resources; `profile/0` carries the projection metadata: delegated facts
  (semanticId, authorityBoundary "OBSERVE", doAuthority false, receiptRequired)
  plus `evidenceRequired` and the REFUSED_* stream each section admits.
  """

  alias Tdb.BurnIn.Resources

  @sections [
    {:burn_cycle_status, Resources.BurnCycleStatus, "tdb:BurnCycleStatus",
     ["REFUSED_BURN_CYCLE_BOUNDS"]},
    {:stage_verdicts, Resources.StageVerdicts, "tdb:StageVerdicts",
     ["REFUSED_STAGE_UNKNOWN"]},
    {:refusal_ledger, Resources.RefusalLedger, "tdb:RefusalLedger",
     [
       "REFUSED_CONFORMANCE_DEVIATION",
       "REFUSED_AUTHORITY_REVOKED",
       "REFUSED_LEASE_EXPIRED",
       "REFUSED_DUPLICATE_EFFECT",
       "REFUSED_LEDGER_TAMPER"
     ]},
    {:alignment_costs, Resources.AlignmentCosts, "tdb:AlignmentCosts",
     ["REFUSED_ALIGNMENT_SPEC_UNKNOWN"]}
  ]

  @doc "The four dashboard section descriptors (key, resource, semanticId, refusals)."
  def sections, do: @sections

  @doc "The stable surface action ids (`Resource#action`), sorted."
  def action_ids do
    Enum.map(sections(), fn {_key, resource, _iri, _refusals} ->
      "#{inspect(resource)}#read"
    end)
    |> Enum.sort()
  end

  @doc "Builds the real manifest over the four section resources."
  def manifest do
    entrypoints =
      Enum.map(sections(), fn {_key, resource, _iri, _refusals} ->
        {:ok, action} = fetch_action(resource)
        %Ash.Info.Manifest.Entrypoint{resource: resource, action: action}
      end)

    %Ash.Info.Manifest{entrypoints: entrypoints}
  end

  # Projects the real compiled action into its manifest fact shape — the same
  # projection `Ash.Info.Manifest.Generator` performs, kept local so this file
  # needs no generator run. Inputs come from the action's public arguments
  # verbatim (name, resolved short-name kind, allow_nil?, has_default?).
  defp fetch_action(resource) do
    case Enum.find(Ash.Resource.Info.public_actions(resource), &(&1.name == :read)) do
      nil ->
        {:error, {:unknown_public_action, resource}}

      act ->
        {:ok,
         %Ash.Info.Manifest.Action{
           name: act.name,
           type: act.type,
           primary?: primary_action?(resource, act),
           inputs: Enum.map(act.arguments, &manifest_argument/1),
           metadata: [],
           custom: %{}
         }}
    end
  end

  defp primary_action?(resource, act) do
    case Ash.Resource.Info.primary_action(resource, act.type) do
      nil -> false
      primary -> primary.name == act.name
    end
  end

  defp manifest_argument(argument) do
    %Ash.Info.Manifest.Argument{
      name: argument.name,
      type: %Ash.Info.Manifest.Type{kind: argument.type},
      allow_nil?: argument.allow_nil?,
      has_default?: not is_nil(argument.default),
      required?: not argument.allow_nil?,
      custom: %{}
    }
  end

  @doc """
  The per-action surface profile: delegated facts + evidence + REFUSED_* stream.
  Keys are the exact `AshSurface.action_id/1` values.
  """
  def profile do
    actions =
      Map.new(sections(), fn {_key, resource, iri, refusals} ->
        id = "#{inspect(resource)}#read"

        {id,
         %{
           "semanticId" => iri,
           "authorityBoundary" => "OBSERVE",
           "doAuthority" => false,
           "receiptRequired" => true,
           "evidenceRequired" => true,
           "possibleRefusals" => refusals
         }}
      end)

    %{"actions" => actions}
  end
end
