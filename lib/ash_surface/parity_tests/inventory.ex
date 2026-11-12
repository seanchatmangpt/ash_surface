defmodule AshSurface.ParityTests.Inventory do
  @moduledoc """
  Mechanical inventory of the reference test tree (`~/ash_typescript/test`).

  Included file types (everything CI executes or compiles under `test/`):

    * `kind: "exs"` - every `*_test.exs` (ExUnit; `mix test`). Describe and test titles
      come from an AST walk (`Code.string_to_quoted/1`): `describe`, `test`, `property`.
    * `kind: "ts"` - every `test/ts/**/*.ts` (compiled by `tsc` via the `test/ts/package.json`
      scripts `compileShouldPass`, `compileShouldFail`, `testZod`, `testValibot`; the entry
      points `shouldPass.ts` / `shouldFail.ts` / `run*Tests.ts` import the rest). Titles come
      from a line scan: `// Test N: ...` comments, `export function ...`, `runTest("...")`,
      `it(`/`test(` calls; `expect_errors` counts `@ts-expect-error` markers.

  Not included: `test/support/**` (fixture resources, not tests), `package*.json`,
  `test_helper.exs`, `*.d.ts`, `node_modules`.

  `derive/1` is a pure function of the reference tree; `to_json/1` is byte-deterministic.
  """

  @doc "Derives the inventory from the reference checkout root."
  def derive(ref_root) do
    test_dir = Path.join(ref_root, "test")

    if File.dir?(test_dir) do
      exs = Path.wildcard(Path.join(test_dir, "**/*_test.exs"))

      ts =
        test_dir
        |> Path.join("ts/**/*.ts")
        |> Path.wildcard()
        |> Enum.reject(
          &(String.ends_with?(&1, ".d.ts") or String.contains?(&1, "/node_modules/"))
        )

      (exs ++ ts)
      |> Enum.sort()
      |> Enum.reduce_while({:ok, []}, fn abs, {:ok, acc} ->
        rel = Path.relative_to(abs, ref_root)

        case analyze(rel, File.read!(abs)) do
          {:ok, row} -> {:cont, {:ok, [row | acc]}}
          {:error, why} -> {:halt, {:error, "#{rel}: #{why}"}}
        end
      end)
      |> case do
        {:ok, rows} ->
          {:ok, %{reference_head: reference_head(ref_root), files: Enum.reverse(rows)}}

        err ->
          err
      end
    else
      {:error, "reference test dir not found: #{test_dir}"}
    end
  end

  @doc "Byte-compares a fresh derivation against the committed inventory at `path`."
  def check(ref_root, path) do
    with {:ok, inv} <- derive(ref_root),
         {:ok, committed} <- File.read(path) do
      if to_json(inv) == committed,
        do: {:ok, length(inv.files), inv.reference_head},
        else:
          {:error,
           "inventory drift: #{path} differs from a fresh derivation; run --regenerate-inventory"}
    else
      {:error, why} -> {:error, if(is_binary(why), do: why, else: inspect(why))}
    end
  end

  @doc "Parses `parity/test_inventory.json` text."
  def from_json!(text) do
    decoded = Jason.decode!(text)

    %{
      reference_head: Map.fetch!(decoded, "reference_head"),
      files: Map.fetch!(decoded, "files")
    }
  end

  @doc "Byte-deterministic JSON: one file row per line."
  def to_json(%{reference_head: head, files: files}) do
    totals = %{
      files: length(files),
      describes: files |> Enum.map(&length(&1.describes)) |> Enum.sum(),
      tests: files |> Enum.map(& &1.test_count) |> Enum.sum()
    }

    rows = Enum.map_join(files, ",\n", fn f -> "    " <> row_json(f) end)

    "{\n  \"reference_head\": #{enc(head)},\n" <>
      "  \"advisory\": {\"files\":#{totals.files},\"describes\":#{totals.describes},\"tests\":#{totals.tests}},\n" <>
      "  \"files\": [\n#{rows}\n  ]\n}\n"
  end

  defp row_json(f) do
    "{" <>
      Enum.join(
        [
          "\"file\":#{enc(f.file)}",
          "\"kind\":#{enc(f.kind)}",
          "\"describes\":#{enc(f.describes)}",
          "\"tests\":#{enc(f.tests)}",
          "\"test_count\":#{f.test_count}",
          "\"expect_errors\":#{f.expect_errors}"
        ],
        ","
      ) <> "}"
  end

  defp enc(v), do: Jason.encode!(v)

  @doc "Reference HEAD sha read from `.git` (nil when unavailable)."
  def reference_head(ref_root) do
    git = Path.join(ref_root, ".git")

    with {:ok, content} <- File.read(Path.join(git, "HEAD")) do
      case String.trim(content) do
        "ref: " <> ref ->
          case File.read(Path.join(git, ref)) do
            {:ok, sha} -> String.trim(sha)
            _ -> packed_ref(git, ref)
          end

        sha ->
          sha
      end
    else
      _ -> nil
    end
  end

  defp packed_ref(git, ref) do
    with {:ok, text} <- File.read(Path.join(git, "packed-refs")) do
      text
      |> String.split("\n", trim: true)
      |> Enum.find_value(fn line ->
        case String.split(line, " ", parts: 2) do
          [sha, ^ref] -> sha
          _ -> nil
        end
      end)
    else
      _ -> nil
    end
  end

  @doc false
  def analyze(rel, text) do
    if String.ends_with?(rel, ".exs"),
      do: analyze_exs(rel, text),
      else: {:ok, analyze_ts(rel, text)}
  end

  defp analyze_exs(rel, text) do
    case Code.string_to_quoted(text) do
      {:ok, ast} ->
        {_, {describes, tests}} = Macro.prewalk(ast, {[], []}, &visit/2)

        {:ok,
         %{
           file: rel,
           kind: "exs",
           describes: Enum.reverse(describes),
           tests: Enum.reverse(tests),
           test_count: length(tests),
           expect_errors: 0
         }}

      {:error, {meta, msg, tok}} ->
        {:error, "unparseable: line #{inspect(meta)} #{inspect(msg)} #{inspect(tok)}"}
    end
  end

  defp visit({:describe, _, [title | _]} = node, {d, t}), do: {node, {[title(title) | d], t}}

  defp visit({macro, _, [title | rest]} = node, {d, t})
       when macro in [:test, :property] and rest != [] do
    {node, {d, [title(title) | t]}}
  end

  defp visit(node, acc), do: {node, acc}

  defp title(t) when is_binary(t), do: t
  defp title(t), do: Macro.to_string(t)

  @ts_test [
    ~r/^\s*\/\/\s*Test\s+\d+[a-zA-Z]?\s*[:.\-]\s*(.+?)\s*$/,
    ~r/^\s*export\s+(?:async\s+)?function\s+(\w+)/,
    ~r/\brunTest\(\s*"([^"]+)"/,
    ~r/^\s*(?:it|test)\(\s*["'`]([^"'`]+)/
  ]
  @ts_describe ~r/^\s*describe\(\s*["'`]([^"'`]+)/

  defp analyze_ts(rel, text) do
    lines = String.split(text, "\n")

    tests =
      Enum.flat_map(lines, fn line ->
        Enum.find_value(@ts_test, [], fn re ->
          case Regex.run(re, line) do
            [_, title] -> [title]
            _ -> nil
          end
        end)
      end)

    describes =
      Enum.flat_map(lines, fn line ->
        case Regex.run(@ts_describe, line) do
          [_, t] -> [t]
          _ -> []
        end
      end)

    %{
      file: rel,
      kind: "ts",
      describes: describes,
      tests: tests,
      test_count: length(tests),
      expect_errors: Enum.count(lines, &String.contains?(&1, "@ts-expect-error"))
    }
  end
end
