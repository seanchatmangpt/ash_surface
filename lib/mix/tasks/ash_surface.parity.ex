defmodule Mix.Tasks.AshSurface.Parity do
  @moduledoc """
  The mechanical ash_typescript parity gate.

      mix ash_surface.parity [--json] [--check-inventory] [--regenerate-inventory]
                             [--reference PATH] [--summary] [--no-strict-skips]

  Default: join `parity/capabilities.json` (the derived inventory), the court map
  `parity/court_map.json` and `docs/KNOWN_DIVERGENCES.md`; print counts by status
  and every MISSING id; exit 1 unless every capability is pass, a registered
  divergence (with a linted receipt) or a non-goal.

    * `--summary` - print only `parity: total=N pass=N divergence=N non_goal=N broken=N missing=N`.
    * `--strict-skips` (default on; `--no-strict-skips` to relax) - a pass entry whose test
      is skip-tagged is BROKEN; skipped coverage cells are always printed and counted.
    * `--json` - machine-readable verdict.
    * `--check-inventory` - re-derive the inventory from the reference
      (`~/ash_typescript` or `--reference`) and byte-compare `parity/capabilities.json`;
      exit 1 on drift or when the reference is unavailable.
    * `--regenerate-inventory` - rewrite `parity/capabilities.json` from the reference.
  """
  use Mix.Task

  alias AshSurface.Parity.{Inventory, Report}

  @shortdoc "Mechanical ash_typescript parity gate (exit 1 on any unmapped capability)"

  @impl Mix.Task
  def run(args) do
    {opts, rest, invalid} =
      OptionParser.parse(args,
        strict: [
          json: :boolean,
          check_inventory: :boolean,
          regenerate_inventory: :boolean,
          reference: :string,
          summary: :boolean,
          strict_skips: :boolean
        ]
      )

    if invalid != [] or rest != [],
      do: Mix.raise("parity: unknown arguments #{inspect(invalid ++ rest)}")

    root = File.cwd!()

    ref =
      Path.expand(opts[:reference] || System.get_env("ASH_TYPESCRIPT_PATH") || "~/ash_typescript")

    inv_path = Path.join(root, "parity/capabilities.json")

    cond do
      opts[:regenerate_inventory] -> regenerate(ref, inv_path)
      opts[:check_inventory] -> check_inventory(ref, inv_path)
      true -> gate(root, opts)
    end
  end

  defp gate(root, opts) do
    r = Report.evaluate(root: root, strict_skips: Keyword.get(opts, :strict_skips, true))

    out =
      cond do
        opts[:json] -> Report.to_json(r)
        opts[:summary] -> Report.summary(r)
        true -> Report.render(r) <> Report.summary(r) <> "\n"
      end

    Mix.shell().info(out)
    finish(r.exit, "parity gate failed")
  end

  defp regenerate(ref, path) do
    case Inventory.derive(ref) do
      {:ok, inv} ->
        File.mkdir_p!(Path.dirname(path))
        File.write!(path, Inventory.to_json(inv))
        Mix.shell().info("wrote #{path} (#{length(inv.capabilities)} capabilities)")

      {:error, why} ->
        Mix.raise("inventory: #{why}")
    end
  end

  defp check_inventory(ref, path) do
    with {:ok, inv} <- Inventory.derive(ref),
         {:ok, committed} <- File.read(path) do
      fresh = Inventory.to_json(inv)

      if fresh == committed do
        Mix.shell().info(
          "inventory identical: #{length(inv.capabilities)} capabilities (reference #{Inventory.reference_head(ref) || "unknown head"})"
        )
      else
        Mix.raise(
          "inventory drift: #{path} differs from a fresh derivation; run --regenerate-inventory"
        )
      end
    else
      {:error, why} -> Mix.raise("inventory check failed: #{inspect(why)}")
    end
  end

  defp finish(0, _), do: :ok
  defp finish(_, msg), do: Mix.raise(msg)
end
