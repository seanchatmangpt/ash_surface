defmodule AshSurface.IdempotencyTest do
  @moduledoc """
  Law pinned: the `ash_surface.idempotency/1` key law, canonical request
  digest, and pure ledger admission (`:first | {:replay, _} | {:conflict, _}`).

  Cross-language parity: the vectors are read from
  `test/js/fixtures/idempotency_vectors.json`, the same file
  `test/js/idempotency_parity.test.mjs` asserts against the JavaScript
  runtime. Ledger functions are pure over a caller-supplied map.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Idempotency

  @vectors "../js/fixtures/idempotency_vectors.json"
           |> Path.expand(__DIR__)
           |> File.read!()
           |> Jason.decode!()

  test "protocol identifier matches the shared vectors" do
    assert Idempotency.protocol() == @vectors["protocol"]
    assert Idempotency.protocol() == "ash_surface.idempotency/1"
  end

  test "request digest vectors (shared with the JavaScript runtime)" do
    for v <- @vectors["digests"] do
      input = Jason.decode!(v["inputJson"])
      assert {:ok, digest} = Idempotency.request_digest(v["actionId"], input)
      assert digest == v["digest"], "#{v["actionId"]} #{v["inputJson"]}"
      assert String.length(digest) == 64
    end
  end

  test "derived key vectors are shared and valid" do
    for v <- @vectors["derivedKeys"] do
      key = Idempotency.derive_key(v["actionId"], v["commandId"])
      assert key == v["key"]
      assert Idempotency.valid_key?(key)
    end
  end

  test "key validation vectors" do
    for key <- @vectors["validKeys"], do: assert(Idempotency.validate_key(key) == :ok, key)

    for key <- @vectors["invalidKeys"] do
      assert Idempotency.validate_key(key) == {:error, :invalid_key}, inspect(key)
    end

    assert Idempotency.validate_key(nil) == {:error, :not_a_string}
    assert Idempotency.validate_key(12_345_678) == {:error, :not_a_string}
    refute Idempotency.valid_key?(:abcd1234)
  end

  test "non-portable inputs are refused with a typed reason" do
    for json <- @vectors["nonPortableInputJson"] do
      assert {:error, _reason} = Idempotency.request_digest("act", Jason.decode!(json))
    end

    assert {:error, {:not_portable, ["a"]}} = Idempotency.request_digest("act", %{"a" => :atom})
    assert {:error, {:non_string_key, []}} = Idempotency.request_digest("act", %{a: 1})
    assert {:error, {:invalid_utf8, []}} = Idempotency.request_digest("act", <<255>>)

    assert {:error, {:unsafe_integer, ["n", 0]}} =
             Idempotency.request_digest("act", %{"n" => [9_007_199_254_740_992]})

    assert {:error, {:not_portable, []}} = Idempotency.request_digest("act", ~D[2026-01-01])
  end

  test "digest ignores map order and binds the action identity" do
    {:ok, a} = Idempotency.request_digest("x", %{"p" => 1, "q" => 2})
    {:ok, b} = Idempotency.request_digest("x", %{"q" => 2, "p" => 1})
    {:ok, c} = Idempotency.request_digest("y", %{"p" => 1, "q" => 2})
    assert a == b
    refute a == c
  end

  describe "ledger" do
    setup do
      {:ok, d1} = Idempotency.request_digest("act", %{"n" => 1})
      {:ok, d2} = Idempotency.request_digest("act", %{"n" => 2})
      %{d1: d1, d2: d2, key: "key-12345678"}
    end

    test "unseen key is :first and admit is pure", %{key: key, d1: d1} do
      assert Idempotency.admit(key, d1, %{}) == :first
      assert Idempotency.admit(key, d1, %{}) == :first
    end

    test "reserve then admit reports in flight; complete then admit replays", ctx do
      %{key: key, d1: d1} = ctx
      {:ok, s1} = Idempotency.reserve(key, d1, %{})
      assert s1 == %{key => %{digest: d1, outcome: :pending}}
      assert Idempotency.admit(key, d1, s1) == {:conflict, :in_flight}

      {:ok, s2} = Idempotency.complete(key, d1, %{"id" => 7}, s1)
      assert Idempotency.admit(key, d1, s2) == {:replay, %{"id" => 7}}
      # the original state is untouched (pure)
      assert Idempotency.admit(key, d1, s1) == {:conflict, :in_flight}
    end

    test "same key, different request digest is always a conflict", ctx do
      %{key: key, d1: d1, d2: d2} = ctx
      {:ok, s1} = Idempotency.reserve(key, d1, %{})
      {:ok, s2} = Idempotency.complete(key, d1, :done, s1)
      assert Idempotency.admit(key, d2, s1) == {:conflict, :digest_mismatch}
      assert Idempotency.admit(key, d2, s2) == {:conflict, :digest_mismatch}
    end

    test "reserve refuses anything but a first sighting", %{key: key, d1: d1} do
      {:ok, s1} = Idempotency.reserve(key, d1, %{})
      assert {:error, {:not_first, {:conflict, :in_flight}}} = Idempotency.reserve(key, d1, s1)
    end

    test "complete is exactly-once and digest-bound", %{key: key, d1: d1, d2: d2} do
      assert Idempotency.complete(key, d1, :x, %{}) == {:error, :not_reserved}
      {:ok, s1} = Idempotency.reserve(key, d1, %{})
      assert Idempotency.complete(key, d2, :x, s1) == {:error, :digest_mismatch}
      {:ok, s2} = Idempotency.complete(key, d1, :x, s1)
      assert Idempotency.complete(key, d1, :y, s2) == {:error, :already_completed}
      assert Idempotency.admit(key, d1, s2) == {:replay, :x}
    end
  end
end
