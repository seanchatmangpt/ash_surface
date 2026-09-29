defmodule AshSurface.Conformance.Runner do
  @moduledoc """
  The Elixir reference runner of the AshSurface conformance corpus.

  Each vector `kind` maps to ONE function that drives the REAL public
  implementation (`AshSurface.Transport`, `AshSurface.CanonicalJSON`,
  `AshSurface.from_manifest/2`, `AshSurface.IR.Codec`, `AshSurface.Event`,
  `AshSurface.Standing`, `AshSurface.Vocabulary`) with a vector's `input` and
  returns a JSON-shaped `expected`. The regeneration script writes those
  results as the corpus; the replay test re-runs them and compares, so any
  drift between corpus and implementation is RED.

  Nothing here computes a law itself. The only derived value is documented at
  `run("transport_outcome", _)` (there is no Elixir failure classifier yet).

  Error normalization (language-neutral): a typed refusal `{kind, detail...}`
  becomes `%{"kind" => "<kind>", "detail" => <json>}`. `kind` is normative;
  `detail` is diagnostic.
  """

  alias Ash.Info.Manifest
  alias Ash.Info.Manifest.{Action, Entrypoint}
  alias AshSurface.CanonicalJSON
  alias AshSurface.Event
  alias AshSurface.IR.Codec
  alias AshSurface.Standing
  alias AshSurface.Transport
  alias AshSurface.Vocabulary

  @corpus_version "1.0.0"

  def corpus_version, do: @corpus_version

  # -- JSON shaping -------------------------------------------------------------

  def jsonify(%DateTime{} = dt), do: DateTime.to_iso8601(dt)

  def jsonify(map) when is_map(map) and not is_struct(map),
    do: Map.new(map, fn {k, v} -> {to_string(k), jsonify(v)} end)

  def jsonify(list) when is_list(list), do: Enum.map(list, &jsonify/1)
  def jsonify(tuple) when is_tuple(tuple), do: tuple |> Tuple.to_list() |> jsonify()
  def jsonify(v) when is_nil(v) or is_boolean(v) or is_number(v) or is_binary(v), do: v
  def jsonify(v) when is_atom(v), do: Atom.to_string(v)

  def error(reason) do
    {kind, detail} =
      case reason do
        atom when is_atom(atom) -> {atom, nil}
        {kind, detail} when is_atom(kind) -> {kind, jsonify(detail)}
        tuple when is_tuple(tuple) -> {elem(tuple, 0), tuple |> Tuple.delete_at(0) |> jsonify()}
        other -> {:unclassified, jsonify(other)}
      end

    %{"error" => %{"kind" => Atom.to_string(kind), "detail" => detail}}
  end

  # -- dispatch -------------------------------------------------------------------

  @spec run(String.t(), map()) :: map()
  def run("transport_selection", input) do
    opts = [
      preferred: atom(input["preferred"]),
      action_id: input["actionId"],
      facts: get_in(input, ["profile", "transportFacts"]) || %{}
    ]

    case Transport.select(atoms(input["declared"]), atoms(input["available"]), opts) do
      {:ok, decision} -> %{"decision" => decision_json(decision)}
      {:error, reason} -> error(reason)
    end
  end

  def run("transport_facts_admission", %{"profile" => profile}) do
    case Transport.facts_from_profile(profile) do
      {:ok, facts} -> %{"facts" => jsonify(facts)}
      {:error, reason} -> error(reason)
    end
  end

  def run("canonical_json", %{"json" => text}) do
    canonical = text |> Jason.decode!() |> CanonicalJSON.encode()

    %{
      "canonical" => canonical,
      "sha256" => :crypto.hash(:sha256, canonical) |> Base.encode16(case: :lower)
    }
  end

  def run("surface_contract_digest", %{"contract" => contract} = input) do
    digest = Codec.digest(contract)

    case input["generation"] do
      nil ->
        %{"digest" => digest}

      generation ->
        {:ok, surface} = build_surface(generation)

        %{
          "digest" => surface.digest,
          "codecDigestAgrees" => digest == surface.digest,
          "contractMatchesGeneration" =>
            CanonicalJSON.encode(surface.contract) == CanonicalJSON.encode(contract)
        }
    end
  end

  def run("surface_contract_refusal", %{"generation" => generation}) do
    case build_surface(generation) do
      {:ok, surface} -> %{"unexpectedlyAdmitted" => surface.digest}
      {:error, reason} -> error(reason)
    end
  end

  def run("receipt_binding", %{"receipt" => receipt} = input) do
    case Event.from_receipt(receipt, input["irAction"]) do
      {:ok, %Event{} = event} ->
        %{
          "event" => %{
            "authorityBoundary" => Atom.to_string(event.authority_boundary),
            "eventId" => event.event_id,
            "eventType" => event.event_type,
            "occurredAt" => DateTime.to_iso8601(event.occurred_at),
            "payload" => jsonify(event.payload),
            "receiptRef" => event.receipt_ref,
            "sequence" => event.sequence,
            "stateDigest" => event.state_digest,
            "subjectRef" => event.subject_ref
          }
        }

      {:error, refusal} ->
        %{
          "refusal" => %{
            "authorityBoundary" => Atom.to_string(refusal.authority_boundary),
            "reason" => error(refusal.reason)["error"],
            "standing" => Atom.to_string(refusal.standing)
          }
        }
    end
  end

  def run("receipt_digest", %{"payloadJson" => text}) do
    %{"sha256" => text |> Jason.decode!() |> CanonicalJSON.sha256_hex()}
  end

  def run("refusal_vocabulary", %{"value" => value}) do
    standing = if is_binary(value), do: String.to_atom(value), else: value

    %{
      "refusalCode" => Vocabulary.refusal_code?(value),
      "standingValid" => Standing.valid?(standing),
      "standingRefused" => Standing.refused?(standing)
    }
  end

  def run("reconcile_status", %{"verdict" => verdict}) do
    admitted =
      is_map(verdict) and is_binary(verdict["status"]) and
        verdict["status"] in Vocabulary.reconcile_statuses()

    %{"admitted" => admitted}
  end

  def run("ir_codec", %{"map" => map}) do
    case Codec.from_map(map) do
      {:ok, ir} ->
        canonical = Codec.to_map(ir)

        %{
          "ok" => %{
            "canonicalMap" => jsonify(canonical),
            "digest" => ir.digest,
            "roundTripsInput" => jsonify(canonical) == map
          }
        }

      {:error, reason} ->
        error(reason)
    end
  end

  # Outcome classification. Elixir owns the pre-dispatch half of the law
  # (Decision.dispatch_state + Transport.fallback_allowed?/1, closed by
  # mark_dispatched/1). It has no failure classifier, so `failureOutcome` is
  # DERIVED here from that fence: once fallback is closed the only lawful
  # failure outcome is the last of Vocabulary.dispatch_outcomes()
  # (UNKNOWN_AFTER_DISPATCH); while it is open nothing was dispatched and
  # there is no dispatch outcome (nil). Reported as a gap in docs/CONFORMANCE.md.
  def run("transport_outcome", %{"phase" => phase} = input) do
    case Transport.select(atoms(input["declared"]), atoms(input["available"]),
           preferred: atom(input["preferred"]),
           action_id: input["actionId"]
         ) do
      {:error, reason} ->
        error(reason)

      {:ok, decision} ->
        decision =
          if phase == "post_dispatch", do: Transport.mark_dispatched(decision), else: decision

        fallback? = Transport.fallback_allowed?(decision)

        %{
          "dispatchState" => Atom.to_string(decision.dispatch_state),
          "fallbackAllowed" => fallback?,
          "failureOutcome" =>
            if(fallback?, do: nil, else: List.last(Vocabulary.dispatch_outcomes()))
        }
    end
  end

  defp decision_json(%Transport.Decision{} = d) do
    %{
      "actionId" => d.action_id,
      "available" => jsonify(d.available),
      "declared" => jsonify(d.declared),
      "dimensions" => Atom.to_string(d.dimensions),
      "dispatchState" => Atom.to_string(d.dispatch_state),
      "fallback" => Atom.to_string(d.fallback),
      "frontier" => jsonify(d.frontier),
      "preferred" => Atom.to_string(d.preferred),
      "reason" => Atom.to_string(d.reason),
      "selected" => Atom.to_string(d.selected)
    }
  end

  defp atom(nil), do: :http
  defp atom(name) when is_binary(name), do: String.to_atom(name)
  defp atoms(names) when is_list(names), do: Enum.map(names, &String.to_atom/1)
  defp atoms(other), do: other

  # -- surfaces from a language-neutral generation spec ---------------------------

  def build_surface(%{"entrypoints" => entrypoints} = generation) do
    manifest = %Manifest{
      entrypoints:
        Enum.map(entrypoints, fn %{"resource" => resource, "action" => action, "type" => type} ->
          %Entrypoint{
            resource: Module.concat([resource]),
            action:
              struct!(Action,
                name: String.to_atom(action),
                type: String.to_atom(type),
                custom: %{}
              )
          }
        end)
    }

    AshSurface.from_manifest(manifest, profile: Map.get(generation, "profile", %{}))
  end

  # -- replay ---------------------------------------------------------------------

  @doc "Replays one vector: `:ok` or `{:mismatch, expected, actual}` (canonical JSON strings)."
  def replay_vector(kind, %{"input" => input, "expected" => expected}) do
    actual = CanonicalJSON.encode(run(kind, input))
    want = CanonicalJSON.encode(expected)
    if actual == want, do: :ok, else: {:mismatch, want, actual}
  end

  @doc "Loads every `*.json` vector file of a corpus directory (sorted by name)."
  def load_files(dir) do
    dir
    |> Path.join("*.json")
    |> Path.wildcard()
    |> Enum.sort()
    |> Enum.map(fn path -> {Path.basename(path), path |> File.read!() |> Jason.decode!()} end)
  end
end
