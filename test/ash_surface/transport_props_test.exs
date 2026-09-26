defmodule AshSurface.TransportPropsTest do
  @moduledoc """
  Property-based selection laws over the real `AshSurface.Transport.select/3`
  (chicago-props-transport-043, Chicago school).

  Generated fact profiles (contract `transportFacts` shapes, atom and binary
  keys, normalized through the real `facts_from_profile/1`) and generated
  transport sets exercise three laws:

    1. Membership: a selected transport is always in declared ∩ available, on
       a nonempty frontier that is exactly a declared-order subsequence of
       that intersection; the only lawful refusal under well-formed inputs is
       total unavailability.
    2. Preference: an available preference wins iff it is non-dominated
       (checked against an independent dominance oracle in this module); a
       dominated preference yields to the weighed frontier, and the
       undelegated fold stays in declared order.
    3. Typed refusal: every malformed shape returns `{:error, reason}` with an
       atom or atom-tagged tuple — never a raise, never `nil`, never
       `{:ok, _}`.

  No test doubles: the unit under test is the real pure module, and no seam
  injection is demanded by any of the three laws. All assertions are on
  observable outcomes — returned decisions and typed refusals — never on
  internals.

  Shrinking is proven in the ticket History: an executed falsifier (a
  one-token mutation of the subject's fold) whose RED run reports a shrunk
  counterexample, then restored to GREEN.
  """

  use ExUnit.Case, async: true
  use ExUnitProperties

  alias AshSurface.Transport

  @known_transports [:http, :phoenix_channel]
  @dimensions [:cost, :latency, :privacy]
  @dimension_classes [:low, :medium, :high]

  # -- generators -------------------------------------------------------------

  defp transport, do: member_of(@known_transports)

  # Duplicate-free declared set over the known transports, in random order.
  defp declared_gen do
    gen all(first <- transport(), second <- transport()) do
      Enum.uniq([first, second])
    end
  end

  # The environment never offers what the action did not declare; shrinking
  # collapses toward the empty environment (total unavailability). Written as
  # a flagged zip (stream_data 1.4 ships no subset/1) with identical
  # semantics: order-preserving sublists of `declared`, shrinking toward [].
  defp available_gen(declared) do
    gen all(flags <- list_of(boolean(), length: length(declared))) do
      for {transport, true} <- Enum.zip(declared, flags), do: transport
    end
  end

  defp class, do: member_of(@dimension_classes)

  defp atom_dims, do: optional_map(%{cost: class(), latency: class(), privacy: class()})

  defp binary_dims,
    do: optional_map(%{"cost" => class(), "latency" => class(), "privacy" => class()})

  defp atom_profile_facts do
    gen all(http <- atom_dims(), channel <- atom_dims()) do
      %{http: http, phoenix_channel: channel}
    end
  end

  defp binary_profile_facts do
    gen all(http <- binary_dims(), channel <- binary_dims()) do
      %{"http" => http, "phoenix_channel" => channel}
    end
  end

  # Realistic action profiles in the contract shape: "transportFacts" present
  # (either key shape), null (not delegated), or absent, plus unrelated
  # profile keys the reader must ignore.
  defp profile_gen do
    gen all(
          facts <-
            one_of([
              constant(:absent),
              constant(nil),
              atom_profile_facts(),
              binary_profile_facts()
            ]),
          noise <- optional_map(%{"transport" => member_of(["auto", "http", "phoenix_channel"])})
        ) do
      case facts do
        :absent -> noise
        other -> Map.put(noise, "transportFacts", other)
      end
    end
  end

  # -- law 1: membership ------------------------------------------------------

  property "law 1: selected ∈ declared ∩ available, on a declared-order frontier" do
    check all(
            declared <- declared_gen(),
            available <- available_gen(declared),
            preferred <- transport(),
            action_id <- member_of([nil, "Post#create", "Session#revoke"]),
            profile <- profile_gen(),
            max_runs: 200
          ) do
      assert {:ok, facts} = Transport.facts_from_profile(profile)

      result =
        Transport.select(declared, available,
          preferred: preferred,
          action_id: action_id,
          facts: facts
        )

      case result do
        {:ok, %Transport.Decision{} = decision} ->
          admissible = Enum.filter(declared, &(&1 in available))

          assert decision.selected in admissible,
                 "selected #{inspect(decision.selected)} escaped declared∩available " <>
                   "#{inspect(admissible)} (declared #{inspect(declared)}, " <>
                   "available #{inspect(available)}, facts #{inspect(facts)})"

          assert decision.frontier != [], "empty frontier despite available #{inspect(available)}"

          assert decision.selected in decision.frontier

          # The frontier is exactly a declared-order subsequence of the
          # admissible set: no invented members, no silent reordering, no
          # silent pruning beyond dominance.
          assert decision.frontier == Enum.filter(admissible, &(&1 in decision.frontier))

          assert decision.declared == declared
          assert decision.available == available
          assert decision.preferred == preferred
          assert decision.action_id == action_id

          # Delegatedness is reported from the admitted facts, never invented.
          expected_dimensions =
            if Enum.any?(facts, fn {_transport, dims} -> dims != %{} end),
              do: :declared,
              else: :undelegated

          assert decision.dimensions == expected_dimensions

        {:error, reason} ->
          # The only lawful refusal under well-formed inputs is total
          # unavailability, carrying the preferred transport.
          assert available == []

          assert {:unsupported_transport, %{preferred: ^preferred, available: []}} = reason
      end
    end
  end

  # -- law 2: preference preserved iff non-dominated ---------------------------

  property "law 2: an available preference wins iff non-dominated; dominated ones yield to the frontier" do
    check all(
            declared <- declared_gen(),
            available <- available_gen(declared),
            preferred <- transport(),
            profile <- profile_gen(),
            max_runs: 200
          ) do
      {:ok, facts} = Transport.facts_from_profile(profile)

      case Transport.select(declared, available, preferred: preferred, facts: facts) do
        {:ok, %Transport.Decision{} = decision} ->
          if preferred in available do
            if non_dominated?(preferred, available, facts) do
              assert decision.selected == preferred,
                     "non-dominated available preference #{inspect(preferred)} was overridden " <>
                       "by #{inspect(decision.selected)} (facts #{inspect(facts)})"

              assert decision.reason == :preferred_available

              assert preferred in decision.frontier
            else
              # Preference is never a license to pick a dominated alternative.
              assert decision.reason == :dimension_weighed

              assert decision.selected in decision.frontier

              refute preferred in decision.frontier,
                     "dominated preference #{inspect(preferred)} survived on the frontier"
            end
          else
            cond do
              decision.dimensions == :undelegated ->
                # Historical fold: first declared transport that is available.
                assert decision.reason == :preferred_unavailable

                assert decision.selected == Enum.find(declared, &(&1 in available)),
                       "undelegated fold left declared order " <>
                         "(declared #{inspect(declared)}, available #{inspect(available)})"

              true ->
                assert decision.reason == :dimension_weighed

                assert decision.selected in decision.frontier
            end
          end

        {:error, {:unsupported_transport, %{available: []}}} ->
          assert available == []
      end
    end
  end

  # Independent dominance oracle: a dominates b iff a is at least as good on
  # every axis comparable between them (both declare it) and strictly better
  # on at least one. Written here from the documented law, not by copying the
  # subject's private calculus.
  defp non_dominated?(candidate, available, facts) do
    not Enum.any?(available, fn other ->
      other != candidate and dominates?(other, candidate, facts)
    end)
  end

  defp dominates?(a, b, facts) do
    comparisons = Enum.map(@dimensions, &compare(&1, a, b, facts))

    Enum.member?(comparisons, :better) and not Enum.member?(comparisons, :worse)
  end

  defp compare(dimension, a, b, facts) do
    case {fetch_class(facts, a, dimension), fetch_class(facts, b, dimension)} do
      {nil, _} -> :incomparable
      {_, nil} -> :incomparable
      {class, class} -> :equal
      {class_a, class_b} -> if better?(dimension, class_a, class_b), do: :better, else: :worse
    end
  end

  defp fetch_class(facts, transport, dimension),
    do: facts |> Map.get(transport, %{}) |> Map.get(dimension)

  # Lower is better for cost and latency; higher is better for privacy.
  defp better?(:privacy, class_a, class_b), do: rank(class_a) > rank(class_b)
  defp better?(_dimension, class_a, class_b), do: rank(class_a) < rank(class_b)

  defp rank(:low), do: 0
  defp rank(:medium), do: 1
  defp rank(:high), do: 2

  # -- law 3: malformed shapes are typed refusals ------------------------------

  property "law 3: malformed shapes are typed refusals — never a raise, never nil, never {:ok, _}" do
    check all(
            kind <- member_of([:declared_set, :available_set, :preferred, :facts]),
            {declared, available, opts} <- malformed_call(kind),
            max_runs: 250
          ) do
      result = Transport.select(declared, available, opts)

      assert {:error, reason} = result,
             "malformed #{inspect(kind)} case must refuse, got #{inspect(result)} " <>
               "(declared #{inspect(declared)}, available #{inspect(available)}, " <>
               "opts #{inspect(opts)})"

      assert is_atom(reason) or
               (is_tuple(reason) and tuple_size(reason) >= 2 and is_atom(elem(reason, 0))),
             "refusal is not a typed term: #{inspect(reason)}"
    end
  end

  # Every case produced here is malformed by construction: at least one
  # argument lies outside the admitted vocabulary, so the only lawful outcome
  # is a typed refusal.
  defp malformed_call(:declared_set) do
    gen all(
          kind <- member_of([:non_list_term, :unadmitted_members]),
          declared <- bad_declared(kind),
          available <- available_gen([:http, :phoenix_channel])
        ) do
      {declared, available, []}
    end
  end

  defp malformed_call(:available_set) do
    gen all(
          bad <-
            member_of([
              :http,
              [:phoenix_channel],
              [:grpc],
              [:http, :grpc],
              [nil],
              [[:http]],
              [:http, nil]
            ])
        ) do
      {[:http], bad, []}
    end
  end

  defp malformed_call(:preferred) do
    gen all(bad <- member_of([:websocket, "http", nil, 42, :GRPC])) do
      {[:http, :phoenix_channel], [:http], preferred: bad}
    end
  end

  defp malformed_call(:facts) do
    gen all(
          kind <-
            member_of([
              :not_a_map,
              :unknown_transport,
              :dims_not_a_map,
              :unknown_dimension,
              :unknown_class
            ]),
          facts <- bad_facts(kind)
        ) do
      {[:http], [:http], facts: facts}
    end
  end

  # Whole-set terms are used directly (never consed — a consed atom becomes a
  # valid one-element list); member cases always carry at least one element
  # outside the admitted atom vocabulary.
  defp bad_declared(:non_list_term),
    do: member_of([:http, "http", nil, 42, {:http}, %{:http => 1}])

  defp bad_declared(:unadmitted_members) do
    gen all(
          bad_member <-
            member_of([:grpc, "grpc", :soap, nil, 42, "http", "phoenix_channel", {:http}]),
          rest <- list_of(transport(), max_length: 2)
        ) do
      Enum.shuffle([bad_member | rest])
    end
  end

  defp bad_facts(:not_a_map), do: member_of([:http, "facts", nil, 42, [:http], {:cost, :low}])

  defp bad_facts(:unknown_transport) do
    gen all(key <- member_of([:grpc, "grpc", "HTTP", :soap, nil, 42, "phoenix channel"])) do
      Map.put(%{}, key, %{cost: :low})
    end
  end

  defp bad_facts(:dims_not_a_map) do
    gen all(
          transport <- member_of([:http, :phoenix_channel, "http", "phoenix_channel"]),
          dims <- member_of([:low, [:low], "low", nil, 42])
        ) do
      Map.put(%{}, transport, dims)
    end
  end

  defp bad_facts(:unknown_dimension) do
    gen all(
          transport <- member_of([:http, :phoenix_channel]),
          dimension <- member_of([:bandwidth, "bandwidth", "Cost", :price, nil, 42]),
          value <- class()
        ) do
      Map.put(%{}, transport, Map.put(%{}, dimension, value))
    end
  end

  defp bad_facts(:unknown_class) do
    gen all(
          transport <- member_of([:http, :phoenix_channel]),
          dimension <- member_of([:cost, :latency, :privacy, "cost", "latency", "privacy"]),
          bad_class <- member_of([:extreme, "extreme", "LOW", "High", 42, :minimal])
        ) do
      Map.put(%{}, transport, Map.put(%{}, dimension, bad_class))
    end
  end
end
