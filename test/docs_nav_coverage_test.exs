defmodule AshSurface.DocsNavCoverageTest do
  @moduledoc """
  Nav-coverage court: binds `docs/diataxis/README.md` entries to the files under
  `docs/diataxis/{tutorials,how-to,reference,explanation}/` in both directions.

  Every file must be indexed in the README, and every README link must resolve
  to an existing file. A new diataxis page without a README entry fails this
  court; a README link to a moved/deleted page fails it too.
  """

  use ExUnit.Case, async: true

  @readme "docs/diataxis/README.md"
  @quadrants ["tutorials", "how-to", "reference", "explanation"]

  @readme_text File.read!(@readme)

  defp readme_links do
    Regex.scan(~r{\]\(([^)]+\.md)\)}, @readme_text)
    |> Enum.map(fn [_, link] -> link end)
    |> Enum.uniq()
  end

  defp diataxis_files do
    for quad <- @quadrants, path <- Path.wildcard("docs/diataxis/#{quad}/*.md"), do: path
  end

  test "README exists at the canonical path" do
    assert File.exists?(@readme)
  end

  test "every README link resolves to an existing diataxis file (README -> files)" do
    links = readme_links()
    assert links != [], "expected README to index diataxis pages"

    for link <- links do
      path = Path.join("docs/diataxis", link)
      assert File.exists?(path), "README links to #{link} but #{path} does not exist"
    end
  end

  test "every diataxis file is indexed in the README (files -> README)" do
    files = diataxis_files()
    assert files != [], "expected diataxis pages to exist"

    for file <- files do
      link = Path.relative_to(file, "docs/diataxis")
      assert link in readme_links(),
             "file #{file} is not indexed in #{@readme} (expected a (#{link}) link)"
    end
  end
end