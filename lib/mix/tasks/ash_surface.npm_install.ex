defmodule Mix.Tasks.AshSurface.NpmInstall do
  @moduledoc "Runs `npm install` (or `bun install` with `--bun`) in `assets/`."
  use Mix.Task

  @shortdoc "Installs npm dependencies in assets/"

  @impl Mix.Task
  def run(args) do
    pm = if "--bun" in args, do: "bun", else: "npm"

    {_out, status} = System.cmd(pm, ["install"], cd: "assets", into: IO.stream(:stdio, :line))

    if status != 0, do: Mix.raise("#{pm} install failed with exit code #{status}")
  end
end
