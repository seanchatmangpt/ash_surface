defmodule AshSurface.VocabularyDriftTest do
  @moduledoc """
  Drift law: `AshSurface.Vocabulary.to_map/0` and the JS runtime's exported
  `VOCABULARY` (+ `STANDING_VALUES`) are the same closed sets. Runs the real
  runtime under Node via test/js/vocabulary_dump.mjs and deep-compares. A change
  on either side fails here until the other follows.
  """
  use ExUnit.Case, async: true

  @dump Path.expand("../js/vocabulary_dump.mjs", __DIR__)

  setup_all do
    {out, status} = System.cmd("node", [@dump], stderr_to_stdout: true)
    assert status == 0, "node vocabulary dump failed: #{out}"
    {:ok, js: Jason.decode!(out)}
  end

  test "every Elixir vocabulary key is exported by JS with an identical value", %{js: js} do
    for {key, value} <- AshSurface.Vocabulary.to_map() do
      assert Map.has_key?(js, key), "JS runtime does not export #{key}"
      assert js[key] == value, "drift on #{key}: js=#{inspect(js[key])} elixir=#{inspect(value)}"
    end
  end

  test "JS exports no comparable key Elixir lacks", %{js: js} do
    assert Enum.sort(Map.keys(js)) == Enum.sort(Map.keys(AshSurface.Vocabulary.to_map()))
  end
end
