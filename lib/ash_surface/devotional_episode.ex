defmodule AshSurface.DevotionalEpisode do
  @moduledoc """
  Ordered, continuous-play devotional projection.

  A devotional episode is a human-facing composition of already identified
  scripture/commentary/prayer segments. AshSurface owns the projection and
  playback intent, not the source text or media rights.
  """

  @statuses [:READY, :IN_PROGRESS, :COMPLETED, :BLOCKED]
  @segment_kinds [:SCRIPTURE, :COMMENTARY, :PRAYER, :REFLECTION, :MUSIC, :TRANSITION]

  @enforce_keys [:episode_id, :title, :segments, :status, :state_digest]

  defstruct [
    :episode_id,
    :title,
    :subtitle,
    :why_this_ref,
    :status,
    :duration_seconds,
    :completion_receipt_ref,
    :state_digest,
    segments: [],
    hypothesis_refs: [],
    source_refs: [],
    playback_policy: :STRAIGHT_THROUGH,
    continuous_play: true,
    authority_boundary: :OBSERVE,
    do_authority: false
  ]

  @type t :: %__MODULE__{}

  @spec create(String.t(), [map()], keyword()) :: t()
  def create(title, segments, opts \\ []) when is_binary(title) and is_list(segments) do
    normalized_segments =
      segments
      |> Enum.with_index()
      |> Enum.map(fn {segment, index} -> normalize_segment!(segment, index) end)

    status = Keyword.get(opts, :status, :READY)
    unless status in @statuses, do: raise(ArgumentError, "unknown status: #{inspect(status)}")

    completion_receipt_ref = Keyword.get(opts, :completion_receipt_ref)

    if status == :COMPLETED and not is_binary(completion_receipt_ref),
      do: raise(ArgumentError, "COMPLETED devotional requires completion_receipt_ref")

    hypothesis_refs = Keyword.get(opts, :hypothesis_refs, [])
    source_refs = Keyword.get(opts, :source_refs, [])
    validate_string_list!(hypothesis_refs, :hypothesis_refs)
    validate_string_list!(source_refs, :source_refs)

    duration_seconds =
      Keyword.get_lazy(opts, :duration_seconds, fn ->
        Enum.reduce(normalized_segments, 0, fn segment, total ->
          total + Map.get(segment, "durationSeconds", 0)
        end)
      end)

    unless is_integer(duration_seconds) and duration_seconds >= 0,
      do: raise(ArgumentError, "duration_seconds must be a non-negative integer")

    identity_digest =
      digest({"ash_surface_devotional_episode/1", title, Enum.map(normalized_segments, & &1["ref"])})

    canonical = %{
      subtitle: Keyword.get(opts, :subtitle),
      why_this_ref: Keyword.get(opts, :why_this_ref),
      status: status,
      duration_seconds: duration_seconds,
      completion_receipt_ref: completion_receipt_ref,
      segments: normalized_segments,
      hypothesis_refs: Enum.sort(hypothesis_refs),
      source_refs: Enum.sort(source_refs),
      playback_policy: :STRAIGHT_THROUGH,
      continuous_play: true
    }

    state_digest = digest({"ash_surface_devotional_episode_state/1", identity_digest, canonical})

    %__MODULE__{
      episode_id: "dev_" <> binary_part(identity_digest, 0, 16),
      title: title,
      subtitle: canonical.subtitle,
      why_this_ref: canonical.why_this_ref,
      status: status,
      duration_seconds: duration_seconds,
      completion_receipt_ref: completion_receipt_ref,
      state_digest: state_digest,
      segments: normalized_segments,
      hypothesis_refs: hypothesis_refs,
      source_refs: source_refs
    }
  end

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = value) do
    %{
      "episodeId" => value.episode_id,
      "title" => value.title,
      "subtitle" => value.subtitle,
      "whyThisRef" => value.why_this_ref,
      "status" => Atom.to_string(value.status),
      "durationSeconds" => value.duration_seconds,
      "completionReceiptRef" => value.completion_receipt_ref,
      "stateDigest" => value.state_digest,
      "segments" => value.segments,
      "hypothesisRefs" => value.hypothesis_refs,
      "sourceRefs" => value.source_refs,
      "playbackPolicy" => Atom.to_string(value.playback_policy),
      "continuousPlay" => true,
      "authorityBoundary" => "OBSERVE",
      "doAuthority" => false
    }
  end

  defp normalize_segment!(segment, index) when is_map(segment) do
    kind = Map.get(segment, :kind) || Map.get(segment, "kind")
    ref = Map.get(segment, :ref) || Map.get(segment, "ref")
    label = Map.get(segment, :label) || Map.get(segment, "label") || ref
    duration = Map.get(segment, :duration_seconds) || Map.get(segment, "durationSeconds") || 0
    audio_ref = Map.get(segment, :audio_ref) || Map.get(segment, "audioRef")

    normalized_kind =
      case kind do
        value when is_atom(value) -> value
        value when is_binary(value) ->
          value
          |> String.upcase()
          |> String.to_existing_atom()

        _ ->
          raise ArgumentError, "segment #{index} requires kind"
      end

    unless normalized_kind in @segment_kinds,
      do: raise(ArgumentError, "unknown devotional segment kind: #{inspect(normalized_kind)}")

    unless is_binary(ref) and byte_size(ref) > 0,
      do: raise(ArgumentError, "segment #{index} requires non-empty ref")

    unless is_integer(duration) and duration >= 0,
      do: raise(ArgumentError, "segment #{index} duration must be non-negative integer")

    %{
      "position" => index,
      "kind" => Atom.to_string(normalized_kind),
      "ref" => ref,
      "label" => label,
      "durationSeconds" => duration,
      "audioRef" => audio_ref
    }
  end

  defp normalize_segment!(_, index), do: raise(ArgumentError, "segment #{index} must be a map")

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
