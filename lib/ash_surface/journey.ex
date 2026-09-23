defmodule AshSurface.Journey do
  @moduledoc """
  Human-readable replay projection over observed events, evidence, and receipts.

  Journey entries do not manufacture outcomes. They point to exact event,
  receipt, and evidence identities that support the visible history.
  """

  @standings [:UNKNOWN, :PARTIAL_ALIVE, :ALIVE, :BLOCKED, :REFUSED]
  @kinds [:PRACTICE, :SERVICE, :ATTENDANCE, :COMMITMENT, :REFLECTION, :OUTCOME, :RECEIPT]

  @enforce_keys [:journey_id, :exact_subject, :entries, :state_digest]

  defstruct [
    :journey_id,
    :exact_subject,
    :state_digest,
    entries: [],
    evidence_refs: [],
    receipt_refs: [],
    privacy_scope: :SUBJECT_PRIVATE,
    standing: :PARTIAL_ALIVE,
    authority_boundary: :OBSERVE
  ]

  @type t :: %__MODULE__{}

  @spec create(String.t(), [map()], keyword()) :: t()
  def create(exact_subject, entries, opts \\ [])
      when is_binary(exact_subject) and is_list(entries) do
    normalized =
      entries
      |> Enum.map(&normalize_entry!/1)
      |> Enum.sort_by(fn entry -> {entry["occurredAt"], entry["entryId"]} end)

    ids = Enum.map(normalized, & &1["entryId"])

    if length(ids) != length(Enum.uniq(ids)),
      do: raise(ArgumentError, "journey entry ids must be unique")

    standing = Keyword.get(opts, :standing, :PARTIAL_ALIVE)

    unless standing in @standings,
      do: raise(ArgumentError, "unknown standing: #{inspect(standing)}")

    evidence_refs = Keyword.get(opts, :evidence_refs, [])
    receipt_refs = Keyword.get(opts, :receipt_refs, [])
    validate_string_list!(evidence_refs, :evidence_refs)
    validate_string_list!(receipt_refs, :receipt_refs)

    canonical = %{
      exact_subject: exact_subject,
      entries: normalized,
      evidence_refs: Enum.sort(evidence_refs),
      receipt_refs: Enum.sort(receipt_refs),
      privacy_scope: :SUBJECT_PRIVATE,
      standing: standing
    }

    state_digest = digest({"ash_surface_journey/1", canonical})

    %__MODULE__{
      journey_id: "journey_" <> binary_part(state_digest, 0, 16),
      exact_subject: exact_subject,
      entries: normalized,
      evidence_refs: evidence_refs,
      receipt_refs: receipt_refs,
      standing: standing,
      state_digest: state_digest
    }
  end

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = value) do
    %{
      "journeyId" => value.journey_id,
      "exactSubject" => value.exact_subject,
      "entries" => value.entries,
      "evidenceRefs" => value.evidence_refs,
      "receiptRefs" => value.receipt_refs,
      "privacyScope" => Atom.to_string(value.privacy_scope),
      "standing" => Atom.to_string(value.standing),
      "stateDigest" => value.state_digest,
      "authorityBoundary" => "OBSERVE",
      "doAuthority" => false
    }
  end

  defp normalize_entry!(entry) when is_map(entry) do
    kind = fetch(entry, :kind)
    subject_ref = fetch(entry, :subject_ref)
    label = fetch(entry, :label)
    occurred_at = fetch(entry, :occurred_at)
    receipt_ref = Map.get(entry, :receipt_ref) || Map.get(entry, "receiptRef")
    evidence_refs = Map.get(entry, :evidence_refs) || Map.get(entry, "evidenceRefs") || []
    standing = Map.get(entry, :standing) || Map.get(entry, "standing") || :ALIVE

    kind = normalize_atom(kind)
    standing = normalize_atom(standing)

    unless kind in @kinds, do: raise(ArgumentError, "unknown journey kind: #{inspect(kind)}")

    unless standing in @standings,
      do: raise(ArgumentError, "unknown journey standing: #{inspect(standing)}")

    validate_string_list!(evidence_refs, :evidence_refs)

    occurred_at = normalize_datetime(occurred_at)

    identity_digest =
      digest({"ash_surface_journey_entry/1", kind, subject_ref, label, occurred_at, receipt_ref})

    %{
      "entryId" => "je_" <> binary_part(identity_digest, 0, 16),
      "kind" => Atom.to_string(kind),
      "subjectRef" => subject_ref,
      "label" => label,
      "occurredAt" => occurred_at,
      "receiptRef" => receipt_ref,
      "evidenceRefs" => evidence_refs,
      "standing" => Atom.to_string(standing)
    }
  end

  defp normalize_entry!(_), do: raise(ArgumentError, "journey entry must be a map")

  defp fetch(map, key) do
    camel = key |> Atom.to_string() |> camelize()

    Map.get(map, key) || Map.get(map, camel) ||
      raise(ArgumentError, "journey entry missing #{key}")
  end

  defp camelize(value) do
    [head | tail] = String.split(value, "_")
    head <> Enum.map_join(tail, "", &String.capitalize/1)
  end

  defp normalize_atom(value) when is_atom(value), do: value

  defp normalize_atom(value) when is_binary(value) do
    value
    |> String.upcase()
    |> String.to_existing_atom()
  end

  defp normalize_datetime(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp normalize_datetime(value) when is_binary(value), do: value

  defp validate_string_list!(values, field) when is_list(values) do
    unless Enum.all?(values, &is_binary/1),
      do: raise(ArgumentError, "#{field} must contain only strings")
  end

  defp validate_string_list!(_, field), do: raise(ArgumentError, "#{field} must be a list")

  defp digest(term) do
    term
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
