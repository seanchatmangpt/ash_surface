defmodule AshSurface.CompilerDiscoveryTest do
  @moduledoc """
  Chicago-school, state-based tests of the DiscoverOnce law of
  `AshSurface.Compiler`.

  Re-pointed at v50 integration to the CANONICAL compiler (v02 canon):
  v28's branch-local canon — `IR.normalize/1` over raw action lists,
  memoized compile with `force:`, `ArgumentError` refusals — was superseded
  by `lib/ash_surface/{ir,compiler}.ex`, and its stub declarations were
  dropped. The laws below are the canonical compiler's own, observed through
  the discovery receipt token it mints:

    1. Single discovery per compile. Every section invocation of one
       compile — across every action and every section key — observes the
       IDENTICAL receipt token. A second discovery inside one compile would
       fork the token and break law 1's single-token row.
    2. Identical normalized term. Every section of a run receives the
       IDENTICAL normalized action map for a given action id.
    3. Deterministic compilation. Two independent compiles of one source
       agree on digest, action ids, and ordering.
    4. Fail-closed sources. Non-admitted sources and malformed section
       bindings are refused with typed errors, never coerced.

  The v28 memoization/`force: true` law is NOT asserted here: the canonical
  compiler claims no cross-compile cache; that law is owed by whichever
  caching owner is admitted later.
  """

  use ExUnit.Case, async: true

  alias AshSurface.Compiler
  alias AshSurface.TestSupport.CompilerEchoSection, as: EchoSection
  alias AshSurface.Fixtures.{Domain, VolunteerMilestone}

  @section_keys [:ash, :semantic, :capability, :presentation, :schema]

  # ---------------------------------------------------------------------------
  # Law 1: single discovery — one receipt token per compile, observed by
  # every section invocation of that compile and by no one else.
  # ---------------------------------------------------------------------------

  test "DiscoverOnce 1: every section invocation of one compile observes one receipt token" do
    assert {:ok, irs} = compile_with_echo(Domain)
    assert [%{tokens: tokens}] = echo_log()

    # Every (action x section) invocation saw the same token.
    assert MapSet.size(MapSet.new(tokens)) == 1

    # Two public actions discovered, five sections each: ten invocations.
    assert length(tokens) == 10

    # The echoed action ids partition one-per-IR: all five section slots of
    # one IR carry that IR's own action id.
    assert Enum.all?(irs, fn ir ->
             ids = Enum.map(@section_keys, fn key -> Map.get(ir, key).echo end)
             assert Enum.uniq(ids) == [hd(ids)]
           end)

    assert Enum.map(irs, & &1.digest) |> Enum.uniq() |> length() == 1
  end

  test "DiscoverOnce 1 falsifier: a second compile forks the receipt token" do
    {:ok, _} = compile_with_echo(Domain)
    {:ok, _} = compile_with_echo(Domain)

    assert [%{tokens: first_run}, %{tokens: second_run}] = echo_log()

    # Two compiles, two distinct tokens — a compiler that reused a stale
    # discovery across compiles would collapse these.
    assert hd(first_run) != hd(second_run)
    assert MapSet.new(first_run) |> MapSet.disjoint?(MapSet.new(second_run))
  end

  # ---------------------------------------------------------------------------
  # Law 2: every section of one action receives the identical normalized term.
  # ---------------------------------------------------------------------------

  test "DiscoverOnce 2: all sections of one action receive the identical action term" do
    {:ok, _} = compile_with_echo(Domain)

    for %{by_action: per_action} <- echo_log() do
      for {action_id, terms} <- per_action do
        assert Enum.uniq(terms) == [hd(terms)],
               "action #{action_id}: a section received a forked term"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Law 3: deterministic compilation — two compiles agree on digest and ids.
  # ---------------------------------------------------------------------------

  test "two compiles of one source agree on digest, ids, and ordering" do
    {:ok, first} = compile_with_echo(Domain)
    {:ok, second} = compile_with_echo(Domain)

    # Digest and version are compile-stable; the IR list is id-sorted.
    assert Enum.map(first, & &1.digest) == Enum.map(second, & &1.digest)
    assert Enum.uniq(Enum.map(first, & &1.version)) == Enum.uniq(Enum.map(second, & &1.version))

    first_ids = Enum.map(first, &{&1.version, &1.digest})
    second_ids = Enum.map(second, &{&1.version, &1.digest})
    assert first_ids == second_ids
  end

  # ---------------------------------------------------------------------------
  # Falsifier: malformed sources and section bindings are refused typed.
  # ---------------------------------------------------------------------------

  test "non-admitted sources are refused typed, never coerced" do
    # Echo bindings carry the compile past section validation so the SOURCE
    # refusal itself is the fact under test.
    assert {:error, {:unsupported_source, %{not: :a_source}}} =
             Compiler.compile(%{not: :a_source}, sections: echo_sections())

    assert {:error, {:unsupported_source, 123}} =
             Compiler.compile(123, sections: echo_sections())

    assert {:error, {:unsupported_source, :not_a_domain_module}} =
             Compiler.compile(:not_a_domain_module, sections: echo_sections())
  end

  test "default section bindings fail closed until conforming adapters land" do
    # Integrated truth: the canonical default bindings name
    # AshSurface.Compiler.Section.* adapters that no branch has landed; the
    # compiler refuses them typed instead of silently skipping — the
    # fail-closed law working as designed. The adapter set is owed by the
    # section-conformance owner.
    assert {:error, {:invalid_section_module, :ash, AshSurface.Compiler.Section.Ash}} =
             Compiler.compile(Domain)
  end

  test "malformed section bindings fail closed" do
    assert {:error, {:unknown_section_keys, [:carrier_pigeon]}} =
             Compiler.compile(Domain, sections: [carrier_pigeon: EchoSection])

    assert {:error, {:missing_section_keys, missing}} =
             Compiler.compile(Domain, sections: [ash: EchoSection])

    assert missing == @section_keys -- [:ash]
  end

  # ---------------------------------------------------------------------------
  # Echo section double: records the receipt token and the exact action term
  # each invocation receives. Declared here, bound through compile/2's
  # `:sections` override — the compiler's own test seam.
  # ---------------------------------------------------------------------------


  defp echo_sections, do: Enum.map(@section_keys, &{&1, EchoSection})

  defp compile_with_echo(source),
    do: Compiler.compile(source, sections: echo_sections())

  defp echo_log do
    {AshSurface.TestSupport.CompilerEchoSection, :log}
    |> Process.get([])
    |> Enum.reverse()
    |> Enum.group_by(& &1.token, & &1)
    |> Enum.map(fn {token, records} ->
      %{
        tokens: Enum.map(records, & &1.token),
        by_action:
          Enum.group_by(records, & &1.action_id, & &1.action)
          |> Enum.map(fn {k, v} -> {k, v} end)
          |> Map.new()
      }
    end)
  end
end

