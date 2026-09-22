defmodule AshSurface.ManufactureTrace do
  @moduledoc """
  OBSERVE-only projection of the Chatman equation A = mu(O*).

  O* is represented as the explicit intersection of observed, admitted,
  grounded, bounded, and aligned evidence references. The trace explains how an
  upstream manufacturer produced an artifact; it does not perform manufacture
  or grant authority.
  """

  @standings [:UNKNOWN, :PARTIAL_ALIVE, :ALIVE, :BLOCKED, :REFUSED]

  @enforce_keys [
    :trace_id,
    :exact_subject,
    :artifact_ref,
    :manufacturer_identity,
    :o_star_refs,
    :state_digest
  ]

  defstruct [
    :trace_id,
    :exact_subject,
    :artifact_ref,
    :manufacturer_identity,
    :human_summary,
    :state_digest,
    observed_refs: [],
    admitted_refs: [],
    grounded_refs: [],
    bounded_refs: [],
    aligned_refs: [],
    o_star_refs: [],
    receipt_refs: [],
    falsifiers: [],
    standing: :PARTIAL_ALIVE,
    authority_boundary: :OBSERVE,
    do_authority: false
  ]

  @type t :: %__MODULE__{}

  @spec create(String.t(), String.t(), String.t(), keyword()) :: t()
  def create(exact_subject, artifact_ref, manufacturer_identity, opts \\ [])
      when is_binary(exact_subject) and is_binary(artifact_ref) and is_binary(manufacturer_identity) do
    observed = Keyword.get(opts, :observed_refs, [])
    admitted = Keyword.get(opts, :admitted_refs, [])
    grounded = Keyword.get(opts, :grounded_refs, [])
    bounded = Keyword.get(opts, :bounded_refs, [])
    aligned = Keyword.get(opts, :aligned_refs, [])
    o_star = Keyword.get(opts, :o_star_refs, [])
    receipts = Keyword.get(opts, :receipt_refs, [])
    falsifiers = Keyword.get(opts, :falsifiers, [])
    standing = Keyword.get(opts, :standing, :PARTIAL_ALIVE)

    Enum.each(
      [
        observed_refs: observed,
        admitted_refs: admitted,
        grounded_refs: grounded,
        bounded_refs: bounded,
        aligned_refs: aligned,
        o_star_refs: o_star,
        receipt_refs: receipts,
        falsifiers: falsifiers
      ],
      fn {field, values} -> validate_string_list!(values, field) end
    )

    unless standing in @standings,
      do: raise(ArgumentError, "unknown standing: #{inspect(standing)}")

    source_sets = [observed, admitted, grounded, bounded, aligned]

    unless Enum.all?(o_star, fn ref -> Enum.all?(source_sets, &(ref in &1)) end) do
      raise ArgumentError,
            "every O* reference must be observed, admitted, grounded, bounded, and aligned"
    end

    if standing == :ALIVE and receipts == [],
      do: raise(ArgumentError, "ALIVE manufacture trace requires at least one receipt reference")

    canonical = %{
      exact_subject: exact_subject,
      artifact_ref: artifact_ref,
      manufacturer_identity: manufacturer_identity,
      human_summary: Keyword.get(opts, :human_summary),
      observed_refs: Enum.sort(observed),
      admitted_refs: Enum.sort(admitted),
      grounded_refs: Enum.sort(grounded),
      bounded_refs: Enum.sort(bounded),
      aligned_refs: Enum.sort(aligned),
      o_star_refs: Enum.sort(o_star),
      receipt_refs: Enum.sort(receipts),
      falsifiers: Enum.sort(falsifiers),
      standing: standing
    }

    state_digest = digest({"ash_surface_manufacture_trace/1", canonical})

    %__MODULE__{
      trace_id: "mt_" <> binary_part(state_digest, 0, 16),
      exact_subject: exact_subject,
      artifact_ref: artifact_ref,
      manufacturer_identity: manufacturer_identity,
      human_summary: canonical.human_summary,
      observed_refs: observed,
      admitted_refs: admitted,
      grounded_refs: grounded,
      bounded_refs: bounded,
      aligned_refs: aligned,
      o_star_refs: o_star,
      receipt_refs: receipts,
      falsifiers: falsifiers,
      standing: standing,
      state_digest: state_digest
    }
  end

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = value) do
    %{
      "traceId" => value.trace_id,
      "exactSubject" => value.exact_subject,
      "artifactRef" => value.artifact_ref,
      "manufacturerIdentity" => value.manufacturer_identity,
      "humanSummary" => value.human_summary,
      "observedRefs" => value.observed_refs,
      "admittedRefs" => value.admitted_refs,
      "groundedRefs" => value.grounded_refs,
      "boundedRefs" => value.bounded_refs,
      "alignedRefs" => value.aligned_refs,
      "oStarRefs" => value.o_star_refs,
      "receiptRefs" => value.receipt_refs,
      "falsifiers" => value.falsifiers,
      "standing" => Atom.to_string(value.standing),
      "stateDigest" => value.state_digest,
      "equation" => "A=mu(O*)",
      "authorityBoundary" => "OBSERVE",
      "doAuthority" => false
    }
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
