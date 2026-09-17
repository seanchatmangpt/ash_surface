defmodule AshSurface.Transport do
  @moduledoc """
  Pure pre-dispatch transport selection.

  Selection is intentionally separate from execution. Once dispatch begins, this
  module never authorizes automatic transport fallback: a timeout or disconnect can
  occur after the server has already executed a consequential action.

  ## Declared dimension facts (v26.9.17 F6, the selection frontier)

  Selection weighs delegated dimension facts — cost class, latency class, and
  privacy class, each `:low | :medium | :high` — carried in the action profile's
  `"transportFacts"` map. `facts_from_profile/1` normalizes the contract profile
  shape for `select/3`'s `:facts` opt. The facts are delegated truth: an absent
  or `nil` fact means "not delegated" and is never defaulted or re-derived.

  When dimensions are declared, the decision exposes the admitted-alternatives
  frontier — every non-dominated available transport, in declared order — and
  selection stays deterministic:

    * an available preference that is non-dominated still wins
      (`:preferred_available`); preference is never a license to pick a
      dominated alternative;
    * otherwise the frontier's best member is selected (`:dimension_weighed`)
      by fixed priority: cost, then latency, then privacy — lower is better for
      cost and latency, higher is better for privacy (stronger guarantee) — and
      a full tie falls to declared order;
    * an axis is comparable only where BOTH alternatives carry a declared
      class; incomparable axes never dominate.

  Absent-fact behavior is typed: with no delegated facts the decision carries
  `dimensions: :undelegated`, every available alternative is trivially
  non-dominated (the frontier mirrors the available set — no silent pruning),
  and the historical preference law decides unchanged.
  """

  @known_transports [:http, :phoenix_channel]

  # Admitted dimension vocabulary (v26.9.17 F6; ontology.ttl surf:SelectionEdge).
  @dimensions [:cost, :latency, :privacy]
  @dimension_classes [:low, :medium, :high]
  # Fixed deterministic weighing priority: cost, then latency, then privacy.
  @dimension_priority [:cost, :latency, :privacy]

  defmodule Decision do
    @enforce_keys [:declared, :available, :selected, :preferred, :reason]

    @type dimensions :: :undelegated | :declared

    @type t :: %__MODULE__{
            action_id: String.t() | nil,
            declared: [atom()],
            available: [atom()],
            selected: atom(),
            preferred: atom(),
            reason: atom(),
            dispatch_state: :not_dispatched | :dispatched,
            fallback: :pre_dispatch_only,
            dimensions: dimensions(),
            frontier: [atom()]
          }
    defstruct [
      :action_id,
      :declared,
      :available,
      :selected,
      :preferred,
      :reason,
      dispatch_state: :not_dispatched,
      fallback: :pre_dispatch_only,
      dimensions: :undelegated,
      frontier: []
    ]
  end

  @doc """
  Pure pre-dispatch selection: picks one transport from the `:available` set
  over the `:declared` order and returns `{:ok, %Decision{}}`.

  Options:

    * `:preferred` — the declared preference (default `:http`);
    * `:action_id` — carried verbatim onto the decision;
    * `:facts` — delegated dimension facts (see `facts_from_profile/1`).

  Without delegated facts the historical law decides: an available preference
  wins (`:preferred_available`), otherwise the first declared transport that
  is available (`:preferred_unavailable`). With delegated facts the decision
  is weighed on the declared axes, and a preference only wins when it is
  non-dominated (`:preferred_available`), never a dominated alternative.

  Typed refusals — never silent repairs — for unknown transports, availability
  outside the declared set, an unknown preference, or malformed facts.

  ## Examples

      iex> {:ok, decision} = AshSurface.Transport.select([:http, :phoenix_channel], [:phoenix_channel], preferred: :http, action_id: "Ticket#read")
      iex> {decision.selected, decision.reason, decision.dimensions, decision.action_id}
      {:phoenix_channel, :preferred_unavailable, :undelegated, "Ticket#read"}

      The undelegated frontier mirrors the available set — no silent pruning:

      iex> {:ok, decision} = AshSurface.Transport.select([:http, :phoenix_channel], [:http, :phoenix_channel], preferred: :http)
      iex> {decision.selected, decision.reason, decision.dimensions, decision.frontier}
      {:http, :preferred_available, :undelegated, [:http, :phoenix_channel]}

      Declared facts weigh the decision; preference never picks a dominated
      alternative (`http` strictly better on cost, equal on latency):

      iex> facts = %{http: %{cost: :low, latency: :low}, phoenix_channel: %{cost: :high, latency: :low}}
      iex> {:ok, decision} = AshSurface.Transport.select([:http, :phoenix_channel], [:http, :phoenix_channel], preferred: :phoenix_channel, facts: facts)
      iex> {decision.selected, decision.reason, decision.dimensions, decision.frontier}
      {:http, :dimension_weighed, :declared, [:http]}

      Refusals are typed:

      iex> AshSurface.Transport.select([:http], [:smoke_signal])
      {:error, {:unknown_transport, [:smoke_signal]}}

      iex> AshSurface.Transport.select([:http], [:http, :phoenix_channel])
      {:error, {:unadmitted_transport, [:phoenix_channel]}}

      iex> AshSurface.Transport.select([:http], [:http], preferred: :carrier_pigeon)
      {:error, {:unknown_transport, :carrier_pigeon}}
  """
  @spec select([atom()], [atom()], keyword()) :: {:ok, Decision.t()} | {:error, term()}
  def select(declared, available, opts \\ []) do
    preferred = Keyword.get(opts, :preferred, :http)
    action_id = Keyword.get(opts, :action_id)
    raw_facts = Keyword.get(opts, :facts, %{})

    with :ok <- validate_transports(declared),
         :ok <- validate_transports(available),
         :ok <- validate_available_subset(declared, available),
         :ok <- validate_preferred(preferred),
         {:ok, facts} <- admit_facts(raw_facts),
         {:ok, selected, reason, dimensions, frontier} <-
           choose(declared, available, preferred, facts) do
      {:ok,
       %Decision{
         action_id: action_id,
         declared: declared,
         available: available,
         selected: selected,
         preferred: preferred,
         reason: reason,
         dimensions: dimensions,
         frontier: frontier
       }}
    end
  end

  @doc """
  Reads the delegated transport dimension facts out of an action profile map
  (the contract's `surface.actions[].profile` shape: binary keys).

  Returns `{:ok, facts}` — the normalized map for `select/3`'s `:facts` opt.
  An absent or null `"transportFacts"` key is `{:ok, %{}}`: not delegated,
  never defaulted. Malformed shapes and unknown names or classes are typed
  refusals, never silent drops.

  ## Examples

      iex> AshSurface.Transport.facts_from_profile(%{"transportFacts" => %{"http" => %{"cost" => "low", "privacy" => "high"}}})
      {:ok, %{http: %{cost: :low, privacy: :high}}}

      Absent (or null) facts are "not delegated", not empty authority:

      iex> AshSurface.Transport.facts_from_profile(%{})
      {:ok, %{}}

      iex> AshSurface.Transport.facts_from_profile(%{"transportFacts" => nil})
      {:ok, %{}}

      Unknown vocabulary is a typed refusal:

      iex> AshSurface.Transport.facts_from_profile(%{"transportFacts" => %{"http" => %{"cost" => "free"}}})
      {:error, {:unknown_dimension_class, {:http, :cost, "free"}}}

      iex> AshSurface.Transport.facts_from_profile("http")
      {:error, :profile_must_be_a_map}
  """
  @spec facts_from_profile(term()) :: {:ok, map()} | {:error, term()}
  def facts_from_profile(profile) when is_map(profile) do
    case Map.get(profile, "transportFacts") || Map.get(profile, :transportFacts) do
      nil -> {:ok, %{}}
      raw -> admit_facts(raw)
    end
  end

  def facts_from_profile(_profile), do: {:error, :profile_must_be_a_map}

  @spec mark_dispatched(Decision.t()) :: Decision.t()
  def mark_dispatched(%Decision{} = decision), do: %{decision | dispatch_state: :dispatched}

  @spec fallback_allowed?(Decision.t()) :: boolean()
  def fallback_allowed?(%Decision{dispatch_state: :not_dispatched}), do: true
  def fallback_allowed?(%Decision{}), do: false

  # -- selection calculus ----------------------------------------------------

  defp choose(_declared, [], preferred, _facts),
    do: {:error, {:unsupported_transport, %{preferred: preferred, available: []}}}

  defp choose(declared, available, preferred, facts) do
    frontier = frontier(declared, available, facts)

    if dimensions_declared?(facts) do
      cond do
        preferred in available and preferred in frontier ->
          {:ok, preferred, :preferred_available, :declared, frontier}

        true ->
          {:ok, frontier_best(frontier, declared, facts), :dimension_weighed, :declared, frontier}
      end
    else
      cond do
        preferred in available ->
          {:ok, preferred, :preferred_available, :undelegated, frontier}

        true ->
          selected = Enum.find(declared, &(&1 in available))
          {:ok, selected, :preferred_unavailable, :undelegated, frontier}
      end
    end
  end

  # The admitted-alternatives frontier: every available transport (in declared
  # order) that no other available transport dominates on the declared axes.
  defp frontier(declared, available, facts) do
    ordered = Enum.filter(declared, &(&1 in available))

    Enum.reject(ordered, fn transport ->
      Enum.any?(ordered, fn other ->
        other != transport and dominates?(other, transport, facts)
      end)
    end)
  end

  # a dominates b iff a is at least as good on every axis comparable between
  # them (both declared) and strictly better on at least one such axis.
  defp dominates?(a, b, facts) do
    comparisons = Enum.map(@dimension_priority, &compare(&1, a, b, facts))

    Enum.member?(comparisons, :better) and not Enum.member?(comparisons, :worse)
  end

  defp compare(dimension, a, b, facts) do
    case {fact(facts, a, dimension), fact(facts, b, dimension)} do
      {nil, _} -> :incomparable
      {_, nil} -> :incomparable
      {class, class} -> :equal
      {class_a, class_b} -> if better?(dimension, class_a, class_b), do: :better, else: :worse
    end
  end

  defp fact(facts, transport, dimension),
    do: facts |> Map.get(transport, %{}) |> Map.get(dimension)

  # Lower is better for cost and latency; higher is better for privacy.
  defp better?(:privacy, class_a, class_b), do: rank(class_a) > rank(class_b)
  defp better?(_dimension, class_a, class_b), do: rank(class_a) < rank(class_b)

  defp rank(:low), do: 0
  defp rank(:medium), do: 1
  defp rank(:high), do: 2

  # Deterministic frontier winner: compared pairwise in declared order, the
  # first comparable axis with differing classes decides; a full tie falls to
  # declared order.
  defp frontier_best([head | rest], declared, facts) do
    Enum.reduce(rest, head, fn candidate, champion ->
      if lex_better?(candidate, champion, declared, facts), do: candidate, else: champion
    end)
  end

  defp lex_better?(a, b, declared, facts) do
    winner =
      Enum.find_value(@dimension_priority, fn dimension ->
        case compare(dimension, a, b, facts) do
          :better -> a
          :worse -> b
          _other -> nil
        end
      end)

    winner || declared_order_winner(a, b, declared)
  end

  defp declared_order_winner(a, b, declared) do
    if Enum.find_index(declared, &(&1 == a)) <= Enum.find_index(declared, &(&1 == b)),
      do: a,
      else: b
  end

  defp dimensions_declared?(facts),
    do: Enum.any?(facts, fn {_transport, dimensions} -> dimensions != %{} end)

  # -- fact admission (delegated facts, fail closed) --------------------------

  # Accepts the atom shape (`%{http: %{cost: :low}}`) and the contract's
  # binary-key shape (`%{"http" => %{"cost" => "low"}}`); `nil`-valued facts
  # are dropped as "not delegated"; anything outside the admitted vocabulary
  # is a typed refusal.
  defp admit_facts(facts) when is_map(facts) do
    Enum.reduce_while(facts, {:ok, %{}}, fn
      {transport, dimensions}, {:ok, acc} ->
        with {:ok, transport} <- transport_key(transport),
             {:ok, dimensions} <- admit_dimensions(transport, dimensions) do
          {:cont, {:ok, Map.put(acc, transport, dimensions)}}
        else
          {:error, _reason} = error -> {:halt, error}
        end
    end)
  end

  defp admit_facts(_facts), do: {:error, :facts_must_be_a_map}

  defp admit_dimensions(transport, dimensions) when is_map(dimensions) do
    Enum.reduce_while(dimensions, {:ok, %{}}, fn
      {_dimension, nil}, {:ok, acc} ->
        {:cont, {:ok, acc}}

      {dimension, class}, {:ok, acc} ->
        with {:ok, dimension} <- dimension_key(transport, dimension),
             {:ok, class} <- class_key(transport, dimension, class) do
          {:cont, {:ok, Map.put(acc, dimension, class)}}
        else
          {:error, _reason} = error -> {:halt, error}
        end
    end)
  end

  defp admit_dimensions(_transport, _dimensions), do: {:error, :transport_facts_must_be_a_map}

  defp transport_key(transport) when transport in @known_transports, do: {:ok, transport}
  defp transport_key("http"), do: {:ok, :http}
  defp transport_key("phoenix_channel"), do: {:ok, :phoenix_channel}
  defp transport_key(other), do: {:error, {:unknown_transport, [other]}}

  defp dimension_key(_transport, dimension) when dimension in @dimensions, do: {:ok, dimension}
  defp dimension_key(_transport, "cost"), do: {:ok, :cost}
  defp dimension_key(_transport, "latency"), do: {:ok, :latency}
  defp dimension_key(_transport, "privacy"), do: {:ok, :privacy}

  defp dimension_key(transport, other),
    do: {:error, {:unknown_dimension, {transport, other}}}

  defp class_key(_transport, _dimension, class) when class in @dimension_classes,
    do: {:ok, class}

  defp class_key(_transport, _dimension, "low"), do: {:ok, :low}
  defp class_key(_transport, _dimension, "medium"), do: {:ok, :medium}
  defp class_key(_transport, _dimension, "high"), do: {:ok, :high}

  defp class_key(transport, dimension, other),
    do: {:error, {:unknown_dimension_class, {transport, dimension, other}}}

  # -- transport-set fences (unchanged) ---------------------------------------

  defp validate_available_subset(declared, available) do
    unadmitted = available -- declared
    if unadmitted == [], do: :ok, else: {:error, {:unadmitted_transport, unadmitted}}
  end

  defp validate_preferred(preferred) when preferred in @known_transports, do: :ok
  defp validate_preferred(preferred), do: {:error, {:unknown_transport, preferred}}

  defp validate_transports(transports) when is_list(transports) do
    unknown = Enum.reject(transports, &(&1 in @known_transports))
    if unknown == [], do: :ok, else: {:error, {:unknown_transport, unknown}}
  end

  defp validate_transports(_), do: {:error, :transports_must_be_a_list}
end
