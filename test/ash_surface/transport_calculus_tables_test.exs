defmodule AshSurface.TransportCalculusTablesTest do
  @moduledoc """
  State-table proof of the v26.9.17 selection calculus
  (chicago-select-frontier-030), exercised against the real
  `AshSurface.Transport.select/3` / `facts_from_profile/1`.

  Four declared tables, one row per test:

    * Table A — preference dominates facts: an available preference wins
      when it stays on the admitted-alternatives frontier, and NEVER picks
      a dominated rival;
    * Table B — the frontier's best member is weighed by fixed priority
      (cost, then latency, then privacy; lower is better except privacy,
      where higher is better); an axis is comparable only where BOTH
      alternatives declare it; incomparable axes never dominate;
    * Table C — absent facts are legacy law, byte-identical: the decision
      carries `dimensions: :undelegated`, the frontier mirrors the
      available set, and the historical preference law decides unchanged;
    * Table D — malformed facts are typed refusals, never silent drops,
      and the transport-set fences keep their precedence.

  Every row asserts observable outcome state only (selected, reason,
  dimensions, frontier, or the typed error). No doubles: the module is
  pure, so rows call the real subject with real inputs.
  """

  use ExUnit.Case, async: true

  alias AshSurface.Transport

  # -- Table A: preference dominates facts ------------------------------------

  @preference_rows [
    %{
      id: "A1",
      law: "a preference tied on every declared axis stays on the frontier and wins",
      declared: [:http, :phoenix_channel],
      available: [:http, :phoenix_channel],
      opts: [
        preferred: :phoenix_channel,
        facts: %{http: %{cost: :low}, phoenix_channel: %{cost: :low}}
      ],
      expect: %{
        selected: :phoenix_channel,
        reason: :preferred_available,
        dimensions: :declared,
        frontier: [:http, :phoenix_channel]
      }
    },
    %{
      id: "A2",
      law: "a preference wins on disjoint (incomparable) axes without dominating",
      declared: [:http, :phoenix_channel],
      available: [:http, :phoenix_channel],
      opts: [
        preferred: :http,
        facts: %{http: %{cost: :high}, phoenix_channel: %{latency: :high}}
      ],
      expect: %{
        selected: :http,
        reason: :preferred_available,
        dimensions: :declared,
        frontier: [:http, :phoenix_channel]
      }
    },
    %{
      id: "A3",
      law: "a preference dominated on every declared axis is overridden",
      declared: [:http, :phoenix_channel],
      available: [:http, :phoenix_channel],
      opts: [
        preferred: :http,
        facts: %{
          http: %{cost: :high, latency: :high, privacy: :low},
          phoenix_channel: %{cost: :low, latency: :low, privacy: :high}
        }
      ],
      expect: %{
        selected: :phoenix_channel,
        reason: :dimension_weighed,
        dimensions: :declared,
        frontier: [:phoenix_channel]
      }
    },
    %{
      id: "A4",
      law: "the override is symmetric: a dominated channel preference loses too",
      declared: [:http, :phoenix_channel],
      available: [:http, :phoenix_channel],
      opts: [
        preferred: :phoenix_channel,
        facts: %{
          http: %{cost: :low, latency: :low, privacy: :high},
          phoenix_channel: %{cost: :high, latency: :high, privacy: :low}
        }
      ],
      expect: %{
        selected: :http,
        reason: :dimension_weighed,
        dimensions: :declared,
        frontier: [:http]
      }
    }
  ]

  # -- Table B: frontier best via cost -> latency -> privacy ------------------
  #
  # Reachability note (discovered while tabling, chicago-select-frontier-030):
  # with the two-transport vocabulary, an available NON-dominated preference
  # short-circuits as :preferred_available before the lex weighing runs, so
  # the weighed outcome (:dimension_weighed) is observable exactly when the
  # preference is dominated or unavailable. The declared priority is then
  # pinned through which rival dominates: cost decides first, then latency,
  # then privacy (higher is better). Flipping the class direction
  # (`better?/3` / `rank/1`) in lib/ash_surface/transport.ex turns exactly
  # the direction-pinning rows RED (A3, A4, B1, B2, B3, B6, B7, D10) while
  # tie and tradeoff rows (A1, A2, B4, B5, B8) stay GREEN.

  @weighed_rows [
    %{
      id: "B1",
      law:
        "cost decides first: an equal-latency rival with the low cost dominates the preferred high cost",
      declared: [:http, :phoenix_channel],
      available: [:http, :phoenix_channel],
      opts: [
        preferred: :http,
        facts: %{
          http: %{cost: :high, latency: :low},
          phoenix_channel: %{cost: :low, latency: :low}
        }
      ],
      expect: %{
        selected: :phoenix_channel,
        reason: :dimension_weighed,
        dimensions: :declared,
        frontier: [:phoenix_channel]
      }
    },
    %{
      id: "B2",
      law: "cost ties, latency decides next: the low-latency rival dominates",
      declared: [:http, :phoenix_channel],
      available: [:http, :phoenix_channel],
      opts: [
        facts: %{
          http: %{cost: :low, latency: :high},
          phoenix_channel: %{cost: :low, latency: :low}
        }
      ],
      expect: %{
        selected: :phoenix_channel,
        reason: :dimension_weighed,
        dimensions: :declared,
        frontier: [:phoenix_channel]
      }
    },
    %{
      id: "B3",
      law: "cost and latency tie, privacy decides (higher is better) and prunes the loser",
      declared: [:http, :phoenix_channel],
      available: [:http, :phoenix_channel],
      opts: [
        facts: %{
          http: %{cost: :low, latency: :low, privacy: :medium},
          phoenix_channel: %{cost: :low, latency: :low, privacy: :high}
        }
      ],
      expect: %{
        selected: :phoenix_channel,
        reason: :dimension_weighed,
        dimensions: :declared,
        frontier: [:phoenix_channel]
      }
    },
    %{
      id: "B4",
      law:
        "a full tie on the only declared axis keeps both alternatives on the frontier and the preference wins it",
      declared: [:http, :phoenix_channel],
      available: [:http, :phoenix_channel],
      opts: [
        preferred: :phoenix_channel,
        facts: %{
          http: %{cost: :low, latency: :medium, privacy: :medium},
          phoenix_channel: %{cost: :low, latency: :medium, privacy: :medium}
        }
      ],
      expect: %{
        selected: :phoenix_channel,
        reason: :preferred_available,
        dimensions: :declared,
        frontier: [:http, :phoenix_channel]
      }
    },
    %{
      id: "B5",
      law: "a full tie with the preference unavailable weighs the fold to declared order",
      declared: [:http, :phoenix_channel],
      available: [:phoenix_channel],
      opts: [
        preferred: :http,
        facts: %{http: %{cost: :low}, phoenix_channel: %{cost: :low}}
      ],
      expect: %{
        selected: :phoenix_channel,
        reason: :dimension_weighed,
        dimensions: :declared,
        frontier: [:phoenix_channel]
      }
    },
    %{
      id: "B6",
      law:
        "an axis is comparable only where BOTH declare it; a privacy-high declaration dominates and prunes",
      declared: [:http, :phoenix_channel],
      available: [:http, :phoenix_channel],
      opts: [
        facts: %{http: %{privacy: :high}, phoenix_channel: %{privacy: :low}}
      ],
      expect: %{
        selected: :http,
        reason: :preferred_available,
        dimensions: :declared,
        frontier: [:http]
      }
    },
    %{
      id: "B7",
      law:
        "medium classes rank between low and high: a medium rival dominates a high-declared preference on the same axes",
      declared: [:http, :phoenix_channel],
      available: [:http, :phoenix_channel],
      opts: [
        facts: %{
          http: %{cost: :high, latency: :high},
          phoenix_channel: %{cost: :medium, latency: :medium}
        }
      ],
      expect: %{
        selected: :phoenix_channel,
        reason: :dimension_weighed,
        dimensions: :declared,
        frontier: [:phoenix_channel]
      }
    },
    %{
      id: "B8",
      law:
        "a maximal tradeoff leaves every rival non-dominated and the available preference standing",
      declared: [:http, :phoenix_channel],
      available: [:http, :phoenix_channel],
      opts: [
        facts: %{
          http: %{cost: :low, latency: :high, privacy: :low},
          phoenix_channel: %{cost: :medium, latency: :low, privacy: :high}
        }
      ],
      expect: %{
        selected: :http,
        reason: :preferred_available,
        dimensions: :declared,
        frontier: [:http, :phoenix_channel]
      }
    }
  ]

  # -- Table C: absent facts are legacy law, byte-identical --------------------

  @absent_rows [
    %{
      id: "C1",
      law: "no :facts opt at all runs the legacy law and mirrors the available set",
      declared: [:http, :phoenix_channel],
      available: [:http, :phoenix_channel],
      opts: [],
      expect: %{
        selected: :http,
        reason: :preferred_available,
        dimensions: :undelegated,
        frontier: [:http, :phoenix_channel]
      }
    },
    %{
      id: "C3",
      law: "an empty facts map folds to the first declared-available transport exactly as legacy",
      declared: [:http, :phoenix_channel],
      available: [:phoenix_channel],
      opts: [preferred: :http, facts: %{}],
      expect: %{
        selected: :phoenix_channel,
        reason: :preferred_unavailable,
        dimensions: :undelegated,
        frontier: [:phoenix_channel]
      }
    },
    %{
      id: "C4",
      law: "nil-valued dimensions are not delegation: the legacy law runs unchanged",
      declared: [:http, :phoenix_channel],
      available: [:http, :phoenix_channel],
      opts: [
        facts: %{http: %{cost: nil}, phoenix_channel: %{latency: nil}}
      ],
      expect: %{
        selected: :http,
        reason: :preferred_available,
        dimensions: :undelegated,
        frontier: [:http, :phoenix_channel]
      }
    },
    %{
      id: "C5",
      law: "per-transport maps emptied by admission are still :undelegated",
      declared: [:http, :phoenix_channel],
      available: [:http, :phoenix_channel],
      opts: [facts: %{http: %{}, phoenix_channel: %{}}],
      expect: %{
        selected: :http,
        reason: :preferred_available,
        dimensions: :undelegated,
        frontier: [:http, :phoenix_channel]
      }
    }
  ]

  # -- Table D: malformed facts are typed refusals -----------------------------

  @refusal_rows [
    %{
      id: "D1",
      law: "facts that are not a map are refused",
      declared: [:http],
      available: [:http],
      opts: [facts: :http],
      error: :facts_must_be_a_map
    },
    %{
      id: "D2",
      law: "an unknown atom transport key is refused",
      declared: [:http],
      available: [:http],
      opts: [facts: %{grpc: %{cost: :low}}],
      error: {:unknown_transport, [:grpc]}
    },
    %{
      id: "D3",
      law: "an unknown binary transport key is refused in the contract shape too",
      declared: [:http],
      available: [:http],
      opts: [facts: %{"grpc" => %{"cost" => "low"}}],
      error: {:unknown_transport, ["grpc"]}
    },
    %{
      id: "D4",
      law: "an unknown dimension name is refused",
      declared: [:http],
      available: [:http],
      opts: [facts: %{http: %{bandwidth: :low}}],
      error: {:unknown_dimension, {:http, :bandwidth}}
    },
    %{
      id: "D5",
      law: "an out-of-vocabulary class is refused with the offending value",
      declared: [:http],
      available: [:http],
      opts: [facts: %{http: %{cost: :extreme}}],
      error: {:unknown_dimension_class, {:http, :cost, :extreme}}
    },
    %{
      id: "D6",
      law: "a binary-key profile with a wrongly-cased class is refused identically",
      declared: [:http],
      available: [:http],
      opts: [facts: %{"http" => %{"cost" => "Low"}}],
      error: {:unknown_dimension_class, {:http, :cost, "Low"}}
    },
    %{
      id: "D7",
      law: "per-transport dimensions that are not a map are refused",
      declared: [:http],
      available: [:http],
      opts: [facts: %{http: [:low]}],
      error: :transport_facts_must_be_a_map
    },
    %{
      id: "D8",
      law: "the unadmitted-transport fence keeps precedence over fact admission",
      declared: [:http],
      available: [:http, :phoenix_channel],
      opts: [facts: %{http: %{cost: :bogus}}],
      error: {:unadmitted_transport, [:phoenix_channel]}
    },
    %{
      id: "D9",
      law: "the unknown-preferred fence keeps precedence over fact admission",
      declared: [:http],
      available: [:http],
      opts: [preferred: :grpc, facts: %{http: %{cost: :bogus}}],
      error: {:unknown_transport, :grpc}
    }
  ]

  for row <- Enum.concat([@preference_rows, @weighed_rows, @absent_rows]) do
    test "#{row.id}: #{row.law}" do
      row = unquote(Macro.escape(row))

      assert {:ok, decision} = Transport.select(row.declared, row.available, row.opts)

      assert decision.selected == row.expect.selected,
             "selected: #{inspect(decision.selected)} != #{inspect(row.expect.selected)}"

      assert decision.reason == row.expect.reason
      assert decision.dimensions == row.expect.dimensions
      assert decision.frontier == row.expect.frontier
    end
  end

  for row <- @refusal_rows do
    test "#{row.id}: #{row.law}" do
      row = unquote(Macro.escape(row))

      assert {:error, row.error} == Transport.select(row.declared, row.available, row.opts),
             "expected typed refusal #{inspect(row.error)}"
    end
  end

  # -- facts_from_profile/1: the contract-profile shape ------------------------

  test "C2: an explicit empty facts map is byte-identical to omitting the opt" do
    {:ok, without_opt} = Transport.select([:http, :phoenix_channel], [:http, :phoenix_channel])

    {:ok, with_empty} =
      Transport.select([:http, :phoenix_channel], [:http, :phoenix_channel], facts: %{})

    assert with_empty == without_opt
    assert with_empty.dimensions == :undelegated
    assert with_empty.frontier == [:http, :phoenix_channel]
  end

  test "D10: facts_from_profile normalizes the contract shape onto the atom facts" do
    profile = %{
      "transportFacts" => %{
        "http" => %{"cost" => "high"},
        "phoenix_channel" => %{"cost" => "low"}
      }
    }

    assert {:ok, facts} = Transport.facts_from_profile(profile)
    assert facts == %{http: %{cost: :high}, phoenix_channel: %{cost: :low}}

    assert {:ok, decision} =
             Transport.select([:http, :phoenix_channel], [:http, :phoenix_channel],
               preferred: :http,
               facts: facts
             )

    assert decision.selected == :phoenix_channel
    assert decision.reason == :dimension_weighed
    assert decision.dimensions == :declared
    assert decision.frontier == [:phoenix_channel]
  end

  test "D11: an absent or null transportFacts key is {:ok, %{}} — not delegated, never defaulted" do
    assert {:ok, %{}} = Transport.facts_from_profile(%{})
    assert {:ok, %{}} = Transport.facts_from_profile(%{"transport" => "auto"})
    assert {:ok, %{}} = Transport.facts_from_profile(%{"transportFacts" => nil})
    # The atom-key profile shape is admitted identically.
    assert {:ok, %{}} = Transport.facts_from_profile(%{transportFacts: nil})
  end

  test "D12: a non-map profile is a typed refusal" do
    assert {:error, :profile_must_be_a_map} = Transport.facts_from_profile(:http)
    assert {:error, :profile_must_be_a_map} = Transport.facts_from_profile(nil)
    assert {:error, :profile_must_be_a_map} = Transport.facts_from_profile(profile: %{})
  end
end
