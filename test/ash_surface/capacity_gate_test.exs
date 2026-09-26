defmodule AshSurface.CapacityGateTest do
  @moduledoc """
  Enforcement anchor for the 並 capacity law rows (ontology.ttl v26.9.17,
  ticket gapfix-ontology-promo-017).

  The anchor proper is `scripts/capacity_gate.sh` (surf:enforcedBy). These
  tests keep the anchor honest: they exercise the gate's semantics directly
  (rider exemption, the ceiling boundary at surf:capacityCeiling, fail-closed
  telemetry) so the gate cannot drift from the law row silently.
  """

  use ExUnit.Case, async: true

  @gate "scripts/capacity_gate.sh"
  @ceiling 16

  defp run_gate(log_path) do
    System.cmd("bash", [@gate], env: [{"CAPACITY_RIDE_LOG", log_path}], stderr_to_stdout: true)
  end

  defp run_gate_at_default_path do
    System.cmd("bash", [@gate], stderr_to_stdout: true)
  end

  defp temp_log(rows) do
    dir = Path.join(System.tmp_dir!(), "capacity-gate-test-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    path = Path.join(dir, "log.ndjson")

    if rows == [] do
      File.write!(path, "")
    else
      content = rows |> Enum.map(&Jason.encode!/1) |> Enum.join("\n")
      File.write!(path, content <> "\n")
    end

    path
  end

  defp observation(overrides) do
    Map.merge(
      %{
        "ts" => "2026-09-17T00:00:00Z",
        "tier" => "flash",
        "weight" => "heavyweight",
        "target_n" => 9,
        "rider" => false
      },
      Map.new(overrides, fn {k, v} -> {Atom.to_string(k), v} end)
    )
  end

  test "gate script exists" do
    assert File.exists?(@gate)
  end

  test "absent telemetry log exits 0 (gate is green at a HEAD without capacity-ride logging)" do
    missing =
      Path.join(
        System.tmp_dir!(),
        "capacity-gate-no-such-log-#{System.unique_integer([:positive])}"
      )

    {output, status} = run_gate(missing)
    assert status == 0
    assert output =~ "nothing to falsify"
  end

  test "empty telemetry log exits 0" do
    {output, status} = run_gate(temp_log([]))
    assert status == 0
    assert output =~ "OK"
  end

  test "rider rows are exempt from the ceiling (surf:RiderSetpointLaw)" do
    {output, status} = run_gate(temp_log([observation(rider: true, target_n: 100)]))
    assert status == 0
    assert output =~ "1 rider row(s) exempt"
  end

  test "non-rider row exactly at the ceiling (#{@ceiling}) passes" do
    {output, status} = run_gate(temp_log([observation(rider: false, target_n: @ceiling)]))
    assert status == 0
    assert output =~ "OK"
  end

  test "non-rider row above the ceiling (#{@ceiling + 1}) fails" do
    {output, status} = run_gate(temp_log([observation(rider: false, target_n: @ceiling + 1)]))
    assert status == 1
    assert output =~ "VIOLATION"
  end

  test "one violating row among passing rows fails the whole gate" do
    rows = [
      observation(target_n: 9),
      observation(target_n: @ceiling + 1),
      observation(rider: true, target_n: 40)
    ]

    {_output, status} = run_gate(temp_log(rows))
    assert status == 1
  end

  test "non-rider row with missing target_n fails closed" do
    row = Map.delete(observation([]), "target_n")
    {output, status} = run_gate(temp_log([row]))
    assert status == 1
    assert output =~ "non-numeric target_n"
  end

  test "malformed telemetry line fails closed (no fabricated pass)" do
    {output, status} = run_gate(malformed_log())
    assert status == 1
    assert output =~ "malformed telemetry"
  end

  test "default-path run at HEAD exits 0" do
    {_output, status} = run_gate_at_default_path()
    assert status == 0
  end

  defp malformed_log do
    dir = Path.join(System.tmp_dir!(), "capacity-gate-test-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    path = Path.join(dir, "log.ndjson")
    File.write!(path, "{\"target_n\": 9, \"rider\": false\nnot json at all\n")
    path
  end
end
