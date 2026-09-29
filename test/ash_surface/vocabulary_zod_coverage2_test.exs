defmodule AshSurface.VocabularyZodCoverage2Test do
  @moduledoc """
  Laws pinned: the closed vocabulary accessors expose exactly the constants
  the rest of the library enforces (dispatch states, refusal prefix,
  idempotency protocol identity), and the zod guard fails closed with a typed
  refusal on every malformed or truncated expression shape - it never
  approximates a partial parse.
  """

  use ExUnit.Case, async: true

  alias AshSurface.Projectors.JS.ZodGuard
  alias AshSurface.Vocabulary

  describe "Vocabulary accessors" do
    test "dispatch states are the closed receipt trio, never a verified standing" do
      assert Vocabulary.dispatch_states() == [
               "not_dispatched",
               "completed",
               "unknown_after_dispatch"
             ]

      refute "SUCCESS" in Vocabulary.dispatch_states()
    end

    test "the refusal prefix defines refusal codes" do
      prefix = Vocabulary.refusal_prefix()
      assert prefix == "REFUSED_"
      assert Vocabulary.refusal_code?(prefix <> "X")
      refute Vocabulary.refusal_code?(prefix)
    end

    test "the idempotency protocol identity is versioned and stable" do
      assert Vocabulary.idempotency_protocol() == "ash_surface.idempotency/1"
    end
  end

  describe "ZodGuard fails closed on malformed expressions" do
    test "a dangling member dot is refused" do
      assert ZodGuard.expression("z.") == {:error, :zod_expected_member_name}
      assert ZodGuard.expression("z.string().") == {:error, :zod_expected_member_name}
    end

    test "truncated call arguments are refused" do
      assert ZodGuard.expression("z.string(") == {:error, :zod_truncated}
      assert ZodGuard.expression("z.object({") == {:error, :zod_truncated}
    end

    test "an unclosed sequence names the missing closer" do
      assert ZodGuard.expression("z.array([1") == {:error, {:zod_unclosed, "]"}}
      assert ZodGuard.expression("z.string(1") == {:error, {:zod_unclosed, ")"}}
    end

    test "an item not separated by a comma is an unexpected token" do
      assert {:error, {:zod_unexpected_token, {:number, "2"}}} =
               ZodGuard.expression("z.string(1 2)")
    end

    test "a non-key object property is unadmitted" do
      assert {:error, {:zod_unadmitted_key, {:number, "1"}}} =
               ZodGuard.expression("z.object({1: z.string()})")
    end

    test "an undecodable string key fails closed as a denied key" do
      assert {:error, {:zod_denied_key, _}} =
               ZodGuard.expression(~S|z.object({"\ud800": z.string()})|)
    end

    test "an escaped __proto__ key is denied by decoded value" do
      assert {:error, {:zod_denied_key, _}} =
               ZodGuard.expression(~S|z.object({"__proto__": z.string()})|)
    end
  end
end
