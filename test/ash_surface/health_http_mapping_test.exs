defmodule AshSurface.HealthHttpMappingTest do
  @moduledoc """
  Health 200/503 HTTP mapping over a real Plug request path.

  `ash_surface` is a library with no endpoint/router of its own
  (`AshSurface.Health` moduledoc names the exact hosting-app wrap: `{:ok, _}`
  -> `200`, `{:error, _}` -> `503`). This court sends REAL requests through a
  real Plug router — `Plug.Test` connections over the actual router pipeline,
  no mocks — pinning that the documented mapping holds for the healthy path
  and for real degraded findings (`:missing_runtime`, `:digest_drift`) and
  the typed `:REFUSED_INVALID_SUBJECT` refusal.
  """

  use ExUnit.Case, async: false

  alias Ash.Info.Manifest
  alias Ash.Info.Manifest.{Action, Entrypoint}
  alias AshSurface.Health

  defmodule Milestone do
    @moduledoc "Real Ash resource backing the manifest under observation."
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

  defmodule Router do
    @moduledoc "The hosting-app wrap documented verbatim in AshSurface.Health."
    use Plug.Router

    plug(:match)
    plug(:dispatch)

    get "/health" do
      case Health.check() do
        {:ok, report} ->
          conn |> put_resp_content_type("application/json") |> send_resp(200, Jason.encode!(Health.to_map(report)))

        {:error, report} ->
          conn |> put_resp_content_type("application/json") |> send_resp(503, Jason.encode!(Health.to_map(report)))
      end
    end

    get "/surface-health/healthy" do
      wrap(conn, AshSurface.HealthHttpMappingTest.surface(:healthy), [])
    end

    get "/surface-health/drifted" do
      wrap(conn, AshSurface.HealthHttpMappingTest.surface(:drifted), [])
    end

    get "/surface-health/missing-runtime" do
      wrap(conn, AshSurface.HealthHttpMappingTest.surface(:healthy),
        runtime_path: "/nonexistent/w326/ash_surface_runtime.mjs"
      )
    end

    get "/surface-health/not-a-surface" do
      case Health.check_surface(:not_a_surface_struct) do
        {:error, refusal} ->
          conn |> put_resp_content_type("application/json") |> send_resp(503, Jason.encode!(refusal))
      end
    end

    defp wrap(conn, surface, opts) do
      case Health.check_surface(surface, opts) do
        {:ok, report} ->
          conn |> put_resp_content_type("application/json") |> send_resp(200, Jason.encode!(Health.to_map(report)))

        {:error, report} ->
          conn |> put_resp_content_type("application/json") |> send_resp(503, Jason.encode!(Health.to_map(report)))
      end
    end

    match _ do
      send_resp(conn, 404, "not found")
    end
  end

  @doc false
  def surface(:healthy) do
    {:ok, surface} =
      AshSurface.from_manifest(manifest(),
        profile: %{
          audience: :web,
          actions: %{"AshSurface.HealthHttpMappingTest.Milestone#read" => %{consumer: :web}}
        }
      )

    surface
  end

  def surface(:drifted) do
    healthy = surface(:healthy)
    %{healthy | digest: "drifted_" <> healthy.digest}
  end

  defp manifest do
    %Manifest{
      entrypoints: [
        %Entrypoint{
          resource: Milestone,
          action: %Action{name: :record, type: :create, custom: %{}}
        },
        %Entrypoint{
          resource: Milestone,
          action: %Action{name: :read, type: :read, custom: %{}}
        }
      ]
    }
  end

  defp get(path) do
    Plug.Test.conn(:get, path)
    |> Router.call(Router.init([]))
  end

  # ---- courts --------------------------------------------------------------

  describe "GET /health (whole-runtime readiness)" do
    test "healthy check maps to 200 with a real JSON report" do
      conn = get("/health")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["status"] == "ok"
      assert body["authorityBoundary"] == "OBSERVE"
      assert length(body["checks"]) == 3
      assert Enum.all?(body["checks"], &(&1["status"] == "ok"))
    end
  end

  describe "GET /surface-health/* (per-surface health)" do
    test "healthy surface maps to 200" do
      conn = get("/surface-health/healthy")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["status"] == "healthy"
      assert body["authorityBoundary"] == "OBSERVE"
      assert Enum.all?(body["checks"], &(&1["status"] == "ok"))
    end

    test "digest_drift maps to 503 with a real degraded report" do
      conn = get("/surface-health/drifted")

      assert conn.status == 503
      body = Jason.decode!(conn.resp_body)
      assert body["status"] == "digest_drift"

      assert Enum.any?(
               body["checks"],
               &(&1["name"] == "digest_integrity" and &1["status"] == "error")
             )
    end

    test "missing_runtime maps to 503" do
      conn = get("/surface-health/missing-runtime")

      assert conn.status == 503
      body = Jason.decode!(conn.resp_body)
      assert body["status"] == "missing_runtime"
      assert Enum.any?(body["checks"], &(&1["name"] == "runtime_present" and &1["status"] == "error"))
    end

    test "a non-surface subject is the typed REFUSED_INVALID_SUBJECT refusal, mapped to 503" do
      conn = get("/surface-health/not-a-surface")

      assert conn.status == 503
      body = Jason.decode!(conn.resp_body)
      assert body["standing"] == "REFUSED_INVALID_SUBJECT"
      assert body["reason"] == "surface_struct_required"
      # The refusal map is encoded as-is (snake_case keys, per Health.check_surface/2).
      assert body["authority_boundary"] == "OBSERVE"
    end
  end
end
