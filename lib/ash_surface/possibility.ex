defmodule AshSurface.Possibility do
  @moduledoc """
  One preserved human-facing option in a DfCM possibility frontier.

  A possibility is a projection of an upstream capability/action candidate.
  It does not select itself and never carries DO authority.
  """

  @statuses [:CANDIDATE, :PRESERVED, :BLOCKED, :REFUSED]
  @reversibility [:REVERSIBLE, :CONDITIONAL, :IRREVERSIBLE]
  @ceilings [:OBSERVE, :SELECT, :CONSTRUCT]

  @enforce_keys [
    :possibility_id,
    :exact_subject,
    :capability_id,
    :label,
    :status,
    :reversibility,
    :state_digest
  ]

  defstruct [
    :possibility_id,
    :exact_subject,
    :capability_id,
    :label,
    :summary,
    :action_ref,
    :why_this_ref,
    :status,
    :reversibility,
    :state_digest,
    :cost_summary,
    :consequence_summary,
    :expires_at,
    requirements: [],
    evidence_refs: [],
    authority_ceiling: :SELECT
  ]

  @type t :: %__MODULE__{}

  @spec create(String.t(), String.t(), String.t(), keyword()) :: t()
  def create(exact_subject, capability_id, label, opts \\ [])
      when is_binary(exact_subject) and is_binary(capability_id) and is_binary(label) do
    status = Keyword.get(opts, :status, :PRESERVED)
    reversibility = Keyword.get(opts, :reversibility, :REVERSIBLE)
    ceiling = Keyword.get(opts, :authority_ceiling, :SELECT)

    validate_member!(status, @statuses, :status)
    validate_member!(reversibility, @reversibility, :reversibility)
    validate_member!(ceiling, @ceilings, :authority_ceiling)

    requirements = Keyword.get(opts, :requirements, [])
    evidence_refs = Keyword.get(opts, :evidence_refs, [])
    validate_string_list!(requirements, :requirements)
    validate_string_list!(evidence_refs, :evidence_refs)

    action_ref = Keyword.get(opts, :action_ref)
    why_this_ref = Keyword.get(opts, :why_this_ref)

    identity_digest =
      digest({"ash_surface_possibility/1", exact_subject, capability_id, label, action_ref})

    canonical = %{
      status: status,
      reversibility: reversibility,
      authority_ceiling: ceiling,
      summary: Keyword.get(opts, :summary),
      why_this_ref: why_this_ref,
      cost_summary: Keyword.get(opts, :cost_summary),
      consequence_summary: Keyword.get(opts, :consequence_summary),
      requirements: Enum.sort(requirements),
      evidence_refs: Enum.sort(evidence_refs),
      expires_at: normalize_datetime(Keyword.get(opts, :expires_at))
    }

    state_digest = digest({"ash_surface_possibility_state/1", identity_digest, canonical})

    %__MODULE__{
      possibility_id: "pos_" <> binary_part(identity_digest, 0, 16),
      exact_subject: exact_subject,
      capability_id: capability_id,
      label: label,
      summary: canonical.summary,
      action_ref: action_ref,
      why_this_ref: why_this_ref,
      status: status,
      reversibility: reversibility,
      state_digest: state_digest,
      cost_summary: canonical.cost_summary,
      consequence_summary: canonical.consequence_summary,
      requirements: requirements,
      evidence_refs: evidence_refs,
      expires_at: Keyword.get(opts, :expires_at),
      authority_ceiling: ceiling
    }
  end

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = value) do
    %{
      "possibilityId" => value.possibility_id,
      "exactSubject" => value.exact_subject,
      "capabilityId" => value.capability_id,
      "label" => value.label,
      "summary" => value.summary,
      "actionRef" => value.action_ref,
      "whyThisRef" => value.why_this_ref,
      "status" => Atom.to_string(value.status),
      "reversibility" => Atom.to_string(value.reversibility),
      "stateDigest" => value.state_digest,
      "costSummary" => value.cost_summary,
      "consequenceSummary" => value.consequence_summary,
      "requirements" => value.requirements,
      "evidenceRefs" => value.evidence_refs,
      "expiresAt" => normalize_datetime(value.expires_at),
      "authorityCeiling" => Atom.to_string(value.authority_ceiling),
      "doAuthority" => false
    }
  end

  defp validate_member!(value, allowed, field) do
    unless value in allowed, do: raise(ArgumentError, "unknown #{field}: #{inspect(value)}")
  end

  defp validate_string_list!(values, field) when is_list(values) do
    unless Enum.all?(values, &is_binary/1),
      do: raise(ArgumentError, "#{field} must contain only strings")
  end

  defp validate_string_list!(_, field), do: raise(ArgumentError, "#{field} must be a list")

  defp normalize_datetime(nil), do: nil
  defp normalize_datetime(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp normalize_datetime(value) when is_binary(value), do: value

  defp digest(term) do
    term
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
