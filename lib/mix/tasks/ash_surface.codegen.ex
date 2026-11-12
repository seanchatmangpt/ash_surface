defmodule Mix.Tasks.AshSurface.Codegen do
  @moduledoc """
  Generates the AshSurface JavaScript artifact (Zod schemas + registries).

  Usage:

      mix ash_surface.codegen [--check | --dry-run | --dev] [--output PATH]
        [--run-endpoint PATH] [--validate-endpoint PATH]

    * `--check` - diff generated output against disk; raises
      `Ash.Error.Framework.PendingCodegen` (non-zero exit) carrying the per-file
      diff when any file is out of date. Nothing is written.
    * `--runtime` / `--no-runtime` - copy the three runtime `.mjs` files
      (`ash_surface_runtime.mjs`, `ash_surface_http_transport.mjs`,
      `ash_surface_channel_transport.mjs`) next to the artifacts; default on.
      `--check` diffs them too.
    * `--dry-run` - print what would be written, write nothing.
    * `--dev` - with `--check` and `config :ash_surface, always_regenerate: true`, the
      `--check` gate is bypassed and changed files are written (local development).
      `--check` without both still raises, and `always_regenerate` alone never
      bypasses `--check`.
    * `--output PATH` - a file path ending in `.mjs` receives the artifact directly;
      any other value is a target directory. Default:
      `AshSurface.Config.output_file/0` (`config :ash_surface, :output_file`, with
      `:output_dir` as the legacy alias).
    * `--run-endpoint PATH` / `-r`, `--validate-endpoint PATH` / `-v` - export the
      endpoints as `AshSurfaceEndpoints` in the artifact (flag, else the explicitly
      configured `:run_endpoint` / `:validate_endpoint`; paths must start with `/`).

  Only files whose content changed are written; a re-run over identical content
  leaves every file (and its mtime) untouched.

  Option parsing is lenient so the task composes with `mix ash.codegen`, which
  forwards its own flags (e.g. `--name`) to every extension's codegen task.
  """

  @shortdoc "Generates AshSurface JavaScript artifacts"

  use Mix.Task

  alias AshSurface.Config
  alias AshSurface.Projectors.JS

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("compile")
    AshSurface.Config.Verifier.verify!()

    {opts, _rest, _invalid} =
      OptionParser.parse(args,
        switches: [
          check: :boolean,
          dry_run: :boolean,
          dev: :boolean,
          output: :string,
          runtime: :boolean,
          run_endpoint: :string,
          validate_endpoint: :string
        ],
        aliases: [o: :output, r: :run_endpoint, v: :validate_endpoint]
      )

    case generate(endpoint_opts(opts)) do
      {:ok, artifacts} ->
        targets = targets(artifacts, opts[:output])
        targets = if Keyword.get(opts, :runtime, true), do: with_runtime(targets), else: targets
        handle(targets, opts)

      {:error, reason} ->
        Mix.raise("ash_surface.codegen failed: #{inspect(reason)}")
    end
  end

  # Flag wins; otherwise an explicitly configured `config :ash_surface, :run_endpoint`
  # (the defaults are not emitted, keeping unconfigured artifacts byte-identical).
  defp endpoint_opts(opts) do
    for key <- [:run_endpoint, :validate_endpoint],
        value = Keyword.get(opts, key) || Application.get_env(:ash_surface, key),
        do: {key, value}
  end

  defp generate(endpoint_opts) do
    otp_app = Mix.Project.config()[:app]

    with {:ok, manifest} <- Ash.Info.Manifest.generate(otp_app: otp_app),
         {:ok, irs} <- AshSurface.Compiler.compile(manifest),
         {:ok, artifacts, _meta} <- JS.project_ir(irs, endpoint_opts) do
      {:ok, artifacts}
    end
  end

  @doc false
  # Maps `%{name => content}` to `%{path => content}`. A `.mjs` target (from
  # `--output` or `Config.output_file/0`) names the single artifact file itself.
  def targets(artifacts, output) do
    target = output || Config.output_file()

    case {Path.extname(target), Map.to_list(artifacts)} do
      {".mjs", [{_name, content}]} ->
        %{target => content}

      {".mjs", _many} ->
        dir = Path.dirname(target)
        Map.new(artifacts, fn {name, content} -> {Path.join(dir, name), content} end)

      _ ->
        Map.new(artifacts, fn {name, content} -> {Path.join(target, name), content} end)
    end
  end

  @runtime_files ~w(ash_surface_runtime.mjs ash_surface_http_transport.mjs
                    ash_surface_channel_transport.mjs)

  @doc false
  # Adds the runtime .mjs files next to the generated artifacts (same directory).
  def with_runtime(targets) do
    dirs = targets |> Map.keys() |> Enum.map(&Path.dirname/1) |> Enum.uniq()

    runtime =
      for dir <- dirs, name <- @runtime_files, into: %{} do
        {Path.join(dir, name),
         File.read!(Application.app_dir(:ash_surface, Path.join("priv/static", name)))}
      end

    Map.merge(runtime, targets)
  end

  defp handle(targets, opts) do
    changed =
      targets
      |> Enum.filter(fn {path, content} -> disk(path) != content end)
      |> Map.new()

    # ash_typescript parity (codegen_check_test): `--check` alone always gates; only
    # `--dev --check` with `always_regenerate: true` regenerates silently.
    regenerate? = opts[:dev] == true and Config.always_regenerate()

    cond do
      opts[:check] && not regenerate? ->
        if changed != %{} do
          diff =
            changed
            |> Enum.sort()
            |> Enum.map(fn {path, content} -> {path, diff(disk(path), content)} end)

          Enum.each(diff, fn {path, text} ->
            Mix.shell().error("--- #{path}\n#{text}")
          end)

          raise Ash.Error.Framework.PendingCodegen, diff: diff, explain: true
        end

      opts[:dry_run] ->
        Enum.each(changed, fn {path, content} -> IO.puts("##{path}:\n\n#{content}") end)

      true ->
        for {path, content} <- Enum.sort(changed) do
          File.mkdir_p!(Path.dirname(path))
          File.write!(path, content)
          Mix.shell().info("wrote #{path}")
        end
    end

    :ok
  end

  defp disk(path) do
    case File.read(path) do
      {:ok, content} -> content
      {:error, _} -> nil
    end
  end

  @doc false
  def diff(nil, new), do: "(new file, #{byte_size(new)} bytes)"

  def diff(old, new) do
    List.myers_difference(String.split(old, "\n"), String.split(new, "\n"))
    |> Enum.flat_map(fn
      {:eq, _} -> []
      {:del, lines} -> Enum.map(lines, &("-" <> &1))
      {:ins, lines} -> Enum.map(lines, &("+" <> &1))
    end)
    |> Enum.join("\n")
  end
end
