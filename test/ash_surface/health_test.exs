defmodule AshSurface.HealthTest do
  use ExUnit.Case, async: true

  alias AshSurface.Health

  test "check/0 reports ok with all real checks passing in the test runtime" do
    assert {:ok, report} = Health.check()
    assert report.status == :ok
    assert length(report.checks) == 3
    assert Enum.all?(report.checks, &(&1.status == :ok))
    assert %DateTime{} = report.checked_at
  end

  test "ready?/0 reflects the real check/0 outcome" do
    assert Health.ready?() == match?({:ok, _}, Health.check())
  end

  test "applications_started check lists the real required apps" do
    {:ok, report} = Health.check()
    apps_check = Enum.find(report.checks, &(&1.name == :applications_started))
    assert apps_check.detail.required == [:ash_surface, :ash, :spark, :jason]
    assert apps_check.detail.missing == []
  end

  test "transport_module check performs a real AshSurface.Transport.select/3 call" do
    {:ok, report} = Health.check()
    transport_check = Enum.find(report.checks, &(&1.name == :transport_module))
    assert transport_check.status == :ok
    assert transport_check.detail.selected == :http
  end
end
