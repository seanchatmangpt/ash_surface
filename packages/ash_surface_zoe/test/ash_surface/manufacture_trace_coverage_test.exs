defmodule AshSurface.ManufactureTraceCoverageTest do
  @moduledoc """
  Pins the admission laws of `AshSurface.ManufactureTrace.create/4`: the
  3-arity default is an empty-O* PARTIAL_ALIVE OBSERVE-only trace of
  A = mu(O*), and unknown standings and malformed reference lists are
  refused with precise `ArgumentError`s.
  """
  use ExUnit.Case, async: true

  alias AshSurface.ManufactureTrace

  test "create/3 defaults to an empty PARTIAL_ALIVE trace equal to create/4 with []" do
    trace = ManufactureTrace.create("person:1", "artifact:plan", "zoela:manufacturer")

    assert trace == ManufactureTrace.create("person:1", "artifact:plan", "zoela:manufacturer", [])
    assert trace.standing == :PARTIAL_ALIVE
    assert trace.o_star_refs == []
    assert trace.authority_boundary == :OBSERVE
    assert trace.trace_id == "mt_" <> binary_part(trace.state_digest, 0, 16)

    projected = ManufactureTrace.to_map(trace)
    assert projected["equation"] == "A=mu(O*)"
    assert projected["doAuthority"] == false
  end

  test "unknown standing is refused" do
    assert_raise ArgumentError, "unknown standing: :DONE", fn ->
      ManufactureTrace.create("s", "a", "m", standing: :DONE)
    end
  end

  test "every reference collection must be a list of strings" do
    assert_raise ArgumentError, "grounded_refs must contain only strings", fn ->
      ManufactureTrace.create("s", "a", "m", grounded_refs: [:ev_1])
    end

    assert_raise ArgumentError, "falsifiers must be a list", fn ->
      ManufactureTrace.create("s", "a", "m", falsifiers: "no receipt")
    end
  end
end
