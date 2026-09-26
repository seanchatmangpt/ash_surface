defmodule AshSurface.MXEpisode do
  @moduledoc """
  Composed Machine Experience (MX) closed-loop episode (mx-episode-schema@v26.9.17).

  `compose/1` binds the already-content-addressed parts of one closed loop —
  the observation digest, the PlanningEpisode, the MX receipt hash, the Event,
  the admitted `AshSurface.Surface` digest, and the repo/head + CalVer
  identities — into the episode shape frozen at
  `test/ash_surface/mx_closed_loop_episode_test.exs` (step 8): the thirteen
  top-level mx-episode-schema fields. `observed_transitions` carries one
  content-addressed witness per `selected_decomposition` step, extending the
  repo's own deep-test binding precedent (observe + actuate + emit_event) with
  project_candidates and authorize_candidate so every decomposition step is
  witnessed (finish-experience-023).

  The mx-episode-schema verifier is vendored in-repo at
  `priv/verifier/verify_closure_episode.py` (re-bound from repo-closure@v26.9.13
  to v26.9.17). `verify_file/1` and `verify/1` run it unconditionally: the
  previous arrangement pointed tests at an external marketplace checkout
  guarded by `if File.exists?/1`, where an absent checkout silently skipped the
  independent check (fail-open). There is no external dependency and no skip
  path. `validate/1` mirrors the same schema law in pure Elixir.
  """

  alias AshSurface.Event
  alias AshSurface.Observation
  alias AshSurface.PlanningEpisode
  alias AshSurface.Surface

  @calver "v" <> AshSurface.schema_version()
  @verifier_relative_path "priv/verifier/verify_closure_episode.py"

  @required_compose_keys ~w(observation planning_episode event surface receipt_hash
    subject_repo subject_head consequence_id)a

  @required_fields ~w(episode_id subject_repo subject_head pattern_version
    domain_version hddl_version fond_version verifier_version
    selected_decomposition observed_transitions cost_score receipt_hash
    resulting_standing)a

  @calver_fields ~w(pattern_version domain_version hddl_version fond_version
    verifier_version)a

  @standings ~w(ALIVE PARTIAL_ALIVE BLOCKED BUILD_BROKEN UNSUPPORTED)

  @selected_decomposition ~w(observe_state project_candidates authorize_candidate
    actuate_brce emit_event)

  @typedoc "A composed mx-episode-schema record: a JSON-ready string-keyed map."
  @type episode :: %{optional(String.t()) => term()}

  @type verify_result ::
          {:ok, :valid}
          | {:error, {code :: String.t(), message :: String.t()}}
          | {:error, term()}

  @doc "The CalVer identity bound into every composed episode (v-prefixed)."
  @spec calver() :: String.t()
  def calver, do: @calver

  @doc "The thirteen mx-episode-schema required top-level fields (string names)."
  @spec required_fields() :: [String.t()]
  def required_fields, do: Enum.map(@required_fields, &Atom.to_string/1)

  @doc "The frozen five-step decomposition each observed transition witnesses."
  @spec selected_decomposition() :: [String.t()]
  def selected_decomposition, do: @selected_decomposition

  @doc """
  Path of the vendored mx-episode-schema verifier inside this OTP application.
  """
  @spec verifier_path() :: String.t()
  def verifier_path, do: Application.app_dir(:ash_surface, @verifier_relative_path)

  @doc """
  Composes the closed-loop episode from its already-content-addressed parts.

  Required input keys: `:observation` (%AshSurface.Observation{}),
  `:planning_episode` (%AshSurface.PlanningEpisode{}), `:event`
  (%AshSurface.Event{}), `:surface` (%AshSurface.Surface{}), `:receipt_hash`
  (the MX dispatch receipt's content-addressed hash), `:subject_repo`,
  `:subject_head`, and `:consequence_id` (the Ash record id the actuate step
  produced). Optional: `:episode_id`, or `:date` + `:sequence` to compose the
  default `MXEpisode/<UTC-date>/<zero-padded sequence>` identity;
  `:resulting_standing` (default `"ALIVE"`); `:cost_score` (default `1.0`).
  Atom or string keys are both accepted.

  The composed episode must satisfy the loop's binding law: the emitted event's
  `subject_ref` equals the observation's `exact_subject`, and the surface
  digest is the 64-hex content address. Anything else is refused — never
  silently composed.

  ## Examples

      iex> observation = AshSurface.Observation.create("sp:ticket:42", %{"status" => "open"})
      iex> planning = AshSurface.PlanningEpisode.create("ws:42", planner_identity: "ash_pplan", policy_identity: "pol:1")
      iex> event = AshSurface.Event.create(observation.exact_subject, 1, "state.changed")
      iex> surface = %AshSurface.Surface{manifest: %{}, contract: %{}, action_ids: [],
      ...> digest: :crypto.hash(:sha256, "surface-bytes") |> Base.encode16(case: :lower)}
      iex> {:ok, episode} = AshSurface.MXEpisode.compose(%{
      ...> observation: observation,
      ...> planning_episode: planning,
      ...> event: event,
      ...> surface: surface,
      ...> receipt_hash: String.duplicate("7", 64),
      ...> subject_repo: "zoela_phx",
      ...> subject_head: "9a1b2c",
      ...> consequence_id: "t1",
      ...> episode_id: "MXEpisode/2026-09-17/000042"})
      iex> {episode["episode_id"], episode["resulting_standing"], episode["cost_score"]}
      {"MXEpisode/2026-09-17/000042", "ALIVE", 1.0}
      iex> Enum.map(episode["observed_transitions"], & &1["step"])
      ["observe", "project_candidates", "authorize_candidate", "actuate", "emit_event"]
      iex> [observe, _, authorize, actuate, emit] = episode["observed_transitions"]
      iex> {observe["state_digest"] == observation.state_digest, authorize["surface_digest"] == surface.digest, actuate["consequence_id"], emit["subject_ref"]}
      {true, true, "t1", "sp:ticket:42"}

      Missing parts are refused, never silently composed:

      iex> AshSurface.MXEpisode.compose(%{"observation" => "not-a-struct"})
      {:error, {:missing_compose_fields, [:planning_episode, :event, :surface, :receipt_hash, :subject_repo, :subject_head, :consequence_id]}}

      An event unbound to the observation's exact subject violates the loop's
      binding law (each example is self-contained):

      iex> observation = AshSurface.Observation.create("sp:ticket:42", %{"status" => "open"})
      iex> unbound = AshSurface.Event.create("sp:other", 1, "state.changed")
      iex> surface = %AshSurface.Surface{manifest: %{}, contract: %{}, action_ids: [], digest: String.duplicate("a", 64)}
      iex> planning = AshSurface.PlanningEpisode.create("ws:42", planner_identity: "ash_pplan", policy_identity: "pol:1")
      iex> AshSurface.MXEpisode.compose(%{observation: observation, planning_episode: planning, event: unbound, surface: surface, receipt_hash: "r", subject_repo: "r", subject_head: "h", consequence_id: "c"})
      {:error, {:subject_binding_violation, "sp:other"}}
  """
  @spec compose(term()) :: {:ok, episode()} | {:error, term()}
  def compose(input)

  def compose(input) when is_map(input) do
    with {:ok, input} <- require_keys(input),
         {:ok, observation} <- fetch_struct(input, :observation, Observation),
         {:ok, planning_episode} <- fetch_struct(input, :planning_episode, PlanningEpisode),
         {:ok, event} <- fetch_struct(input, :event, Event),
         {:ok, surface} <- fetch_struct(input, :surface, Surface),
         {:ok, receipt_hash} <- fetch_binary(input, :receipt_hash),
         {:ok, subject_repo} <- fetch_binary(input, :subject_repo),
         {:ok, subject_head} <- fetch_binary(input, :subject_head),
         {:ok, consequence_id} <- fetch_binary(input, :consequence_id),
         :ok <- verify_subject_binding(observation, event),
         :ok <- verify_surface_digest(surface),
         {:ok, standing} <- fetch_standing(input),
         {:ok, cost_score} <- fetch_cost_score(input),
         {:ok, episode_id} <- fetch_episode_id(input) do
      {:ok,
       %{
         "episode_id" => episode_id,
         "subject_repo" => subject_repo,
         "subject_head" => subject_head,
         "pattern_version" => @calver,
         "domain_version" => @calver,
         "hddl_version" => @calver,
         "fond_version" => @calver,
         "verifier_version" => @calver,
         "selected_decomposition" => @selected_decomposition,
         "observed_transitions" => [
           %{"step" => "observe", "state_digest" => observation.state_digest},
           %{
             "step" => "project_candidates",
             "planning_episode_id" => planning_episode.episode_id,
             "authority_ceiling" => Atom.to_string(planning_episode.authority_ceiling)
           },
           %{
             "step" => "authorize_candidate",
             "surface_digest" => surface.digest,
             "marketplace_identity" => surface.contract["marketplaceIdentity"]
           },
           %{"step" => "actuate", "outcome" => "pass", "consequence_id" => consequence_id},
           %{
             "step" => "emit_event",
             "event_id" => event.event_id,
             "subject_ref" => event.subject_ref,
             "state_digest" => event.state_digest
           }
         ],
         "cost_score" => cost_score,
         "receipt_hash" => receipt_hash,
         "resulting_standing" => standing
       }}
    end
  end

  def compose(input), do: {:error, {:compose_input_must_be_a_map, input}}

  @doc """
  Pure-Elixir mirror of the vendored mx-episode-schema law: required fields,
  CalVer bindings, and the standing vocabulary. Takes the JSON-shaped
  (string-keyed) episode.
  """
  @spec validate(term()) :: :ok | {:error, term()}
  def validate(episode) when is_map(episode) do
    present = Map.keys(episode) |> Enum.map(&key_string/1)
    missing = Enum.sort(required_fields() -- present)

    cond do
      missing != [] ->
        {:error, {:missing_fields, missing}}

      true ->
        calver_drift(episode) || standing_check(episode)
    end
  end

  def validate(_episode), do: {:error, :episode_must_be_a_map}

  @doc """
  Runs the vendored in-repo mx-episode-schema verifier against a JSON file.

  `{:ok, :valid}` only when the verifier exits 0 and reports VALID. Any other
  verifier code is an `{:error, {code, message}}` — never skipped, never
  approximated.
  """
  @spec verify_file(String.t()) :: verify_result()
  def verify_file(episode_path) when is_binary(episode_path) do
    with {:ok, python} <- python_executable(),
         {output, exit_code} <-
           System.cmd(python, [verifier_path(), episode_path], stderr_to_stdout: true) do
      report_verifier_result(output, exit_code)
    end
  end

  @doc """
  Encodes an episode to JSON and runs the vendored in-repo verifier on it
  (round trip). Same result contract as `verify_file/1`.
  """
  @spec verify(term()) :: verify_result()
  def verify(episode) when is_map(episode) do
    tmp_path =
      Path.join(System.tmp_dir(), "mx_episode_verify-#{:erlang.unique_integer([:positive])}.json")

    File.write!(tmp_path, Jason.encode!(episode))

    try do
      verify_file(tmp_path)
    after
      File.rm(tmp_path)
    end
  end

  def verify(episode), do: {:error, {:episode_must_be_a_map, episode}}

  # ---------------------------------------------------------------------------
  # compose internals
  # ---------------------------------------------------------------------------

  defp require_keys(input) do
    missing = Enum.filter(@required_compose_keys, fn key -> fetch(input, key) == :error end)

    if missing == [] do
      {:ok, input}
    else
      {:error, {:missing_compose_fields, missing}}
    end
  end

  defp fetch_struct(input, key, module) do
    with {:ok, value} <- fetch(input, key) do
      if is_struct(value, module) do
        {:ok, value}
      else
        {:error, {:invalid_compose_input, key, module}}
      end
    end
  end

  defp fetch_binary(input, key) do
    case fetch(input, key) do
      {:ok, value} when is_binary(value) -> {:ok, value}
      {:ok, value} -> {:error, {:invalid_compose_input, key, {:expected_binary, value}}}
      :error -> {:error, {:missing_compose_fields, [key]}}
    end
  end

  # The loop's subject-binding law (deep-test precedent): every emitted event
  # binds back to the observation's exact subject.
  defp verify_subject_binding(%Observation{} = observation, %Event{} = event) do
    if event.subject_ref == observation.exact_subject do
      :ok
    else
      {:error, {:subject_binding_violation, event.subject_ref}}
    end
  end

  # The surface digest is a content address; an episode must never bind a
  # non-canonical one.
  defp verify_surface_digest(%Surface{digest: digest}) do
    if is_binary(digest) and digest =~ ~r/^[0-9a-f]{64}$/ do
      :ok
    else
      {:error, {:invalid_surface_digest, digest}}
    end
  end

  defp fetch_standing(input) do
    value =
      case fetch(input, :resulting_standing) do
        {:ok, atom} when is_atom(atom) -> Atom.to_string(atom)
        {:ok, other} -> other
        :error -> "ALIVE"
      end

    if value in @standings do
      {:ok, value}
    else
      {:error, {:invalid_standing, value}}
    end
  end

  defp fetch_cost_score(input) do
    case fetch(input, :cost_score) do
      {:ok, score} when is_number(score) -> {:ok, score}
      {:ok, other} -> {:error, {:invalid_compose_input, :cost_score, {:expected_number, other}}}
      :error -> {:ok, 1.0}
    end
  end

  defp fetch_episode_id(input) do
    case fetch(input, :episode_id) do
      {:ok, id} when is_binary(id) -> {:ok, id}
      {:ok, other} -> {:error, {:invalid_compose_input, :episode_id, {:expected_binary, other}}}
      :error -> {:ok, default_episode_id(input)}
    end
  end

  defp default_episode_id(input) do
    date =
      case fetch(input, :date) do
        {:ok, %Date{} = date} -> Date.to_iso8601(date)
        {:ok, string} when is_binary(string) -> string
        _ -> Date.utc_today() |> Date.to_iso8601()
      end

    sequence =
      case fetch(input, :sequence) do
        {:ok, number} when is_integer(number) and number >= 0 ->
          number |> Integer.to_string() |> String.pad_leading(6, "0")

        _ ->
          "000001"
      end

    "MXEpisode/#{date}/#{sequence}"
  end

  # Atom-key input is canonical; string-key input is the JSON dialect.
  defp fetch(input, key) when is_atom(key) do
    case Map.fetch(input, key) do
      {:ok, _} = ok -> ok
      :error -> Map.fetch(input, Atom.to_string(key))
    end
  end

  # ---------------------------------------------------------------------------
  # validate internals (pure-Elixir mx-episode-schema mirror)
  # ---------------------------------------------------------------------------

  defp calver_drift(episode) do
    Enum.find_value(@calver_fields, fn field ->
      name = Atom.to_string(field)
      value = Map.get(episode, name)

      if value == @calver, do: nil, else: {:error, {:calver_mismatch, name, value}}
    end)
  end

  defp standing_check(episode) do
    standing = Map.get(episode, "resulting_standing")

    if standing in @standings, do: :ok, else: {:error, {:invalid_standing, standing}}
  end

  defp key_string(key) when is_binary(key), do: key
  defp key_string(key) when is_atom(key), do: Atom.to_string(key)
  defp key_string(key), do: inspect(key)

  # ---------------------------------------------------------------------------
  # verifier plumbing (vendored in-repo: no external checkout, no skip)
  # ---------------------------------------------------------------------------

  defp python_executable do
    if executable = Enum.find(["python3.11", "python3"], &System.find_executable/1) do
      {:ok, executable}
    else
      {:error, :verifier_python_not_found}
    end
  end

  defp report_verifier_result(output, exit_code) do
    case parse_verifier_output(output) do
      {"VALID", _message} when exit_code == 0 -> {:ok, :valid}
      {"VALID", _message} -> {:error, {:verifier_failed, exit_code, output}}
      {code, message} -> {:error, {code, message}}
      :error -> {:error, {:verifier_unparseable, exit_code, output}}
    end
  end

  defp parse_verifier_output(output) do
    case Regex.run(~r/\[([A-Z_]+)\]\s*(.*)/, String.trim(output)) do
      [_, code, message] -> {code, String.trim(message)}
      _ -> :error
    end
  end
end
