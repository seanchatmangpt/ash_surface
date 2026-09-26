defmodule AshSurface.HealthDeepTest.Milestone do
  @moduledoc "Real Ash resource backing real manifest structs; no actions are run."

  use Ash.Resource,
    domain: nil,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key(:id)
    attribute(:member_id, :string, public?: true, allow_nil?: false)
  end

  actions do
    defaults([:read])

    create(:record) do
      accept([:member_id])
    end
  end
end

defmodule AshSurface.HealthDeepTest do
  @moduledoc """
  Uncovered health invariants: OBSERVE-only guarantees, the surface status
  taxonomy over real manifests, deterministic reporting, serialization shape,
  and typed refusal on invalid input. All offline: zero env/db/network.
  """

  # async: false on purpose: the OBSERVE-only snapshot below asserts on global
  # node state (persistent_term, :ets.all/0, app env). Concurrent async cases
  # legally mutate that state mid-window (lazy ETS table creation, logger
  # reconfiguration), which flipped the assertion under test.zero's scheduling.
  # Exclusivity scopes the assertion to Health's own effects.
  use ExUnit.Case, async: false

  alias Ash.Info.Manifest
  alias Ash.Info.Manifest.{Action, Entrypoint}
  alias AshSurface.Health

  @missing_runtime_path "/nonexistent/ash_surface_health_probe/ash_surface_runtime.mjs"

  defp manifest do
    %Manifest{
      entrypoints: [
        %Entrypoint{
          resource: AshSurface.HealthDeepTest.Milestone,
          action: %Action{name: :record, type: :create, custom: %{}}
        },
        %Entrypoint{
          resource: AshSurface.HealthDeepTest.Milestone,
          action: %Action{name: :read, type: :read, custom: %{}}
        }
      ]
    }
  end

  defp surface do
    {:ok, surface} =
      AshSurface.from_manifest(manifest(),
        profile: %{
          audience: :web,
          actions: %{"AshSurface.HealthDeepTest.Milestone#read" => %{consumer: :web}}
        }
      )

    surface
  end

  describe "OBSERVE-only: health never mutates node or caller state" do
    test "check/0 and check_surface/2 leave app env, persistent_term, pdict, and ETS untouched" do
      snapshot_before = node_state_snapshot()
      surface = surface()

      assert {:ok, _} = Health.check()
      assert {:ok, _} = Health.check_surface(surface)
      assert {:error, _} = Health.check_surface(surface, runtime_path: @missing_runtime_path)

      assert node_state_snapshot() == snapshot_before
    end

    test "check_surface/2 leaves the observed surface and its manifest structurally unchanged" do
      surface = surface()
      manifest_before = surface.manifest
      contract_before = surface.contract

      assert {:ok, _} = Health.check_surface(surface)

      assert surface.manifest == manifest_before
      assert surface.contract == contract_before
    end

    test "every report self-declares zero DO authority" do
      surface = surface()
      {:ok, readiness} = Health.check()
      {:ok, healthy} = Health.check_surface(surface)

      assert readiness.authority_boundary == :OBSERVE
      assert healthy.authority_boundary == :OBSERVE
    end
  end

  describe "status taxonomy over real manifests" do
    test "healthy: runtime resolves and stored digest content-addresses the contract" do
      surface = surface()

      assert {:ok, report} = Health.check_surface(surface)
      assert report.status == :healthy
      assert report.subject == surface.digest

      assert Enum.map(report.checks, & &1.name) |> Enum.sort() == [
               :digest_integrity,
               :runtime_present
             ]

      runtime = Enum.find(report.checks, &(&1.name == :runtime_present))
      assert runtime.status == :ok
      assert runtime.detail.path == AshSurface.runtime_path()
      assert is_integer(runtime.detail.bytes) and runtime.detail.bytes > 0

      digest = Enum.find(report.checks, &(&1.name == :digest_integrity))
      assert digest.status == :ok
      assert digest.detail.stored == surface.digest
      assert digest.detail.recomputed == surface.digest
      assert digest.detail.algorithm == "sha256-canonical-term"
    end

    test "missing_runtime: absent runtime adapter degrades without short-circuiting the digest check" do
      surface = surface()

      assert {:error, report} = Health.check_surface(surface, runtime_path: @missing_runtime_path)
      assert report.status == :missing_runtime

      runtime = Enum.find(report.checks, &(&1.name == :runtime_present))
      assert runtime.status == :error
      assert runtime.detail.path == @missing_runtime_path
      assert runtime.detail.reason == :enoent

      digest = Enum.find(report.checks, &(&1.name == :digest_integrity))
      assert digest.status == :ok
    end

    test "digest_drift: a stored digest that no longer addresses the contract is corruption" do
      surface = surface()
      drifted = %{surface | digest: String.duplicate("0", 64)}

      assert {:error, report} = Health.check_surface(drifted)
      assert report.status == :digest_drift
      assert report.subject == drifted.digest

      digest = Enum.find(report.checks, &(&1.name == :digest_integrity))
      assert digest.status == :error
      assert digest.detail.stored == drifted.digest
      assert digest.detail.recomputed == surface.digest

      runtime = Enum.find(report.checks, &(&1.name == :runtime_present))
      assert runtime.status == :ok
    end

    test "digest_drift outranks missing_runtime when both findings hold" do
      drifted = %{surface() | digest: String.duplicate("f", 64)}

      assert {:error, report} = Health.check_surface(drifted, runtime_path: @missing_runtime_path)
      assert report.status == :digest_drift
    end
  end

  describe "deterministic reporting" do
    test "identical surface and options always produce identical reports" do
      surface = surface()

      assert {:ok, first} = Health.check_surface(surface)
      assert {:ok, second} = Health.check_surface(surface)
      assert first == second
      assert Health.to_map(first) == Health.to_map(second)
      assert Jason.encode!(Health.to_map(first)) == Jason.encode!(Health.to_map(second))
    end

    test "independently built identical surfaces yield identical reports" do
      assert {:ok, first} = Health.check_surface(surface())
      assert {:ok, second} = Health.check_surface(surface())
      assert first == second
    end

    test "readiness check/0 findings are stable across calls in an unchanged runtime" do
      findings = fn ->
        Health.check() |> elem(1) |> Map.get(:checks) |> Map.new(&{&1.name, &1.status})
      end

      assert findings.() == findings.()
    end
  end

  describe "serialization shape" do
    test "to_map/1 serializes a surface health report with exact keys and JSON round-trips" do
      {:ok, report} = Health.check_surface(surface())

      serialized = Health.to_map(report)

      assert Map.keys(serialized) |> Enum.sort() == [
               "authorityBoundary",
               "checks",
               "status",
               "subject"
             ]

      assert serialized["status"] == "healthy"
      assert serialized["authorityBoundary"] == "OBSERVE"
      assert serialized["subject"] == report.subject

      assert [%{"name" => "digest_integrity"}, %{"name" => "runtime_present"}] =
               Enum.sort_by(serialized["checks"], & &1["name"])

      assert Enum.all?(serialized["checks"], &is_binary(&1["status"]))
      assert Jason.encode!(serialized)
      assert {:ok, ^serialized} = Jason.decode(Jason.encode!(serialized))
    end

    test "to_map/1 serializes a readiness report with an ISO8601 checkedAt" do
      {:ok, report} = Health.check()

      serialized = Health.to_map(report)

      assert Map.keys(serialized) |> Enum.sort() == [
               "authorityBoundary",
               "checkedAt",
               "checks",
               "status"
             ]

      assert serialized["authorityBoundary"] == "OBSERVE"
      assert serialized["status"] == "ok"

      assert {:ok, checked_at, 0} = DateTime.from_iso8601(serialized["checkedAt"])
      assert DateTime.compare(checked_at, report.checked_at) == :eq

      assert {:ok, ^serialized} = Jason.decode(Jason.encode!(serialized))
    end

    test "degraded surface reports serialize the taxonomy without atoms leaking" do
      {:error, report} = Health.check_surface(%{surface() | digest: "drifted"})

      serialized = Health.to_map(report)

      assert serialized["status"] == "digest_drift"
      assert {:ok, ^serialized} = Jason.decode(Jason.encode!(serialized))
    end
  end

  describe "refusal on invalid input" do
    test "check_surface/2 refuses non-surface subjects with a typed, serializable refusal" do
      for invalid <- [nil, %{}, [], :surface, 42, "surface", {:ok, :surface}] do
        assert {:error, refusal} = Health.check_surface(invalid)
        assert refusal.standing == :REFUSED_INVALID_SUBJECT
        assert refusal.reason == :surface_struct_required
        assert refusal.authority_boundary == :OBSERVE
        assert Jason.encode!(refusal)
      end
    end

    test "check_surface/2 refuses non-binary runtime_path with the offending value" do
      surface = surface()

      assert {:error, refusal} = Health.check_surface(surface, runtime_path: 42)

      assert refusal.standing == :REFUSED_INVALID_OPTION
      assert refusal.reason == {:runtime_path_must_be_binary, 42}
      assert refusal.authority_boundary == :OBSERVE
    end
  end

  defp node_state_snapshot do
    %{
      app_env: Application.get_all_env(:ash_surface),
      persistent_term: :persistent_term.get(),
      process_dictionary: :erlang.process_info(self(), :dictionary),
      ets_tables: :ets.all() |> Enum.sort()
    }
  end
end
