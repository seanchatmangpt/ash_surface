defmodule AshSurface.PersonalizationContext do
  @moduledoc """
  Subject-private personalization projection for human surfaces.

  The context distinguishes USER_STATED, OBSERVED, and INFERRED facets so a
  consumer can explain what personalization is based on without promoting an
  inference into user testimony. Raw profile ownership remains upstream.
  """

  @sources [:USER_STATED, :OBSERVED, :INFERRED]
  @standings [:UNKNOWN, :PARTIAL_ALIVE, :ALIVE, :BLOCKED, :REFUSED]

  @enforce_keys [:context_id, :exact_subject, :facets, :state_digest]

  defstruct [
    :context_id,
    :exact_subject,
    :state_digest,
    :consent_ref,
    facets: [],
    evidence_refs: [],
    standing: :PARTIAL_ALIVE,
    privacy_scope: :SUBJECT_PRIVATE,
    share_scope: :SUBJECT_ONLY,
    authority_boundary: :OBSERVE
  ]

  @type t :: %__MODULE__{}

  @spec create(String.t(), [map()], keyword()) :: t()
  def create(exact_subject, facets, opts \\ [])
      when is_binary(exact_subject) and is_list(facets) do
    normalized =
      facets
      |> Enum.map(&normalize_facet!/1)
      |> Enum.sort_by(& &1["facetId"])

    facet_ids = Enum.map(normalized, & &1["facetId"])

    if length(facet_ids) != length(Enum.uniq(facet_ids)),
      do: raise(ArgumentError, "personalization facet ids must be unique")

    standing = Keyword.get(opts, :standing, :PARTIAL_ALIVE)

    unless standing in @standings,
      do: raise(ArgumentError, "unknown standing: #{inspect(standing)}")

    evidence_refs = Keyword.get(opts, :evidence_refs, [])
    validate_string_list!(evidence_refs, :evidence_refs)

    consent_ref = Keyword.get(opts, :consent_ref)

    canonical = %{
      exact_subject: exact_subject,
      facets: normalized,
      consent_ref: consent_ref,
      evidence_refs: Enum.sort(evidence_refs),
      standing: standing,
      privacy_scope: :SUBJECT_PRIVATE,
      share_scope: :SUBJECT_ONLY
    }

    state_digest = digest({"ash_surface_personalization_context/1", canonical})

    %__MODULE__{
      context_id: "pc_" <> binary_part(state_digest, 0, 16),
      exact_subject: exact_subject,
      facets: normalized,
      consent_ref: consent_ref,
      evidence_refs: evidence_refs,
      standing: standing,
      state_digest: state_digest
    }
  end

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = value) do
    %{
      "contextId" => value.context_id,
      "exactSubject" => value.exact_subject,
      "facets" => value.facets,
      "consentRef" => value.consent_ref,
      "evidenceRefs" => value.evidence_refs,
      "standing" => Atom.to_string(value.standing),
      "privacyScope" => Atom.to_string(value.privacy_scope),
      "shareScope" => Atom.to_string(value.share_scope),
      "stateDigest" => value.state_digest,
      "authorityBoundary" => "OBSERVE",
      "doAuthority" => false
    }
  end

  defp normalize_facet!(facet) when is_map(facet) do
    dimension = fetch_string!(facet, :dimension)
    value_ref = fetch_string!(facet, :value_ref)
    source = normalize_atom!(fetch!(facet, :source), @sources, :source)

    standing =
      normalize_atom!(
        Map.get(facet, :standing) || Map.get(facet, "standing") || :UNKNOWN,
        @standings,
        :standing
      )

    evidence_refs = Map.get(facet, :evidence_refs) || Map.get(facet, "evidenceRefs") || []
    falsifier = Map.get(facet, :falsifier) || Map.get(facet, "falsifier")

    validate_string_list!(evidence_refs, :evidence_refs)

    if source == :INFERRED and not (is_binary(falsifier) and byte_size(falsifier) > 0),
      do: raise(ArgumentError, "INFERRED personalization facet requires a falsifier")

    identity_digest =
      digest({"ash_surface_personalization_facet/1", dimension, value_ref, source})

    %{
      "facetId" => "pf_" <> binary_part(identity_digest, 0, 16),
      "dimension" => dimension,
      "valueRef" => value_ref,
      "source" => Atom.to_string(source),
      "standing" => Atom.to_string(standing),
      "falsifier" => falsifier,
      "evidenceRefs" => Enum.sort(evidence_refs)
    }
  end

  defp normalize_facet!(_), do: raise(ArgumentError, "personalization facet must be a map")

  defp fetch_string!(map, key) do
    value = fetch!(map, key)

    unless is_binary(value) and byte_size(value) > 0,
      do: raise(ArgumentError, "#{key} must be a non-empty string")

    value
  end

  defp fetch!(map, key) do
    camel = key |> Atom.to_string() |> camelize()

    case Map.get(map, key) || Map.get(map, camel) do
      nil -> raise ArgumentError, "personalization facet missing #{key}"
      value -> value
    end
  end

  defp camelize(value) do
    [head | tail] = String.split(value, "_")
    head <> Enum.map_join(tail, "", &String.capitalize/1)
  end

  defp normalize_atom!(value, allowed, field) when is_atom(value) do
    if value in allowed,
      do: value,
      else: raise(ArgumentError, "unknown #{field}: #{inspect(value)}")
  end

  defp normalize_atom!(value, allowed, field) when is_binary(value) do
    normalized = value |> String.upcase() |> String.to_existing_atom()
    normalize_atom!(normalized, allowed, field)
  rescue
    ArgumentError -> raise ArgumentError, "unknown #{field}: #{inspect(value)}"
  end

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
