defmodule AshSurface.TransportCoverageTest do
  @moduledoc """
  Pins two corners of the pre-dispatch transport-selection law of
  `AshSurface.Transport` against the real module:

    1. The contract's binary-keyed `"medium"` class is admitted as `:medium`
       and sits strictly between `:low` and `:high` on every axis, so a
       `"medium"` fact weighs a real selection rather than being dropped or
       refused.
    2. The frontier/preference closure over the admitted transport
       vocabulary: exhaustively, over every delegated fact assignment for the
       two admitted transports, a `:dimension_weighed` decision always
       resolves a singleton frontier (and selects its only member), and a
       two-member frontier is always resolved by the non-dominated
       preference (`:preferred_available`). Pre-dispatch fallback never
       picks a dominated alternative and never leaves the frontier.
  """

  use ExUnit.Case, async: true

  alias AshSurface.Transport

  @declared [:http, :phoenix_channel]
  @classes [nil, :low, :medium, :high]

  describe "the \"medium\" dimension class" do
    test "binary \"medium\" is admitted as :medium on every axis" do
      profile = %{
        "transportFacts" => %{
          "phoenix_channel" => %{"cost" => "medium", "latency" => "medium", "privacy" => "medium"}
        }
      }

      assert Transport.facts_from_profile(profile) ==
               {:ok, %{phoenix_channel: %{cost: :medium, latency: :medium, privacy: :medium}}}
    end

    test "a \"medium\" cost loses to \"low\" and beats \"high\" in a real selection" do
      beats_high = %{
        "http" => %{"cost" => "high"},
        "phoenix_channel" => %{"cost" => "medium"}
      }

      assert {:ok, decision} =
               Transport.select(@declared, @declared, preferred: :http, facts: beats_high)

      assert {decision.selected, decision.reason, decision.dimensions, decision.frontier} ==
               {:phoenix_channel, :dimension_weighed, :declared, [:phoenix_channel]}

      loses_to_low = %{
        "http" => %{"cost" => "low"},
        "phoenix_channel" => %{"cost" => "medium"}
      }

      assert {:ok, decision} =
               Transport.select(@declared, @declared,
                 preferred: :phoenix_channel,
                 facts: loses_to_low
               )

      assert {decision.selected, decision.reason, decision.frontier} ==
               {:http, :dimension_weighed, [:http]}
    end

    test "\"medium\" privacy is a weaker guarantee than \"high\" (higher is better)" do
      facts = %{
        "http" => %{"privacy" => "medium"},
        "phoenix_channel" => %{"privacy" => "high"}
      }

      assert {:ok, decision} =
               Transport.select(@declared, @declared, preferred: :http, facts: facts)

      assert {decision.selected, decision.frontier} == {:phoenix_channel, [:phoenix_channel]}
    end
  end

  describe "frontier/preference closure over the admitted vocabulary" do
    test "dimension_weighed always resolves a singleton frontier; a plural frontier is resolved by preference" do
      rows =
        for http <- fact_assignments(),
            channel <- fact_assignments(),
            facts = %{http: http, phoenix_channel: channel},
            facts |> Map.values() |> Enum.any?(&(&1 != %{})),
            available <- [[:http], [:phoenix_channel], @declared],
            preferred <- @declared do
          {:ok, decision} =
            Transport.select(@declared, available, preferred: preferred, facts: facts)

          {facts, available, preferred, decision}
        end

      # 63 non-empty assignments per transport, 64 * 64 - 1 delegated pairs.
      assert length(rows) == (64 * 64 - 1) * 3 * 2

      for {facts, available, preferred, decision} <- rows do
        context = %{facts: facts, available: available, preferred: preferred}

        assert decision.dimensions == :declared, inspect(context)
        assert decision.selected in decision.frontier, inspect(context)
        assert Enum.all?(decision.frontier, &(&1 in available)), inspect(context)

        case decision.reason do
          :dimension_weighed ->
            refute preferred in decision.frontier, inspect(context)
            assert decision.frontier == [decision.selected], inspect(context)

          :preferred_available ->
            assert decision.selected == preferred, inspect(context)
        end

        if length(decision.frontier) > 1 do
          assert decision.reason == :preferred_available, inspect(context)
        end
      end
    end
  end

  describe "a transport set is a set" do
    test "a repeated declared or available member is refused, never put on the frontier twice" do
      facts = %{http: %{cost: :low}}

      assert Transport.select([:http, :http], [:http], preferred: :phoenix_channel, facts: facts) ==
               {:error, {:duplicate_transport, [:http]}}

      assert Transport.select([:http, :phoenix_channel], [:http, :http], facts: facts) ==
               {:error, {:duplicate_transport, [:http]}}

      assert Transport.select(
               [:phoenix_channel, :http, :phoenix_channel, :http],
               [:http],
               []
             ) == {:error, {:duplicate_transport, [:http, :phoenix_channel]}}
    end

    test "an unknown member is reported before a duplicate" do
      assert Transport.select([:smoke_signal, :http, :http], [:http]) ==
               {:error, {:unknown_transport, [:smoke_signal]}}
    end
  end

  defp fact_assignments do
    for cost <- @classes, latency <- @classes, privacy <- @classes do
      %{cost: cost, latency: latency, privacy: privacy}
      |> Enum.reject(fn {_axis, class} -> is_nil(class) end)
      |> Map.new()
    end
  end
end
