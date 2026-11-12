defmodule AshSurface.TransportClassifyTest do
  use ExUnit.Case, async: true
  alias AshSurface.Transport

  test "pre-dispatch failures are not_dispatched with fallback open" do
    assert %{dispatch_state: :not_dispatched, failure_outcome: nil, fallback_allowed: true} =
             Transport.classify_failure(:pre_dispatch, :invalid_timeout)
  end

  test "post-dispatch failures are UNKNOWN_AFTER_DISPATCH, no fallback" do
    for cause <- [:adapter_rejected, :deadline_exceeded, :abort_after_dispatch] do
      assert %{
               dispatch_state: :dispatched,
               failure_outcome: :unknown_after_dispatch,
               fallback_allowed: false
             } = Transport.classify_failure(:post_dispatch, cause)
    end
  end

  test "unknown phase is typed error" do
    assert {:error, :unknown_phase} = Transport.classify_failure(:sideways, :x)
  end

  test "matches every transport_outcome conformance vector" do
    %{"vectors" => vs} =
      "conformance/vectors/transport_outcome.json" |> File.read!() |> Jason.decode!()

    for %{"input" => %{"phase" => ph, "cause" => c}, "expected" => %{"dispatchState" => ds} = e} <-
          vs do
      r = Transport.classify_failure(String.to_existing_atom(ph), c)
      assert Atom.to_string(r.dispatch_state) == ds
      assert r.fallback_allowed == e["fallbackAllowed"]

      assert (r.failure_outcome && r.failure_outcome |> Atom.to_string() |> String.upcase()) ==
               e["failureOutcome"]
    end
  end

  test "twin: JS runtime vocabulary names the same states and outcome" do
    script =
      ~s|import("./priv/static/ash_surface_runtime.mjs").then(m=>console.log(JSON.stringify(m.VOCABULARY)))|

    {out, 0} = System.cmd("node", ["-e", script], stderr_to_stdout: true)
    v = out |> String.trim() |> Jason.decode!()
    assert "not_dispatched" in v["dispatchStates"]
    assert "unknown_after_dispatch" in v["dispatchStates"]
    assert "UNKNOWN_AFTER_DISPATCH" in v["dispatchOutcomes"]

    pre = Transport.classify_failure(:pre_dispatch, nil)
    post = Transport.classify_failure(:post_dispatch, nil)
    assert Atom.to_string(pre.dispatch_state) in v["dispatchStates"]
    assert Atom.to_string(post.failure_outcome) in v["dispatchStates"]
    outcome = post.failure_outcome |> Atom.to_string() |> String.upcase()
    assert outcome in v["dispatchOutcomes"]
  end
end
