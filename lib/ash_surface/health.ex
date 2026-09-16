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

  ## Health is OBSERVE-only

  Every function in this module is an observation. Health never mutates node
  state (no application environment writes, no ETS table creation, no process
  spawning, no file writes) and carries zero DO authority: every report is
  tagged `authority_boundary: :OBSERVE` and `to_map/1` serializes that tag as
  the literal `"OBSERVE"`.

  ## Surface status taxonomy

  `check_surface/2` assesses an exact, already-verified `AshSurface.Surface`
  against the real runtime it declares a dependency on, using a three-valued
  taxonomy (both checks always run; status is the worst finding, with
  `:digest_drift` outranking `:missing_runtime` because a drifted
  content-addressed identity is corruption regardless of environment):

    * `:healthy` — the JavaScript runtime adapter is present on disk and the
      surface's stored digest still equals the digest recomputed from its
      contract.
    * `:missing_runtime` — the runtime adapter path does not resolve (pass
      `:runtime_path` to observe an alternate install location).
    * `:digest_drift` — the stored `surface.digest` no longer matches the
      contract actually held, so the surface's identity claim is false.

  `check_surface/2` is deterministic: identical surface + identical options
  always produce structurally identical reports (no wall clock, no randomness),
  which makes reports diffable and cacheable by callers.
  """

  @required_apps [:ash_surface, :ash, :spark, :jason]

  @digest_algorithm "sha256-canonical-term"

  @type check_result :: %{
          name: atom(),
          status: :ok | :error,
          detail: term()
        }

  @type report :: %{
          status: :ok | :degraded,
          authority_boundary: :OBSERVE,
          checks: [check_result()],
          checked_at: DateTime.t()
        }

  @type surface_status :: :healthy | :missing_runtime | :digest_drift

  @type surface_report :: %{
          status: surface_status(),
          subject: String.t(),
          authority_boundary: :OBSERVE,
          checks: [check_result()]
        }

  @type refusal :: %{
          standing: :REFUSED_INVALID_SUBJECT | :REFUSED_INVALID_OPTION,
          reason: term(),
          authority_boundary: :OBSERVE
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

    report = %{
      status: status,
      authority_boundary: :OBSERVE,
      checks: checks,
      checked_at: DateTime.utc_now()
    }

    if status == :ok, do: {:ok, report}, else: {:error, report}
  end

  @doc """
  OBSERVE-only health assessment of an exact surface against the real runtime.

  Returns `{:ok, report}` when the surface is `:healthy`, or `{:error, report}`
  carrying the worst finding (`:digest_drift` outranks `:missing_runtime`).
  Both the runtime-presence and digest-integrity checks always run and always
  appear in the report — observation never short-circuits.

  Options:

    * `:runtime_path` — binary path to the JavaScript runtime adapter to
      observe (defaults to `AshSurface.runtime_path/0`).

  Refuses (as `{:error, refusal}`) without raising when the subject is not an
  `%AshSurface.Surface{}` (`:REFUSED_INVALID_SUBJECT`) or when
  `:runtime_path` is not a binary (`:REFUSED_INVALID_OPTION`).
  """
  @spec check_surface(AshSurface.Surface.t(), keyword()) ::
          {:ok, surface_report()} | {:error, surface_report() | refusal()}
  def check_surface(surface, opts \\ [])

  def check_surface(%AshSurface.Surface{} = surface, opts) do
    with :ok <- validate_runtime_path_option(opts) do
      runtime_path = Keyword.get(opts, :runtime_path, AshSurface.runtime_path())

      checks = [runtime_check(runtime_path), digest_check(surface)]

      status = classify(checks)

      report = %{
        status: status,
        subject: surface.digest,
        authority_boundary: :OBSERVE,
        checks: checks
      }

      if status == :healthy, do: {:ok, report}, else: {:error, report}
    end
  end

  def check_surface(_invalid_subject, _opts) do
    {:error,
     %{
       standing: :REFUSED_INVALID_SUBJECT,
       reason: :surface_struct_required,
       authority_boundary: :OBSERVE
     }}
  end

  @doc """
  Serializes a readiness or surface health report into a JSON-normalized map.

  Both report kinds carry `"authorityBoundary" => "OBSERVE"` so downstream
  consumers can rely on the zero-DO-authority tag in serialized form. Detail
  keys and atom values are normalized to strings, so the result is exactly the
  JSON shape: `Jason.decode(Jason.encode!(to_map(report))) == to_map(report)`.
  """
  @spec to_map(report() | surface_report()) :: map()
  def to_map(%{checked_at: %DateTime{} = checked_at, status: status, checks: checks}) do
    %{
      "status" => to_string(status),
      "authorityBoundary" => "OBSERVE",
      "checkedAt" => DateTime.to_iso8601(checked_at),
      "checks" => Enum.map(checks, &check_to_map/1)
    }
  end

  def to_map(%{subject: subject, status: status, checks: checks}) do
    %{
      "status" => to_string(status),
      "authorityBoundary" => "OBSERVE",
      "subject" => subject,
      "checks" => Enum.map(checks, &check_to_map/1)
    }
  end

  defp check_to_map(%{name: name, status: status, detail: detail}) do
    %{
      "name" => to_string(name),
      "status" => to_string(status),
      "detail" => json_shape(detail)
    }
  end

  # Deep normalization to the exact JSON isomorphism: string keys, atom values
  # (status atoms like :enoent, app names) become strings; binaries, numbers,
  # booleans, and nil pass through unchanged.
  defp json_shape(value) when is_binary(value) or is_number(value) or is_nil(value), do: value
  defp json_shape(value) when is_boolean(value) or is_atom(value), do: to_string(value)
  defp json_shape(value) when is_list(value), do: Enum.map(value, &json_shape/1)

  defp json_shape(value) when is_map(value) do
    value |> Enum.map(fn {key, item} -> {json_shape(key), json_shape(item)} end) |> Map.new()
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

  # Observation only: validate the caller-supplied observation target without
  # touching anything.
  defp validate_runtime_path_option(opts) do
    case Keyword.fetch(opts, :runtime_path) do
      {:ok, path} when is_binary(path) ->
        :ok

      {:ok, other} ->
        {:error,
         %{
           standing: :REFUSED_INVALID_OPTION,
           reason: {:runtime_path_must_be_binary, other},
           authority_boundary: :OBSERVE
         }}

      :error ->
        :ok
    end
  end

  # Observe (never write): does the JavaScript runtime adapter the surface
  # depends on actually resolve on this install?
  defp runtime_check(path) do
    case File.stat(path) do
      {:ok, %{size: bytes}} ->
        %{name: :runtime_present, status: :ok, detail: %{path: path, bytes: bytes}}

      {:error, reason} ->
        %{name: :runtime_present, status: :error, detail: %{path: path, reason: reason}}
    end
  end

  # Observe (never write): does the stored digest still content-address the
  # contract actually held? This mirrors AshSurface's canonical term digest;
  # agreement is pinned by tests against freshly built real surfaces.
  defp digest_check(%AshSurface.Surface{} = surface) do
    recomputed = content_digest(surface.contract)

    %{
      name: :digest_integrity,
      status: if(recomputed == surface.digest, do: :ok, else: :error),
      detail: %{
        stored: surface.digest,
        recomputed: recomputed,
        algorithm: @digest_algorithm
      }
    }
  end

  defp classify(checks) do
    failed = checks |> Enum.reject(&(&1.status == :ok)) |> MapSet.new(& &1.name)

    cond do
      MapSet.member?(failed, :digest_integrity) -> :digest_drift
      MapSet.member?(failed, :runtime_present) -> :missing_runtime
      true -> :healthy
    end
  end

  defp content_digest(contract) do
    contract
    |> canonical_term()
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp canonical_term(term) when is_map(term) do
    term
    |> Enum.map(fn {key, value} -> {to_string(key), canonical_term(value)} end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  defp canonical_term(term) when is_list(term), do: Enum.map(term, &canonical_term/1)
  defp canonical_term(term), do: term
end
