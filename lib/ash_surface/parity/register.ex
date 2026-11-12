defmodule AshSurface.Parity.Register do
  @moduledoc """
  The known-divergence register (`docs/KNOWN_DIVERGENCES.md`) and its receipt lint.

  Rows are markdown table lines of the form

      | KD-nn | surface | divergence | better_because | court | receipt | close condition |

  Divergence law (operator 2026-11-11): a divergence is acceptable ONLY if
  ash_surface implements something better, witnessed by an executed court. A row
  is `witnessed?/2` only when `better_because` is non-empty, `court` is an
  existing repo-relative file, and the receipt `Standing:` is ALIVE or PASS.
  An unwitnessed row does NOT close its capability: the gate counts it MISSING.

  Receipt-lint: every row (referenced or not) must cite an existing receipt file
  whose `Standing:` line carries a value from the closed vocabulary
  `ALIVE | PARTIAL_ALIVE | PASS | BLOCKED | UNVERIFIED | PARTIAL`.
  """

  @vocabulary ~w(ALIVE PARTIAL_ALIVE PASS BLOCKED UNVERIFIED PARTIAL)

  @type row :: %{
          id: String.t(),
          surface: String.t(),
          divergence: String.t(),
          better: String.t(),
          court: String.t(),
          receipt: String.t(),
          close: String.t()
        }

  def vocabulary, do: @vocabulary

  @columns ~w(id surface divergence better_because court receipt close)
  @aliases %{
    "better" => "better_because",
    "close_condition" => "close",
    "close condition" => "close"
  }

  @doc """
  Parse KD rows from the register text by HEADER NAME (never by fixed column index).

  The header is the first table line whose first cell is `id`; its cells are
  normalised (lowercase, aliases `better`, `close condition`). Rows may reorder
  columns or add extra ones; cells split on unescaped `|` only (`\\|` is a literal
  pipe); ids are any `KD-<A-Z0-9->` token (`KD-07`, `KD-KIN-03`, `KD-SQ-12`).
  A row with fewer cells than the header gets empty fields (lint flags them).
  """
  @spec parse(String.t()) :: [row()]
  def parse(text) do
    lines = String.split(text, "\n")

    case header(lines) do
      nil ->
        []

      {hdr_idx, index} ->
        lines
        |> Enum.drop(hdr_idx + 1)
        |> Enum.flat_map(fn line ->
          cs = cells(line)
          id = Enum.at(cs, Map.get(index, "id", 0), "")

          if Regex.match?(~r/^KD-[A-Z0-9]+(-[A-Z0-9]+)*$/, id),
            do: [row(id, cs, index)],
            else: []
        end)
    end
  end

  @doc """
  Register-shape problems: KD-looking rows with no header, or a header missing a
  required column. Empty when the register is well-formed (or holds no rows).
  """
  @spec header_problems(String.t()) :: [String.t()]
  def header_problems(text) do
    lines = String.split(text, "\n")

    case header(lines) do
      nil ->
        if Enum.any?(lines, &String.match?(&1, ~r/^\|\s*KD-/)),
          do: ["register has KD rows but no `| id | ...` header line"],
          else: ["register has no `| id | ...` header line"]

      {_, index} ->
        for c <- @columns, not Map.has_key?(index, c), do: "register header lacks column `#{c}`"
    end
  end

  defp header(lines) do
    lines
    |> Enum.with_index()
    |> Enum.find_value(fn {line, i} ->
      case cells(line) do
        [_ | _] = cs ->
          if Enum.any?(cs, &(String.downcase(&1) == "id")) and
               "court" in Enum.map(cs, &String.downcase/1) do
            idx =
              cs
              |> Enum.with_index()
              |> Map.new(fn {c, j} ->
                n = String.downcase(c)
                {Map.get(@aliases, n, n), j}
              end)

            {i, idx}
          end

        _ ->
          nil
      end
    end)
  end

  # split a table line on unescaped pipes; nil-ish for non-table lines
  defp cells(line) do
    t = String.trim(line)

    if String.starts_with?(t, "|") do
      t
      |> String.trim_leading("|")
      |> String.replace(~r/\|\s*$/, "")
      |> then(&Regex.split(~r/(?<!\\)\|/, &1))
      |> Enum.map(&clean/1)
    else
      []
    end
  end

  defp row(id, cs, index) do
    get = fn col ->
      case Map.fetch(index, col) do
        {:ok, j} -> Enum.at(cs, j, "")
        :error -> ""
      end
    end

    %{
      id: id,
      surface: get.("surface"),
      divergence: get.("divergence"),
      better: get.("better_because"),
      court: get.("court"),
      receipt: get.("receipt"),
      close: get.("close")
    }
  end

  @doc "Lint every row; returns a list of problem strings (empty when clean)."
  @spec lint([row()], Path.t()) :: [String.t()]
  def lint(rows, root) do
    dup =
      rows
      |> Enum.frequencies_by(& &1.id)
      |> Enum.filter(fn {_, n} -> n > 1 end)
      |> Enum.map(fn {id, _} -> "#{id}: duplicate register row" end)

    dup ++ Enum.flat_map(rows, &lint_row(&1, root))
  end

  defp lint_row(row, root) do
    []
    |> need(row.surface != "", "#{row.id}: empty surface")
    |> need(row.divergence != "", "#{row.id}: empty divergence")
    |> need(row.close != "", "#{row.id}: empty close condition")
    |> need(row.better != "", "#{row.id}: empty better_because")
    |> need(row.court != "", "#{row.id}: empty court path")
    |> Kernel.++(receipt_problems(row, root))
  end

  defp need(acc, true, _), do: acc
  defp need(acc, false, msg), do: acc ++ [msg]

  defp receipt_problems(%{receipt: ""} = row, _),
    do: ["#{row.id}: divergence row lacks a receipt path"]

  defp receipt_problems(row, root) do
    case receipt_standing(root, row.receipt) do
      {:ok, _} -> []
      {:error, why} -> ["#{row.id}: receipt #{row.receipt}: #{why}"]
    end
  end

  @doc """
  Divergence law: `:ok` when the row is a witnessed better-implementation
  (better_because + existing court file + receipt Standing ALIVE|PASS), else
  `{:unwitnessed, reasons}`.
  """
  def witnessed?(row, root) do
    reasons =
      []
      |> need(String.trim(row.better) != "", "better_because empty")
      |> need(
        court_exists?(row.court, root),
        "court #{inspect(row.court)} is not an existing repo file"
      )
      |> need(
        match?({:ok, s} when s in ["ALIVE", "PASS"], receipt_standing(root, row.receipt)),
        "receipt Standing is not ALIVE|PASS"
      )

    reasons = reasons ++ receipt_evidence_problems(row, root)
    if reasons == [], do: :ok, else: {:unwitnessed, reasons}
  end

  @doc """
  Receipt-body evidence law: a Standing line alone never closes a divergence. The
  receipt must carry at least one PASS evidence line (other than its Standing
  line), no FAIL/SKIP/BLOCKED token, and must name the row's court file. (The gate
  does not run the court; it checks it is referenced and exists.)
  """
  @spec receipt_evidence_problems(row(), Path.t()) :: [String.t()]
  def receipt_evidence_problems(row, root) do
    path = Path.join(root, row.receipt)

    with true <- row.receipt != "" and Path.type(row.receipt) == :relative,
         true <- ".." not in Path.split(row.receipt),
         {:ok, body} <- File.read(path) do
      body_lines = body |> String.split("\n") |> Enum.reject(&String.match?(&1, ~r/^Standing:/))
      text = Enum.join(body_lines, "\n")

      []
      |> need(
        Enum.any?(body_lines, &String.match?(&1, ~r/\bPASS\b/)),
        "receipt has zero PASS evidence lines"
      )
      |> need(
        not Regex.match?(~r/\b(FAIL|FAILED|SKIP|SKIPPED|BLOCKED)\b/, text),
        "receipt contains FAIL/SKIP/BLOCKED token (a closed row cannot launder failures)"
      )
      |> need(
        row.court != "" and String.contains?(text, row.court),
        "receipt does not name court file #{inspect(row.court)}"
      )
    else
      _ -> []
    end
  end

  defp court_exists?(court, root) do
    court != "" and Path.type(court) == :relative and ".." not in Path.split(court) and
      File.regular?(Path.join(root, court))
  end

  @doc "Read a receipt's `Standing:` value; must lie in the closed vocabulary."
  @spec receipt_standing(Path.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def receipt_standing(root, rel) do
    cond do
      Path.type(rel) == :absolute or ".." in Path.split(rel) ->
        {:error, "path must be repo-relative"}

      not File.regular?(Path.join(root, rel)) ->
        {:error, "file does not exist"}

      true ->
        standing_of(File.read!(Path.join(root, rel)))
    end
  end

  defp standing_of(text) do
    case Regex.run(~r/^Standing:\s*([A-Z_]+)/m, text) do
      [_, v] when v in @vocabulary -> {:ok, v}
      [_, v] -> {:error, "Standing value #{v} outside closed vocabulary"}
      nil -> {:error, "no Standing: line"}
    end
  end

  defp clean(cell),
    do: cell |> String.trim() |> String.trim("`") |> String.replace("\\|", "|")
end
