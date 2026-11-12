defmodule AshSurface.ParityTests.Skips do
  @moduledoc """
  Robust skip / test-count detector for ash_surface test files.

  Elixir files are judged on the AST (never regex over text), so multi-line
  `@tag skip: "..." <> "..."` continuations, `@tag :skip`, `@moduletag`/`@describetag`
  forms, keyword lists (`@tag timeout: 1, skip: "x"`), bodiless (pending) `test "x"`, and
  tags excluded through `ExUnit.start/configure(exclude: ...)` (in the file or in
  `test/test_helper.exs`) all count as a skip. `skip: false`/`nil` does not.

  Node test files (`*.test.mjs`) are judged by line scan: `.skip(`, `test.todo`,
  `xit(`, `xdescribe(`, `{ skip: <truthy> }`.
  """

  alias AshSurface.Parity.{ExcludeSpec, TestIndex}

  @doc "Analyzes a file. Returns `{:ok, %{skips: [reason], tests: n, describes: n, text: text}}`."
  def scan(path, excluded \\ []) do
    with {:ok, text} <- File.read(path) do
      cond do
        String.ends_with?(path, ".exs") -> scan_exs(path, text, excluded)
        String.ends_with?(path, ".mjs") -> {:ok, scan_mjs(text)}
        true -> {:error, "unsupported test file type"}
      end
    else
      {:error, r} -> {:error, "unreadable (#{inspect(r)})"}
    end
  end

  @doc "Tag names excluded by `ExUnit.start/configure(exclude: ...)` in the given test_helper path."
  def excluded_tags(helper_path) do
    for {k, _} <- ExcludeSpec.read_file(helper_path).exclude, do: String.to_atom(k)
  end

  # One kernel: tags, nesting, pending and dynamic tests come from `TestIndex`; filters
  # (exclude/include/only, unresolvable problems) come from `ExcludeSpec`.
  defp scan_exs(path, text, excluded) do
    spec = spec_of(excluded)

    spec =
      if String.ends_with?(path, "test_helper.exs"),
        do: spec,
        else: ExcludeSpec.merge(spec, ExcludeSpec.read_file(path))

    case TestIndex.analyze(path, text) do
      {:ok, idx} ->
        skips =
          Enum.map(spec.problems, &"#{&1} (cannot prove the test runs)") ++
            Enum.flat_map(idx.tests, &test_skips(&1, spec)) ++
            Enum.flat_map(idx.dynamic, &dynamic_skips(&1, spec))

        {:ok,
         %{
           skips: skips,
           tests: length(idx.tests) + length(idx.dynamic),
           describes: count_describes(text),
           text: text
         }}

      {:error, why} ->
        {:error, why}
    end
  end

  defp spec_of(%{exclude: _, include: _, only: _, problems: _} = s), do: s
  defp spec_of(names) when is_list(names), do: ExcludeSpec.from_names(names)

  defp test_skips(t, spec) do
    []
    |> then(&if t.pending, do: ["bodiless (pending) test #{inspect(t.title)}" | &1], else: &1)
    |> then(&if t.skipped, do: ["skip tag on #{inspect(t.title)}" | &1], else: &1)
    |> then(fn acc ->
      if ExcludeSpec.excluded?(spec, t.tag_values),
        do: ["#{inspect(t.title)} excluded by tag filter" | acc],
        else: acc
    end)
    |> Enum.reverse()
  end

  # a for/macro-generated test runs under `mix test`: a skip only if a tag/filter applies
  defp dynamic_skips(d, spec) do
    t = %{title: d.title, pending: false, skipped: d.skipped, tag_values: d.tag_values}
    test_skips(t, spec)
  end

  defp count_describes(text) do
    case Code.string_to_quoted(text) do
      {:ok, ast} ->
        {_, n} =
          Macro.prewalk(ast, 0, fn
            {:describe, _, [_ | _]} = node, n -> {node, n + 1}
            node, n -> {node, n}
          end)

        n

      _ ->
        0
    end
  end

  defp scan_mjs(text) do
    lines = String.split(text, "\n")

    skips =
      lines
      |> Enum.filter(fn l ->
        Regex.match?(~r/\.skip\s*\(|\b(?:test|it|describe)\.todo\b|\bx(?:it|describe)\s*\(/, l) or
          Regex.match?(~r/\bskip\s*:\s*(?!false\b|null\b|undefined\b)\S/, l)
      end)
      |> Enum.map(&("mjs skip: " <> String.trim(&1)))

    %{
      skips: skips,
      tests: Enum.count(lines, &Regex.match?(~r/^\s*(?:test|it)\(/, &1)),
      describes: Enum.count(lines, &Regex.match?(~r/^\s*describe\(/, &1)),
      text: text
    }
  end
end
