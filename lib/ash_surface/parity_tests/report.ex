defmodule AshSurface.ParityTests.Report do
  @moduledoc """
  The test-port gate: join `parity/test_inventory.json` (derived from the reference test
  tree) with `parity/test_ledger.json` (one row per reference test file).

  Each inventory file lands in exactly one status:

    * `:ported` / `:adapted` / `:skipped_gap` / `:non_goal` - the row validates
    * `:unaccounted` - no row, or disposition `unaccounted` (counted as MISSING)
    * `:broken` - a row whose evidence does not hold (problems carried); orphan ledger rows
      (file absent from the inventory) and duplicate rows are counted here too

  Row rules:

    * ported / adapted: `ash_surface_tests` non-empty; each path relative, exists, named
      `*_test.exs` (or `*.test.mjs`), contains no skip (see `Skips`), has >= 1 test. A `ts`
      reference can never be `ported` (generated-text assertions are only ever adapted or
      non-goals). adapted additionally needs non-empty `changes`.
    * adapted rows whose test file shows no node/zod/renderer reference are SHALLOW (warning
      only; the gate cannot judge semantic adaptation).
    * skipped_gap: listed tests exist, contain the verbatim `skip_tag` text AND a detected
      skip; `gap` non-empty; optional `capabilities` ids must exist in `parity/capabilities.json`.
    * non_goal: `readme_quote` is a verbatim (whitespace-collapsed) substring of `README.md`.

  `exit` is 0 only when nothing is unaccounted or broken and the inputs are readable.
  """

  alias AshSurface.ParityTests.{Inventory, Skips}

  @dispositions ~w(ported adapted skipped_gap non_goal unaccounted)
  @statuses [:ported, :adapted, :skipped_gap, :non_goal, :unaccounted, :broken]
  @shallow_re ~r/\bnode\b|\bzod\b|fragment_runner|System\.cmd|ZodType|Inference\.emit|Projectors?\.JS|Projectors?\.Js|Renderer|\.render\(/i

  @doc "Options: `:root` (default cwd), `:inventory_path`, `:ledger_path`."
  def evaluate(opts \\ []) do
    root = Keyword.get(opts, :root, File.cwd!())
    inv_path = Keyword.get(opts, :inventory_path, Path.join(root, "parity/test_inventory.json"))
    ledger_path = Keyword.get(opts, :ledger_path, Path.join(root, "parity/test_ledger.json"))

    with {:ok, inv} <- read(inv_path, &Inventory.from_json!/1),
         {:ok, rows} <- read(ledger_path, fn t -> t |> Jason.decode!() |> Map.fetch!("rows") end),
         {:ok, readme} <- read(Path.join(root, "README.md"), &collapse/1) do
      ctx = %{
        root: root,
        readme: readme,
        excluded: AshSurface.Parity.ExcludeSpec.read(root),
        capability_ids: capability_ids(root)
      }

      build(inv, rows, ctx)
    else
      {:error, why} ->
        %{exit: 1, fatal: why, cells: [], counts: %{}, by_dir: %{}, shallow: 0, errors: [why]}
    end
  end

  defp read(path, fun) do
    with {:ok, text} <- File.read(path) do
      try do
        {:ok, fun.(text)}
      rescue
        e -> {:error, "#{path}: unreadable (#{Exception.message(e)})"}
      end
    else
      {:error, r} -> {:error, "#{path}: #{inspect(r)}"}
    end
  end

  defp collapse(s), do: s |> String.split() |> Enum.join(" ")

  defp capability_ids(root) do
    with {:ok, t} <- File.read(Path.join(root, "parity/capabilities.json")),
         {:ok, %{"capabilities" => caps}} <- Jason.decode(t) do
      MapSet.new(caps, & &1["id"])
    else
      _ -> nil
    end
  end

  defp build(inv, rows, ctx) do
    by_file = Enum.group_by(rows, &Map.get(&1, "file"))
    inv_files = MapSet.new(inv.files, & &1["file"])

    cells = Enum.map(inv.files, &cell(&1, Map.get(by_file, &1["file"], []), ctx))

    orphans =
      for {file, rs} <- by_file, not MapSet.member?(inv_files, file) do
        %{
          file: inspect(file),
          kind: "?",
          dir: "(orphan)",
          status: :broken,
          problems: ["orphan ledger row (#{length(rs)}): file not in test_inventory.json"],
          shallow: false
        }
      end

    cells = cells ++ Enum.sort_by(orphans, & &1.file)
    counts = Enum.frequencies_by(cells, & &1.status)
    counts = Map.new(@statuses, &{&1, Map.get(counts, &1, 0)})
    shallow = Enum.count(cells, & &1.shallow)

    by_dir =
      cells
      |> Enum.group_by(& &1.dir)
      |> Map.new(fn {d, cs} -> {d, Enum.frequencies_by(cs, & &1.status)} end)

    bad = counts.unaccounted + counts.broken

    %{
      exit: if(bad == 0, do: 0, else: 1),
      cells: cells,
      counts: Map.put(counts, :files, length(inv.files)),
      by_dir: by_dir,
      shallow: shallow,
      reference_head: inv.reference_head,
      errors: []
    }
  end

  defp cell(f, rows, ctx) do
    file = f["file"]
    base = %{file: file, kind: f["kind"], dir: Path.dirname(file), shallow: false}

    case rows do
      [] ->
        Map.merge(base, %{status: :unaccounted, problems: ["no ledger row"]})

      [_, _ | _] ->
        Map.merge(base, %{status: :broken, problems: ["duplicate ledger rows (#{length(rows)})"]})

      [row] ->
        disp = Map.get(row, "disposition")

        cond do
          disp == "unaccounted" ->
            Map.merge(base, %{status: :unaccounted, problems: ["disposition unaccounted"]})

          disp not in @dispositions ->
            Map.merge(base, %{status: :broken, problems: ["unknown disposition #{inspect(disp)}"]})

          true ->
            {problems, shallow} = check(disp, row, f, ctx)
            status = if problems == [], do: String.to_atom(disp), else: :broken

            Map.merge(base, %{
              status: status,
              problems: problems,
              shallow: shallow and problems == []
            })
        end
    end
  end

  defp check("ported", row, f, ctx) do
    {tests, _texts} = check_tests(row, ctx, :runs)

    extra =
      if f["kind"] == "ts",
        do: ["ts reference cannot be ported verbatim (adapted or non_goal only)"],
        else: []

    {extra ++ tests, false}
  end

  defp check("adapted", row, _f, ctx) do
    {problems, texts} = check_tests(row, ctx, :runs)
    changes = if blank?(row["changes"]), do: ["adapted row has empty changes"], else: []

    shallow =
      problems == [] and texts != [] and not Enum.any?(texts, &Regex.match?(@shallow_re, &1))

    {changes ++ problems, shallow}
  end

  defp check("skipped_gap", row, _f, ctx) do
    tag = row["skip_tag"]

    gap =
      if(blank?(row["gap"]), do: ["skipped_gap row has empty gap description"], else: []) ++
        if(blank?(tag), do: ["skipped_gap row has empty skip_tag"], else: []) ++
        capability_problems(row["capabilities"], ctx)

    {problems, _} = check_tests(row, ctx, {:skipped, tag})
    {gap ++ problems, false}
  end

  defp check("non_goal", row, _f, ctx) do
    q = row["readme_quote"]

    problems =
      cond do
        blank?(q) -> ["non_goal row has empty readme_quote"]
        String.contains?(ctx.readme, collapse(q)) -> []
        true -> ["readme_quote is not a verbatim substring of README.md: #{inspect(q)}"]
      end

    {problems, false}
  end

  defp capability_problems(nil, _), do: []
  defp capability_problems([], _), do: []

  defp capability_problems(ids, %{capability_ids: set}) when is_list(ids) do
    case set do
      nil ->
        ["capabilities listed but parity/capabilities.json is unreadable"]

      set ->
        for id <- ids, not MapSet.member?(set, id), do: "unknown capability id #{inspect(id)}"
    end
  end

  defp capability_problems(_, _), do: ["capabilities must be a list"]

  # mode: :runs (no skips allowed) | {:skipped, tag}. Returns {problems, texts-of-good-files}
  defp check_tests(row, ctx, mode) do
    paths = row["ash_surface_tests"]

    if is_list(paths) and paths != [] do
      results = Enum.map(paths, &check_path(&1, ctx, mode))
      {Enum.flat_map(results, &elem(&1, 0)), for({[], t} <- results, t, do: t)}
    else
      {["ash_surface_tests empty"], []}
    end
  end

  defp check_path(rel, ctx, mode) when is_binary(rel) do
    abs = Path.join(ctx.root, rel)

    cond do
      Path.type(rel) == :absolute or ".." in Path.split(rel) ->
        {["#{rel}: path must be repo-relative"], nil}

      not (String.ends_with?(rel, "_test.exs") or String.ends_with?(rel, ".test.mjs")) ->
        {["#{rel}: not named *_test.exs or *.test.mjs"], nil}

      not File.regular?(abs) ->
        {["#{rel}: file does not exist"], nil}

      true ->
        case Skips.scan(abs, ctx.excluded) do
          {:error, why} -> {["#{rel}: #{why}"], nil}
          {:ok, scan} -> judge(rel, scan, mode)
        end
    end
  end

  defp check_path(other, _, _),
    do: {["ash_surface_tests entry not a string: #{inspect(other)}"], nil}

  defp judge(rel, scan, :runs) do
    cond do
      scan.skips != [] -> {["#{rel}: contains a skip (#{hd(scan.skips)})"], nil}
      scan.tests + scan.describes == 0 -> {["#{rel}: zero test/describe lines"], nil}
      true -> {[], scan.text}
    end
  end

  defp judge(rel, scan, {:skipped, tag}) do
    cond do
      blank?(tag) ->
        {[], nil}

      not String.contains?(scan.text, tag) ->
        {["#{rel}: skip_tag #{inspect(tag)} not found in file"], nil}

      scan.skips == [] ->
        {["#{rel}: skip_tag present but the file contains no skip"], nil}

      true ->
        {[], scan.text}
    end
  end

  defp blank?(v), do: not is_binary(v) or String.trim(v) == ""

  # -- rendering ----------------------------------------------------------------------

  @doc "`parity-tests: files=N ported=N ... broken=N shallow=N`"
  def summary(%{fatal: why}), do: "parity-tests: FATAL #{why}"

  def summary(%{counts: c, shallow: s}) do
    "parity-tests: files=#{c.files} ported=#{c.ported} adapted=#{c.adapted} " <>
      "skipped_gap=#{c.skipped_gap} non_goal=#{c.non_goal} unaccounted=#{c.unaccounted} " <>
      "broken=#{c.broken} shallow=#{s}"
  end

  @doc "Human report: per-directory table, broken rows, unaccounted count."
  def render(%{fatal: why}), do: "FATAL: #{why}\n"

  def render(r) do
    dirs =
      r.by_dir
      |> Enum.sort()
      |> Enum.map_join("\n", fn {d, c} ->
        n = fn k -> Map.get(c, k, 0) end

        "  #{String.pad_trailing(d, 52)} files=#{c |> Map.values() |> Enum.sum()} " <>
          "ported=#{n.(:ported)} adapted=#{n.(:adapted)} skipped_gap=#{n.(:skipped_gap)} " <>
          "non_goal=#{n.(:non_goal)} unaccounted=#{n.(:unaccounted)} broken=#{n.(:broken)}"
      end)

    broken =
      for c <- r.cells, c.status == :broken, p <- c.problems, do: "  BROKEN #{c.file}: #{p}"

    shallow = for c <- r.cells, c.shallow, do: "  SHALLOW #{c.file}"

    "per directory:\n#{dirs}\n" <>
      Enum.join(broken ++ shallow, "\n") <>
      if(broken ++ shallow == [], do: "", else: "\n") <>
      "unaccounted (MISSING): #{r.counts.unaccounted}\n"
  end

  @doc "Machine-readable verdict."
  def to_json(%{fatal: why}), do: Jason.encode!(%{exit: 1, fatal: why})

  def to_json(r) do
    Jason.encode!(%{
      exit: r.exit,
      reference_head: r.reference_head,
      counts: r.counts,
      shallow: r.shallow,
      by_dir:
        Map.new(r.by_dir, fn {d, c} ->
          {d, Map.new(c, fn {k, v} -> {Atom.to_string(k), v} end)}
        end),
      broken: for(c <- r.cells, c.status == :broken, do: %{file: c.file, problems: c.problems}),
      unaccounted: for(c <- r.cells, c.status == :unaccounted, do: c.file),
      shallow_files: for(c <- r.cells, c.shallow, do: c.file)
    })
  end
end
