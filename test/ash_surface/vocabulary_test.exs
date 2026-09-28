defmodule AshSurface.VocabularyTest do
  @moduledoc """
  Pins the single-sourced cross-boundary vocabulary: the refusal law
  ("REFUSED_" plus a non-empty reason), digest shape, and that every
  consumer module (Standing, Transport, AshSurface profile validation) answers
  from `AshSurface.Vocabulary`, not from a private copy.
  """
  use ExUnit.Case, async: true
  doctest AshSurface.Vocabulary

  alias AshSurface.{Standing, Transport, Vocabulary}

  test "refusal law: prefix plus non-empty reason, binaries only" do
    assert Vocabulary.refusal_code?("REFUSED_NO_AUTHORITY")
    refute Vocabulary.refusal_code?("REFUSED_")
    refute Vocabulary.refusal_code?("REFUSED")
    refute Vocabulary.refusal_code?("refused_x")
    refute Vocabulary.refusal_code?(nil)
  end

  test "Standing answers from the vocabulary, including the empty-reason atom" do
    assert Standing.base_standings() == Vocabulary.base_standings()
    assert Standing.valid?(:REFUSED_NO_AUTHORITY)
    refute Standing.valid?(:REFUSED_)
    refute Standing.valid?(:REFUSED)
    refute Standing.refused?(:REFUSED_)
    refute Standing.valid?(nil)
  end

  test "digest shape versus canonical digest" do
    hex = String.duplicate("ab", 32)
    assert Vocabulary.digest_shape?(hex) and Vocabulary.digest?(hex)
    assert Vocabulary.digest_shape?(String.upcase(hex))
    refute Vocabulary.digest?(String.upcase(hex))
    refute Vocabulary.digest?(String.duplicate("g", 64))
    refute Vocabulary.digest_shape?(:atom)
    assert Vocabulary.digest_hex_length() == byte_size(hex)
  end

  test "Transport admits exactly the vocabulary's transports, dimensions and classes" do
    for t <- Vocabulary.known_transports() do
      assert {:ok, %{selected: ^t}} = Transport.select([t], [t], preferred: t)
    end

    for d <- Vocabulary.dimensions(), c <- Vocabulary.dimension_classes() do
      profile = %{"transportFacts" => %{"http" => %{Atom.to_string(d) => Atom.to_string(c)}}}
      assert {:ok, %{http: %{^d => ^c}}} = Transport.facts_from_profile(profile)
    end

    assert {:error, {:unknown_dimension, {:http, "jitter"}}} =
             Transport.facts_from_profile(%{
               "transportFacts" => %{"http" => %{"jitter" => "low"}}
             })

    assert {:error, {:unknown_transport, ["smtp"]}} =
             Transport.facts_from_profile(%{"transportFacts" => %{"smtp" => %{"cost" => "low"}}})
  end

  test "the fixed weighing priority is cost, latency, privacy" do
    assert Vocabulary.dimension_priority() == [:cost, :latency, :privacy]
  end

  test "to_map is JSON-shaped: string keys, string/integer leaves" do
    map = Vocabulary.to_map()
    assert map == map |> Jason.encode!() |> Jason.decode!()
    assert map["refusalPrefix"] == "REFUSED_"
    assert map["digestHexLength"] == 64
  end
end
