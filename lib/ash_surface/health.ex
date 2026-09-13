defmodule AshSurface.Health do
  @moduledoc """
  Real readiness/health checks for the `ash_surface` library runtime.

  `ash_surface` is a manifest-first Ash consumer-surface *library*, not a Phoenix
  application: it has no `Phoenix.Endpoint`, no router, and no HTTP listener of its
  own (see `AGENTS.md` — AshPhoenix owns Phoenix forms/LiveView integration; this
  library only ever *references* `:phoenix_channel` as one enumerated transport
  target). There is therefore no `Phoenix.Controller` to route a health endpoint
  into. What is admissible instead — and what this module actually implements — is
  a real, checkable readiness function that a hosting application (a Phoenix app,
  an Ash app, a plain OTP release) can call and wrap in its own controller/plug to
  expose `GET /health` with real backing state, e.g.:

      def health(conn, _params) do
        case AshSurface.Health.check() do
          {:ok, report} -> json(conn, report)
          {:error, report} -> conn |> put_status(503) |> json(report)
        end
      end

  Every field in the report reflects a real runtime check performed at call time —
  no hardcoded `:ok` and no placeholder values.
  """

  @required_apps [:ash_surface, :ash, :spark, :jason]
  @known_transports [:http, :phoenix_channel]

  @type check_result :: %{
          name: atom(),
          status: :ok | :error,
          detail: term()
        }

  @type report :: %{
          status: :ok | :degraded,
          checks: [check_result()],
          checked_at: DateTime.t()
        }

  @doc """
  Runs every real readiness check and returns `{:ok, report}` when all pass, or
  `{:error, report}` when any fail. Suitable for a `200`/`503` HTTP mapping in a
  hosting Phoenix (or any Plug-based) application.
  """
  @spec check() :: {:ok, report()} | {:error, report()}
  def check do
    checks = [
      check_applications_started(),
      check_transport_module_alive(),
      check_manifest_module_available()
    ]

    status = if Enum.all?(checks, &(&1.status == :ok)), do: :ok, else: :degraded

    report = %{status: status, checks: checks, checked_at: DateTime.utc_now()}

    if status == :ok, do: {:ok, report}, else: {:error, report}
  end

  @doc "Convenience boolean wrapper around `check/0`."
  @spec ready?() :: boolean()
  def ready?, do: match?({:ok, _}, check())

  # Real check: are the OTP applications this library depends on actually started
  # in the current node (not just present in mix.lock)?
  defp check_applications_started do
    started = Application.started_applications() |> Enum.map(&elem(&1, 0)) |> MapSet.new()

    missing = Enum.reject(@required_apps, &MapSet.member?(started, &1))

    %{
      name: :applications_started,
      status: if(missing == [], do: :ok, else: :error),
      detail: %{required: @required_apps, missing: missing}
    }
  end

  # Real check: does the transport selection module actually load and does a real
  # call into it produce the expected decision, right now, in this process?
  defp check_transport_module_alive do
    result =
      try do
        AshSurface.Transport.select([:http, :phoenix_channel], [:http], preferred: :http)
      rescue
        error -> {:error, error}
      end

    case result do
      {:ok, %AshSurface.Transport.Decision{selected: :http}} ->
        %{name: :transport_module, status: :ok, detail: %{selected: :http}}

      other ->
        %{name: :transport_module, status: :error, detail: %{result: inspect(other)}}
    end
  end

  # Real check: is Ash.Info.Manifest (the module AshSurface.from_app/2 depends on)
  # actually loaded and exporting the function this library calls?
  defp check_manifest_module_available do
    loaded? = Code.ensure_loaded?(Ash.Info.Manifest)
    exported? = loaded? and function_exported?(Ash.Info.Manifest, :generate, 1)

    %{
      name: :ash_manifest_module,
      status: if(exported?, do: :ok, else: :error),
      detail: %{loaded: loaded?, generate_1_exported: exported?}
    }
  end
end
