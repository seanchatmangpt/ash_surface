defmodule AshSurface.MixProject do
  use Mix.Project

  @version "26.9.17"
  @source_url "https://github.com/seanchatmangpt/ash_surface"

  # The only variables allowed to survive `mix test.zero`'s scrub. Anything
  # beyond toolchain discovery (PATH) and the user home (HOME) is a hidden
  # config dependency and must fail loudly under the scrubbed run.
  #
  # ASH_SURFACE_LINEAGE_GIT_DIR: optional override pointing the LIVE
  # lineage-court re-judgment (test/ash_surface/lineage_court_test.exs) at a
  # non-shallow git dir (e.g. a full clone beside a shallow CI checkout). It
  # is never a hidden dependency: unset it and the test falls back to the
  # repo's own `.git` or takes a named skip — never a silent pass.
  # Documented here (PR #7, L5 wave3, 2026-09-26; zero-config CI run
  # 36229792938 refused the undocumented read).
  #
  # ASH_SURFACE_LINEAGE_HEAD: optional override pinning the LIVE
  # lineage-court re-judgment to an explicit head SHA (e.g. a scratch tree
  # judged against a canonical `.git`). It is never a hidden dependency:
  # unset it and the test falls back to `git rev-parse HEAD` on the
  # ASH_SURFACE_LINEAGE_GIT_DIR git dir. Documented here (PR #7, L7 wave5,
  # 2026-09-26; zero-config-v2 CI run 36249823044 refused the undocumented
  # read at lineage_court_test.exs:531).
  @zero_env_allowlist ~w(HOME PATH ASH_SURFACE_LINEAGE_GIT_DIR ASH_SURFACE_LINEAGE_HEAD)

  def project do
    [
      app: :ash_surface,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Manifest-first consumer surfaces for Ash applications",
      source_url: @source_url,
      homepage_url: @source_url,
      package: package(),
      aliases: aliases(),
      test_coverage: test_coverage(),
      dialyzer: dialyzer()
    ]
  end

  # Coverage gate. threshold: 90 is Elixir >= 1.20's mix default; it is pinned
  # here as an explicit repo decision so a future toolchain bump cannot move
  # the gate silently (PR #7 lane AS, 2026-09-25; CI run 35841301667 failed at
  # 87.48% partly because the coverage job ran before `npm install`, killing
  # the zod-importing JS-bridge suites — ordering fixed in
  # .github/workflows/dialyzer-coverage.yml).
  #
  # ignore_modules: everything under test/support/ (fixtures, the compiler
  # echo section, digest-parity fixtures, Inspect protocol impls for fixture
  # structs). They are compiled into the :test env and exercised by the
  # suites, but they are scaffolding, not product surface — the 90% gate
  # measures product code only.
  defp test_coverage do
    [
      threshold: 90,
      ignore_modules: [
        AshSurface.DigestParityFixtures,
        AshSurface.Fixtures.Domain,
        AshSurface.Fixtures.Server,
        AshSurface.Fixtures.VolunteerMilestone,
        AshSurface.TestSupport.CompilerEchoSection,
        Inspect.AshSurface.Fixtures.VolunteerMilestone
      ]
    ]
  end

  # Dialyzer baseline (gapfix-dialyzer-010): findings that are real defects are
  # fixed; the residual suppression lives in dialyzer.ignore-warnings with a
  # per-line justification. ex_unit is needed in the PLT because test support
  # modules reference ExUnit callbacks. ash_a2a and ash_r2rml are runtime:
  # false all-env deps whose functions ash_surface calls directly — without
  # them in the PLT dialyzer reports their functions as unknown.
  defp dialyzer do
    [
      plt_add_apps: [:ex_unit, :ash_a2a, :ash_r2rml],
      ignore_warnings: "dialyzer.ignore-warnings",
      list_unused_filters: true
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # `mix test.all` chains the "test" task through an alias, and `mix test.zero`
  # re-execs it with no MIX_ENV in the scrubbed environment; preferred_envs
  # makes :test the default for both without any environment variable.
  def cli do
    [preferred_envs: ["test.all": :test, "test.zero": :test]]
  end

  def application do
    [extra_applications: [:logger, :crypto]]
  end

  defp deps do
    [
      {:ash, "~> 3.33.1"},
      {:spark, "~> 2.7"},
      {:jason, "~> 1.4"},
      # Property-based tests (042 + 043 union; deduped at 051 merge). No `only:` restriction
      # is admissible: ash_a2a (all-env dep) requires stream_data in every env,
      # and ash already pulls it non-optionally. It never enters the boot path
      # (not in extra_applications) and the analysis/generator machinery never
      # ships in release artifacts built from this app.
      {:stream_data, "~> 1.4", runtime: false},
      # igniter: no `only:` restriction — ash_a2a (all-env dep) requires it
      # beyond dev/test; runtime: false keeps it out of the boot path.
      {:igniter, "~> 0.7", runtime: false},
      # Static success-typing analysis (gapfix-dialyzer-010). Dev-only: the
      # analysis tool never ships and never enters the boot path.
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      # ash_r2rml pinned to git HEAD (7d958a8) overriding ash_a2a's hex
      # "~> 26.8" requirement — git version 26.9.12 satisfies it.
      {:ash_r2rml,
       git: "https://github.com/seanchatmangpt/ash_r2rml.git",
       ref: "7d958a8c47a5a3459a515ac6f81a4d2d2d84dd16",
       runtime: false,
       override: true},
      # ash_a2a repinned to the released v26.9.22 tag (ASF-26922-07; was
      # e25ed6e) — pulls rdf ~> 3.0 and the wasmex NIF.
      {:ash_a2a,
       git: "https://github.com/seanchatmangpt/ash_a2a.git", tag: "v26.9.22", runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib priv .formatter.exs mix.exs README.md AGENTS.md)
    ]
  end

  defp aliases do
    [
      # Elixir suite first, then the JS suite. Mix aborts a list alias at the
      # first failing task, so a failure in either suite fails the whole run.
      "test.all": ["test", "test.js"],
      "test.js": &run_js_suite/1,
      # Zero-config proof: `mix test.all` re-run through literal `env -i`
      # with only @zero_env_allowlist surviving.
      "test.zero": &run_all_under_scrubbed_env/1
    ]
  end

  defp run_js_suite(_args) do
    case System.cmd("npm", ["test"], into: IO.stream(:stdio, :line), stderr_to_stdout: true) do
      {_output, 0} ->
        :ok

      {_output, status} ->
        Mix.raise("test.js: npm test exited with status #{status}")
    end
  end

  # `System.cmd/3`'s `:env` option MERGES into the parent environment (verified
  # empirically on OTP 28), so true env -i semantics require wrapping env(1).
  defp run_all_under_scrubbed_env(_args) do
    env_exe = System.find_executable("env")

    if is_nil(env_exe) do
      Mix.raise("test.zero: env(1) not found in PATH; cannot scrub the environment")
    end

    assignments =
      for key <- @zero_env_allowlist, value = System.get_env(key) do
        "#{key}=#{value}"
      end

    Mix.shell().info(
      "==> test.zero: running `mix test.all` under env -i (only #{Enum.join(@zero_env_allowlist, ", ")} survive)"
    )

    case System.cmd(env_exe, ["-i" | assignments] ++ ["mix", "test.all"],
           into: IO.stream(:stdio, :line),
           stderr_to_stdout: true
         ) do
      {_output, 0} ->
        :ok

      {_output, status} ->
        Mix.raise("test.zero: scrubbed `mix test.all` exited with status #{status}")
    end
  end
end
