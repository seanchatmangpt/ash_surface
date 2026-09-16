defmodule AshSurface.CompilerDiscoveryTest do
  @moduledoc """
  Chicago-school, state-based tests of the DiscoverOnce law of
  `AshSurface.Compiler`.

  Law under test:

    1. Single read. Compiling 50 actions through all five injected sections
       reads the source EXACTLY once — not once per section (5 reads), not
       once per action (50 reads). Two independent records must agree: the
       caller-side reader counter and the compiler's own `reads` field.
    2. Identical normalized term. Every section of a run receives the
       IDENTICAL normalized `AshSurface.IR`. Each section echoes back the
       exact term it received, so all five echoes plus the compilation's
       own IR must be one term.
    3. Recompile discipline. A second compile of an unchanged source
       performs ZERO reads and serves the memoized compilation; discovery
       runs again ONLY when forced (`force: true`).

  Falsifiers embedded in the tables: a per-section reader burns 5 reads, a
  per-action reader burns 50 — both break law 1's frozen `reads == 1` row.
  A compiler that forks the IR per section breaks law 2's one-echo-term
  row. A compiler that re-reads on recompile — or never re-reads when
  forced — breaks law 3's frozen 1/0/1 read table.
  """

  use ExUnit.Case, async: true

  alias AshSurface.Compiler
  alias AshSurface.IR

  @action_count 50

  # Frozen table: exactly 50 deterministic action declarations, plus two
  # deliberately private ones and one non-default transport so the section
  # projections below are distinguishable.
  @fifty_actions Enum.map(1..@action_count, fn i ->
                   name =
                     String.to_atom("act_" <> String.pad_leading(Integer.to_string(i), 2, "0"))

                   cond do
                     i == 7 -> %{action: name, transport: :http, public: false}
                     i == 41 -> %{action: name, transport: :phoenix_channel, public: false}
                     true -> name
                   end
                 end)

  @fifty_public_count @action_count - 2

  # ---------------------------------------------------------------------------
  # Law 0 (support): normalization is canonical — the "normalized term" the
  # sections receive cannot be forked by input order or omitted defaults.
  # ---------------------------------------------------------------------------

  test "normalization is canonical: order and defaults cannot fork the term" do
    sorted = IR.normalize(@fifty_actions)
    shuffled = IR.normalize(Enum.reverse(@fifty_actions))

    assert shuffled == sorted
    assert shuffled.digest == sorted.digest
    assert List.first(sorted.actions) == %{action: :act_01, transport: :auto, public: true}
  end

  # ---------------------------------------------------------------------------
  # Law 1: single read — the counting double records metadata reads.
  # ---------------------------------------------------------------------------

  test "DiscoverOnce 1: 50 actions over five sections read the source exactly once" do
    counter = {:discover_reads, :single_read_law}
    source = counting_reader(counter, @fifty_actions)

    compiled = Compiler.compile(source)

    # Two independent records of the same event must agree: the reader-side
    # counter and the compiler-side reads field.
    assert Process.get(counter, 0) == 1
    assert compiled.reads == 1

    # All five sections ran, over all fifty actions.
    assert map_size(compiled.sections) == 5
    assert length(compiled.ir.actions) == @action_count
    assert compiled.sections.actions.data == Enum.map(compiled.ir.actions, & &1.action)
    assert compiled.sections.public_index.data |> length() == @fifty_public_count
    assert compiled.sections.private_index.data == [:act_07, :act_41]
  end

  # ---------------------------------------------------------------------------
  # Law 2: all five sections receive the IDENTICAL normalized term.
  # ---------------------------------------------------------------------------

  test "DiscoverOnce 2: all five sections receive the identical normalized IR" do
    counter = {:discover_reads, :identical_term_law}
    source = counting_reader(counter, @fifty_actions)

    compiled = Compiler.compile(source)
    assert Process.get(counter, 0) == 1

    echoes = compiled.sections |> Map.values() |> Enum.map(& &1.ir)

    # One term: every echo equals every other echo AND the compilation's IR.
    assert Enum.uniq(echoes) == [compiled.ir]
    assert Enum.uniq(Enum.map(echoes, & &1.digest)) == [compiled.ir.digest]
    assert map_size(compiled.sections) == 5
  end

  # ---------------------------------------------------------------------------
  # Law 3: recompile re-discovers only when forced.
  # ---------------------------------------------------------------------------

  test "DiscoverOnce 3: recompile re-discovers only when forced" do
    counter = {:discover_reads, :recompile_law}
    source = counting_reader(counter, [:recompile_probe_a, :recompile_probe_b])

    first = Compiler.compile(source)
    assert first.reads == 1
    assert Process.get(counter, 0) == 1

    # Unforced recompile: memoized, zero reads, identical normalized term.
    second = Compiler.compile(source)
    assert second.reads == 0
    assert Process.get(counter, 0) == 1
    assert second.ir == first.ir

    # Forced recompile: exactly one more discovery, same normalized term.
    forced = Compiler.compile(source, force: true)
    assert forced.reads == 1
    assert Process.get(counter, 0) == 2
    assert forced.ir == first.ir
  end

  # ---------------------------------------------------------------------------
  # Falsifier: the memo keys on the exact source — distinct sources never
  # share a discovery, so caching cannot hide a genuine new read.
  # ---------------------------------------------------------------------------

  test "distinct sources never share a discovery" do
    counter = {:discover_reads, :distinct_sources}
    a = counting_reader(counter, [:distinct_probe_a])
    b = counting_reader(counter, [:distinct_probe_b])

    Compiler.compile(a)
    Compiler.compile(b)

    assert Process.get(counter, 0) == 2
  end

  # ---------------------------------------------------------------------------
  # Falsifier: malformed sources and inadmitted transports are refused at
  # the single discovery pass, never silently coerced.
  # ---------------------------------------------------------------------------

  test "malformed declarations are refused inside discovery" do
    assert_raise ArgumentError, ~r/zero-arity reader fun or an action declaration list/, fn ->
      Compiler.compile(%{not: :a_source})
    end

    assert_raise ArgumentError, ~r/atom :action/, fn ->
      Compiler.compile([{:carrier_pigeon_is_not_admitted, 1}])
    end

    assert_raise ArgumentError, ~r/inadmitted transport/, fn ->
      Compiler.compile([%{action: :probe, transport: :carrier_pigeon}])
    end
  end

  defp counting_reader(counter, actions) do
    fn ->
      Process.put(counter, Process.get(counter, 0) + 1)
      actions
    end
  end
end
