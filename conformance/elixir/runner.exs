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
  alias AshSurface.Compiler.{
    CalculationSchema,
    ErrorSchema,
    FilterSchema,
    IdentitySchema,
    QuerySchema,
    RelationshipSchema,
    Schema,
    SelectionSchema,
    UnionSchema
  }

  alias AshSurface.IR.ErrorShape
  alias AshSurface.Event
  alias AshSurface.FieldName
  alias AshSurface.IR.Codec
  alias AshSurface.Standing
  alias AshSurface.Transport
  alias AshSurface.Vocabulary

  @corpus_version "2.0.0"

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

  def run("field_name_emission", %{"op" => "emit"} = input) do
    %{"key" => FieldName.compute(input["name"], fn_formatter(input["formatter"]))}
  end

  def run("field_name_emission", %{"op" => "collision"} = input) do
    f = fn_formatter(input["formatter"])
    entries = Enum.map(input["names"], &{&1, FieldName.compute(&1, f)})

    case AshSurface.Compiler.EmittedKeys.check(entries, "conformance") do
      :ok ->
        %{"ok" => true}

      {:error, {:emitted_key_collision, _container, key, names}} ->
        %{"error" => %{"kind" => "emitted_key_collision", "detail" => %{"key" => key, "names" => names}}}
    end
  end

  def run("field_name_emission", %{"op" => "inverse"} = input) do
    f = fn_formatter(input["formatter"])
    # Regen/replay-time atoms for the finite admitted set only; parse_input/4 itself never mints.
    admitted = Enum.map(input["admitted"], &String.to_atom/1)

    case FieldName.parse_input(input["client"], f, admitted) do
      {:ok, atom} -> %{"ok" => Atom.to_string(atom)}
      :error -> %{"error" => %{"kind" => "error", "detail" => nil}}
    end
  end

  def run("field_name_emission", %{"op" => "format_checked"} = input) do
    case FieldName.format_checked(input["name"], fn_formatter(input["formatter"])) do
      {:ok, key} -> %{"ok" => key}
      {:error, {:not_invertible, _field, key}} ->
        %{"error" => %{"kind" => "not_invertible", "detail" => %{"key" => key}}}
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

  # Constraint -> zod projection (lane L14). The input is the SAME discovery
  # shape `AshSurface.Compiler.Schema.build/2` consumes (single- or few-action
  # maps with constrained arguments); the expected records the section's real
  # zod projection (`IR.Boundary.zod`) plus its meta counts. Value-level
  # pass/fail and safeParse issue shapes are NOT minted here: the Elixir
  # implementation renders fragments but has no value evaluator — recorded
  # BLOCKED in docs/jira/v26.11.11/receipts/L14.md.
  def run("constraints", %{"actions" => _} = discovery) do
    case Schema.build(discovery) do
      {:ok, ir, meta} ->
        zod =
          Map.new(ir, fn {id, boundary} -> {id, boundary.zod} end)

        %{
          "zod" => zod,
          "actionCount" => meta.action_count,
          "argumentCount" => meta.argument_count
        }

      {:error, reason} ->
        error(reason)
    end
  end

  # -- schema-renderer kinds (lane w3-04) ---------------------------------------------
  #
  # Each kind drives ONE real renderer under AshSurface.Compiler.* and records the
  # rendered Zod expression(s) PLUS probe verdicts. Verdicts are minted by really
  # executing the rendered text under zod (conformance/js/zod_eval.mjs via node):
  # `probes` are authored inputs, `verdicts` are never typed by hand. A probe is
  # `{"value": v}` or `{"target": name, "value": v}` (target selects one expression
  # when the renderer returns a map).

  def run("filter_operators", %{"inputs" => inputs} = input) do
    opts = input |> Map.get("opts", %{}) |> keyword([:max_depth, :connectives])

    inputs
    |> FilterSchema.render_filter_schema(opts)
    |> zod_outcome(input)
  end

  def run("query_envelope", %{"render" => render} = input) do
    args = Map.get(input, "args", %{})

    case render do
      "sort" ->
        QuerySchema.render_sort_schema(args["fields"], array?: args["array?"] == true)

      "pagination" ->
        QuerySchema.render_pagination_schema(flags(args))

      "query_params" ->
        params =
          case flags(args) do
            %{pagination: %{} = pagination} = f -> %{f | pagination: flags(pagination)}
            f -> f
          end

        case QuerySchema.render_query_params(params) do
          {:ok, %{sort: sort, page: page}} -> {:ok, %{"sort" => sort, "page" => page}}
          other -> other
        end

      "offset_result" ->
        QuerySchema.render_offset_result_schema(args["record"])

      "keyset_result" ->
        QuerySchema.render_keyset_result_schema(args["record"])

      "page_result" ->
        QuerySchema.render_page_result_schema(args["record"], flags(args))

      "typed_input" ->
        parts = for {k, v} <- args["parts"], into: %{}, do: {String.to_existing_atom(k), v}
        required = Enum.map(args["required"] || [], &String.to_existing_atom/1)
        QuerySchema.render_typed_query_input_schema(parts, required: required)

      "get_input" ->
        QuerySchema.render_get_input_schema(Enum.map(args["keys"], &List.to_tuple/1))

      "get_result" ->
        QuerySchema.render_get_result_schema(args["record"], flags(args))
    end
    |> zod_outcome(input)
  end

  def run("selection_admission", %{"admitted" => admitted, "denied" => denied} = input) do
    opts =
      input
      |> Map.get("opts", %{})
      |> keyword([:relationships, :allowed_loads, :denied_loads, :calculations, :aggregates])
      |> Enum.map(fn
        {:aggregates, facts} -> {:aggregates, aggregate_facts(facts)}
        other -> other
      end)

    admitted |> SelectionSchema.render_selection_schema(denied, opts) |> zod_outcome(input)
  end

  def run("relationship_loads", %{"relationships" => relationships} = input) do
    opts = input |> Map.take(["max_depth"]) |> keyword([:max_depth])

    case RelationshipSchema.render_load_schema(relationships, opts) do
      {:ok, zod, _descriptors} -> zod_outcome({:ok, zod}, input)
      other -> zod_outcome(other, input)
    end
  end

  def run("calculation_envelope", %{"render" => render, "facts" => facts} = input) do
    case render do
      "calculation" -> CalculationSchema.render_calculation_schema(facts)
      "aggregates" -> facts |> aggregate_facts() |> CalculationSchema.render_aggregate_schemas()
      "results" -> CalculationSchema.render_calculation_result_schemas(facts)
    end
    |> zod_outcome(input)
  end

  def run("identity_get", %{"render" => render} = input) do
    case render do
      "get" -> IdentitySchema.render_get_schema(input["identities"], input["primary_key"])
      "tenant" -> IdentitySchema.render_tenant_schema(input["multitenancy"])
    end
    |> case do
      {:ok, nil} -> {:ok, %{}}
      other -> other
    end
    |> zod_outcome(input)
  end

  def run("error_envelope", %{"render" => render} = input) do
    opts = [formatter: String.to_atom(Map.get(input, "formatter", "camel_case"))]

    case render do
      "types" -> {:ok, %{"types" => ErrorShape.types(), "catchAll" => ErrorShape.catch_all()}}
      "normalize" -> {:ok, %{"normalized" => ErrorShape.normalize_type(input["type"])}}
      "union" -> {:ok, ErrorSchema.union(opts)}
      "variant" -> {:ok, ErrorSchema.variant(input["type"], opts)}
      "field_errors" -> {:ok, ErrorSchema.field_errors(input["fields"])}
      "carry" -> {:ok, ErrorSchema.carry(input["fields"], opts)}
    end
    |> zod_outcome(input)
  end

  def run("union_schema", %{"render" => render, "members" => members} = input) do
    opts =
      input
      |> Map.get("opts", %{})
      |> Map.new(fn
        {"storage", v} -> {:storage, String.to_atom(v)}
        {"discriminator", v} -> {:discriminator, v}
        {"max_depth", v} -> {:max_depth, v}
      end)
      |> Enum.to_list()

    case render do
      "members" -> UnionSchema.render_members_admitted(members, opts)
      "facts" -> UnionSchema.render_union_schema_admitted(members, opts)
    end
    |> zod_outcome(input)
  end

  # Transport wire law (lane w3-04). The Elixir side owns the dispatch fence
  # (Transport.select/mark_dispatched/fallback_allowed?), so every post-dispatch
  # fault (adapter throw, channel timeout, HTTP non-2xx/network failure) maps to
  # dispatched / fallback closed / UNKNOWN_AFTER_DISPATCH. The CSRF vector is minted
  # against the REAL Plug.CSRFProtection: the header it reads, that a request
  # carrying the session's token passes, and that a request without one is refused.
  def run("transport_wire", %{"fault" => "csrf_header"}) do
    candidates = ["csrf-token", "x-csrf-token", "x-xsrf-token"]

    %{
      "acceptedHeaders" => Enum.filter(candidates, &csrf_passes?(&1)),
      "missingRejected" => not csrf_passes?(nil)
    }
  end

  def run("transport_wire", %{"transport" => transport, "fault" => fault}) when is_binary(fault) do
    other = if transport == "http", do: "phoenix_channel", else: "http"
    declared = [transport, other]

    {:ok, decision} =
      Transport.select(atoms(declared), atoms(declared), preferred: String.to_atom(transport), action_id: "Conformance.Resource#act")

    decision = Transport.mark_dispatched(decision)
    fallback? = Transport.fallback_allowed?(decision)

    %{
      "dispatchState" => Atom.to_string(decision.dispatch_state),
      "fallbackAllowed" => fallback?,
      "failureOutcome" => if(fallback?, do: nil, else: List.last(Vocabulary.dispatch_outcomes()))
    }
  end

  # Real Plug.CSRFProtection over a POST whose session carries a minted state; the
  # request passes only when `header` carries the matching (masked) token.
  defp csrf_passes?(header) do
    token = Plug.CSRFProtection.get_csrf_token()
    state = Plug.CSRFProtection.dump_state()

    conn =
      Plug.Test.conn(:post, "/", %{})
      |> Plug.Test.init_test_session(%{"_csrf_token" => state})

    conn = if header, do: Plug.Conn.put_req_header(conn, header, token), else: conn

    try do
      Plug.CSRFProtection.call(conn, Plug.CSRFProtection.init([]))
      true
    rescue
      Plug.CSRFProtection.InvalidCSRFTokenError -> false
    after
      Process.delete(:plug_masked_csrf_token)
      Process.delete(:plug_unmasked_csrf_token)
    end
  end

  # -- renderer plumbing --------------------------------------------------------------

  defp keyword(map, allowed) do
    for key <- allowed, Map.has_key?(map, Atom.to_string(key)), do: {key, Map.fetch!(map, Atom.to_string(key))}
  end

  defp flags(args) do
    for {k, v} <- args, k not in ["fields", "array?", "record", "parts", "required", "keys"], into: %{} do
      {String.to_atom(k), v}
    end
  end

  defp aggregate_facts(facts) when is_list(facts) do
    Enum.map(facts, fn
      %{"kind" => kind} = fact when is_binary(kind) -> %{fact | "kind" => String.to_atom(kind)}
      fact -> fact
    end)
  end

  defp aggregate_facts(other), do: other

  defp zod_outcome({:error, reason}, _input), do: error(reason)

  defp zod_outcome({:ok, [{_, _} | _] = pairs}, input),
    do: zod_outcome({:ok, Map.new(pairs)}, input)

  defp zod_outcome({:ok, zod}, input) when is_map(zod) and not is_map_key(zod, "types") and
                                          not is_map_key(zod, "normalized") do
    zod_with_verdicts(zod, input)
  end

  defp zod_outcome({:ok, zod}, input) when is_binary(zod), do: zod_with_verdicts(zod, input)
  defp zod_outcome({:ok, data}, _input) when is_map(data), do: %{"ok" => data}
  defp zod_outcome(other, _input), do: error(other)

  defp zod_with_verdicts(zod, input) do
    probes = Map.get(input, "probes", [])

    cases =
      Enum.flat_map(probes, fn probe ->
        expression = if is_map(zod), do: zod[probe["target"]], else: zod
        if is_binary(expression), do: [%{"zod" => expression, "value" => probe["value"]}], else: []
      end)

    %{"ok" => %{"zod" => zod, "verdicts" => zod_verdicts(cases)}}
  end

  @zod_eval Path.expand("../js/zod_eval.mjs", __DIR__)

  @doc "Executes `[%{\"zod\", \"value\"}]` under real zod (node); returns safeParse booleans."
  def zod_verdicts([]), do: []

  def zod_verdicts(cases) do
    path = Path.join(System.tmp_dir!(), "ash_surface_zod_cases_#{System.unique_integer([:positive])}.json")
    File.write!(path, Jason.encode!(cases))

    try do
      {out, 0} = System.cmd("node", [@zod_eval, path], stderr_to_stdout: true)
      Jason.decode!(out)
    after
      File.rm(path)
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

  defp fn_formatter("camel_case"), do: :camel_case
  defp fn_formatter("snake_case"), do: :snake_case
  defp fn_formatter("pascal_case"), do: :pascal_case

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
