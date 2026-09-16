defmodule AshSurface.MixProject do
  use Mix.Project

  @version "26.9.13"
  @source_url "https://github.com/seanchatmangpt/ash_surface"

  # The only variables allowed to survive `mix test.zero`'s scrub. Anything
  # beyond toolchain discovery (PATH) and the user home (HOME) is a hidden
  # config dependency and must fail loudly under the scrubbed run.
  @zero_env_allowlist ~w(HOME PATH)

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
      aliases: aliases()
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
      {:igniter, "~> 0.7", only: [:dev, :test], runtime: false},
      {:ash_r2rml,
       git: "https://github.com/seanchatmangpt/ash_r2rml.git",
       ref: "067954ad406fd637fd47646bdb10c4580809c79d",
       only: :test}
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
