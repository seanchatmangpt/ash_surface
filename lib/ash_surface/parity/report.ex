defmodule AshSurface.Parity.Report do
  @moduledoc """
  The parity gate: join the derived inventory, the court map and the KD register.

  `evaluate/1` is a pure function of files on disk (it never executes resource
  actions). Every inventory id lands in exactly one status:

    * `:pass` / `:divergence` / `:non_goal` - mapped and the mapping validates
    * `:broken` - mapped but the mapping points at something absent
    * `:missing` - unmapped, OR mapped as a divergence/non-goal that is not a
      witnessed better-implementation / README-declared non-goal (operator
      divergence law 2026-11-11); `problems` carries the reason

  `exit` is 0 only when there are no missing/broken ids, no orphan map entries,
  and no register lint problems.
  """

  alias AshSurface.Parity.{CourtMap, Inventory, Register}

  @statuses [:pass, :divergence, :non_goal, :broken, :missing]

  @doc """
  Options: `:root` (repo root, default cwd), `:inventory_path`, `:map_path`,
  `:kd_path` (each defaulting to the repo-relative standard location).
  """
  def evaluate(opts \\ []) do
    root = Keyword.get(opts, :root, File.cwd!())
    inv_path = Keyword.get(opts, :inventory_path, Path.join(root, "parity/capabilities.json"))
    map_path = Keyword.get(opts, :map_path, Path.join(root, "parity/court_map.json"))
    kd_path = Keyword.get(opts, :kd_path, Path.join(root, "docs/KNOWN_DIVERGENCES.md"))
    strict = Keyword.get(opts, :strict_skips, true)
    CourtMap.reset_cache()

    with {:ok, inv} <- read(inv_path, &Inventory.from_json!/1),
         {:ok, entries} <-
           read(map_path, fn t -> t |> Jason.decode!() |> Map.fetch!("entries") end),
         {:ok, kd_text} <- read(kd_path, & &1) do
      rows = Register.parse(kd_text)
      kd = Map.new(rows, &{&1.id, &1})
      lint = Register.header_problems(kd_text) ++ Register.lint(rows, root)

      cells =
        inv.capabilities
        |> Enum.map(&cell(&1, entries, root, kd, strict))
        |> cap_shared_tests()

      orphans = orphans(entries, inv.capabilities)
      build(cells, orphans, lint ++ inventory_problems(inv), inv, rows)
    else
      {:error, why} ->
        %{exit: 1, fatal: why, rows: [], counts: %{}, missing: [], errors: [why], advisory: %{}}
    end
  end

  defp read(path, fun) do
    case File.read(path) do
      {:ok, text} ->
        try do
          {:ok, fun.(text)}
        rescue
          e -> {:error, "#{path}: unreadable (#{Exception.message(e)})"}
        end

      {:error, r} ->
        {:error, "#{path}: #{:file.format_error(r)}"}
    end
  end

  # an inventory that is empty, or whose rows lack id/section, cannot be a green gate
  defp inventory_problems(%{capabilities: []}), do: ["inventory holds zero capabilities"]

  defp inventory_problems(%{capabilities: caps}) do
    for c <- caps,
        not (is_binary(Map.get(c, :id)) and is_binary(Map.get(c, :section))),
        do: "inventory row without id/section: #{inspect(c)}"
  end

  @max_rows_per_ref 3

  @doc "Max capabilities one literal test reference may close (unless the entry sets `\"shared\": true`)."
  def max_rows_per_ref, do: @max_rows_per_ref

  # one test line closing many rows is smeared evidence: refuse every row past the cap
  defp cap_shared_tests(cells) do
    over =
      cells
      |> Enum.filter(&(&1.status == :pass and not (&1.entry["shared"] == true)))
      |> Enum.flat_map(fn c ->
        c.entry |> CourtMap.literal_refs() |> Enum.uniq() |> Enum.map(&{&1, c.id})
      end)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Enum.filter(fn {_, ids} -> length(ids) > @max_rows_per_ref end)
      |> Map.new()

    Enum.map(cells, fn c ->
      hit =
        if c.status == :pass and c.entry["shared"] != true,
          do: c.entry |> CourtMap.literal_refs() |> Enum.find(&Map.has_key?(over, &1))

      case hit do
        nil ->
          c

        {file, tok} = ref ->
          msg =
            "SHARED-TEST #{file} #{inspect(tok)} closes #{length(over[ref])} rows (> #{@max_rows_per_ref}); one test cannot close that many"

          %{c | status: :broken, problems: [msg]}
      end
    end)
  end

  defp skipped?(p), do: String.contains?(p, "SKIPPED")

  defp cell(cap, entries, root, kd, strict) do
    case CourtMap.resolve(entries, cap.id) do
      nil ->
        Map.merge(cap, %{status: :missing, problems: [], skipped: false})

      {_key, entry} ->
        {s, problems} = CourtMap.validate(cap.id, entry, root, kd)
        skipped = Enum.any?(problems, &skipped?/1)
        # strict (default): a skipped court is broken. non-strict: still counted, not failing.
        problems = if strict, do: problems, else: Enum.reject(problems, &skipped?/1)
        base = Map.merge(cap, %{skipped: skipped, entry: entry})

        case {s, problems} do
          {s, []} -> Map.merge(base, %{status: s, problems: []})
          {:unwitnessed, p} -> Map.merge(base, %{status: :missing, problems: p})
          {_, p} -> Map.merge(base, %{status: :broken, problems: p})
        end
    end
  end

  defp orphans(entries, caps) do
    ids = Enum.map(caps, & &1.id)

    for {k, _} <- entries,
        not Enum.any?(ids, fn id ->
          if String.ends_with?(k, "*"),
            do: String.starts_with?(id, String.trim_trailing(k, "*")),
            else: id == k
        end),
        do: "map entry #{inspect(k)} matches no inventory id (stale)"
  end

  defp build(cells, orphans, lint, inv, rows) do
    counts = @statuses |> Map.new(&{&1, 0}) |> Map.merge(Enum.frequencies_by(cells, & &1.status))
    broken = for %{status: :broken} = c <- cells, p <- c.problems, do: "#{c.id}: #{p}"
    missing = for %{status: :missing} = c <- cells, do: c.id
    errors = Enum.sort(broken) ++ Enum.sort(orphans) ++ lint

    failing = missing != [] or errors != []

    %{
      exit: if(failing, do: 1, else: 0),
      total: length(cells),
      counts: counts,
      rows: cells,
      missing: missing,
      errors: errors,
      advisory: inv.advisory,
      kd_rows: length(rows),
      skipped: for(%{skipped: true} = c <- cells, do: c.id),
      generic:
        for(
          %{problems: ps} = c <- cells,
          Enum.any?(ps, &String.contains?(&1, "GENERIC token")),
          do: c.id
        )
    }
  end

  @doc "Stable CI line: `parity: total=N pass=N divergence=N non_goal=N broken=N missing=N`."
  def summary(%{fatal: _}),
    do: "parity: total=0 pass=0 divergence=0 non_goal=0 broken=1 missing=0"

  def summary(r) do
    c = r.counts

    "parity: total=#{r.total} pass=#{c.pass} divergence=#{c.divergence} " <>
      "non_goal=#{c.non_goal} broken=#{c.broken} missing=#{c.missing}"
  end

  @doc "Human table: counts by status, by section, every MISSING id and every error."
  def render(%{fatal: why}), do: "PARITY GATE FATAL: #{why}\n"

  def render(r) do
    sections = r.rows |> Enum.group_by(& &1.section) |> Enum.sort_by(fn {s, _} -> s end)

    head = [
      "ash_surface parity gate",
      "total capabilities: #{r.total}",
      "status      count",
      Enum.map(@statuses, fn s -> "#{String.pad_trailing(to_string(s), 11)} #{r.counts[s]}" end),
      "",
      "by section (pass/divergence/non_goal/broken/missing):",
      Enum.map(sections, fn {s, cs} ->
        f = Enum.frequencies_by(cs, & &1.status)
        nums = Enum.map_join(@statuses, "/", &Map.get(f, &1, 0))
        "  #{String.pad_trailing(s, 12)} #{String.pad_leading(to_string(length(cs)), 4)}  #{nums}"
      end),
      "",
      "MISSING (#{length(r.missing)}), ranked by section:"
    ]

    missing =
      r.rows
      |> Enum.filter(&(&1.status == :missing))
      |> Enum.group_by(& &1.section)
      |> Enum.sort_by(fn {s, cs} -> {-length(cs), s} end)
      |> Enum.flat_map(fn {s, cs} ->
        ["  [#{s}] #{length(cs)}" | Enum.map(cs, &missing_line/1)]
      end)

    errs =
      case r.errors do
        [] -> []
        es -> ["", "ERRORS (#{length(es)}):" | Enum.map(es, &"  ERROR #{&1}")]
      end

    skips =
      ["", "SKIPPED-TEST coverage cells: #{length(r.skipped)}"] ++
        Enum.map(r.skipped, &"  SKIPPED #{&1}")

    generic =
      if r.generic == [],
        do: [],
        else: [
          "GENERIC-token ids (#{length(r.generic)}):" | Enum.map(r.generic, &"  GENERIC #{&1}")
        ]

    tail =
      skips ++
        generic ++
        ["", if(r.exit == 0, do: "PARITY: PASS (exit 0)", else: "PARITY: FAIL (exit 1)")]

    (head ++ missing ++ errs ++ tail) |> List.flatten() |> Enum.join("\n") |> Kernel.<>("\n")
  end

  defp missing_line(%{problems: []} = c), do: "    MISSING #{c.id}"
  defp missing_line(%{problems: [one]} = c), do: "    MISSING #{c.id}  (#{one})"

  defp missing_line(%{problems: [first | rest]} = c),
    do: "    MISSING #{c.id}  (#{first}; +#{length(rest)} more court files checked)"

  @doc "Machine-readable verdict."
  def to_json(%{fatal: why}), do: Jason.encode!(%{exit: 1, fatal: why})

  def to_json(r) do
    counts = Map.new(r.counts, fn {k, v} -> {to_string(k), v} end)

    Jason.encode!(%{
      "exit" => r.exit,
      "total" => r.total,
      "counts" => counts,
      "missing" => r.missing,
      "skipped" => r.skipped,
      "generic" => r.generic,
      "errors" => r.errors
    })
  end
end
