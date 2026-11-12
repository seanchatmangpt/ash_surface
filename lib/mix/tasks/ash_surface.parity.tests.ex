defmodule Mix.Tasks.AshSurface.Parity.Tests do
  @moduledoc """
  The ash_typescript test-port gate (ledger + inventory).

      mix ash_surface.parity.tests [--json] [--summary] [--check-inventory]
                                   [--regenerate-inventory] [--reference PATH]

  Default: join `parity/test_inventory.json` (every reference `*_test.exs` and
  `test/ts/**/*.ts`, derived mechanically) with `parity/test_ledger.json` (one row per
  reference file: ported | adapted | skipped_gap | non_goal | unaccounted); print the
  per-directory table and exit 1 on any unaccounted file or broken row.

    * `--summary` - only `parity-tests: files=N ported=N adapted=N skipped_gap=N non_goal=N unaccounted=N broken=N shallow=N`.
    * `--json` - machine-readable verdict.
    * `--check-inventory` - re-derive from the reference (`~/ash_typescript` or `--reference`)
      and byte-compare `parity/test_inventory.json`; exit 1 on drift or no reference.
    * `--regenerate-inventory` - rewrite `parity/test_inventory.json` from the reference.
  """
  use Mix.Task

  alias AshSurface.ParityTests.{Inventory, Report}

  @shortdoc "ash_typescript test-port gate (exit 1 on any unaccounted/broken reference test file)"

  @impl Mix.Task
  def run(args) do
    {opts, rest, invalid} =
      OptionParser.parse(args,
        strict: [
          json: :boolean,
          summary: :boolean,
          check_inventory: :boolean,
          regenerate_inventory: :boolean,
          reference: :string
        ]
      )

    if invalid != [] or rest != [],
      do: Mix.raise("parity.tests: unknown arguments #{inspect(invalid ++ rest)}")

    root = File.cwd!()
    inv_path = Path.join(root, "parity/test_inventory.json")

    ref =
      Path.expand(opts[:reference] || System.get_env("ASH_TYPESCRIPT_PATH") || "~/ash_typescript")

    cond do
      opts[:regenerate_inventory] -> regenerate(ref, inv_path)
      opts[:check_inventory] -> check_inventory(ref, inv_path)
      true -> gate(root, opts)
    end
  end

  defp gate(root, opts) do
    r = Report.evaluate(root: root)

    out =
      cond do
        opts[:json] -> Report.to_json(r)
        opts[:summary] -> Report.summary(r)
        true -> Report.render(r) <> Report.summary(r) <> "\n"
      end

    Mix.shell().info(out)
    if r.exit != 0, do: Mix.raise("parity.tests gate failed")
  end

  defp regenerate(ref, path) do
    case Inventory.derive(ref) do
      {:ok, inv} ->
        File.mkdir_p!(Path.dirname(path))
        File.write!(path, Inventory.to_json(inv))
        Mix.shell().info("wrote #{path} (#{length(inv.files)} files)")

      {:error, why} ->
        Mix.raise("test inventory: #{why}")
    end
  end

  defp check_inventory(ref, path) do
    case Inventory.check(ref, path) do
      {:ok, n, head} ->
        Mix.shell().info(
          "test inventory identical: #{n} files (reference #{head || "unknown head"})"
        )

      {:error, why} ->
        Mix.raise("test inventory check failed: #{why}")
    end
  end
end
