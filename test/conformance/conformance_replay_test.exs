Code.require_file(Path.expand("../../conformance/elixir/runner.exs", __DIR__))

defmodule AshSurface.ConformanceReplayTest do
  @moduledoc """
  Law pinned: the language-neutral conformance corpus (`conformance/`) is
  EXACTLY what the real Elixir implementation does today.

  Every vector's `input` is replayed through the public implementation
  (`AshSurface.Transport`, `CanonicalJSON`, `from_manifest/2`, `IR.Codec`,
  `Event.from_receipt/2`, `Standing`, `Vocabulary`) via
  `AshSurface.Conformance.Runner` and the result must equal the recorded
  `expected`. A change to the implementation without regenerating the corpus
  (`MIX_ENV=test mix run scripts/conformance_regen.exs`) is RED here; a
  hand-edited `expected` is RED here. The manifest's sha256 pins each file's
  bytes, so a silently edited vector file is RED too.

  The replay is proven able to fail: a vector with a mutated `expected` is
  reported as a mismatch (see the "replay can fail" tests).
  """

  use ExUnit.Case, async: true

  alias AshSurface.CanonicalJSON
  alias AshSurface.Conformance.Runner

  @corpus Path.expand("../../conformance", __DIR__)
  @manifest @corpus |> Path.join("MANIFEST.json") |> File.read!() |> Jason.decode!()
  @levels ~w(MUST MAY PENDING_DECISION)

  defp files, do: Runner.load_files(Path.join(@corpus, "vectors"))

  describe "corpus integrity" do
    test "the manifest lists exactly the vector files on disk, with matching sha256 and counts" do
      on_disk =
        @corpus
        |> Path.join("vectors/*.json")
        |> Path.wildcard()
        |> Enum.map(&Path.basename/1)
        |> Enum.sort()

      listed = @manifest["files"] |> Enum.map(&Path.basename(&1["path"])) |> Enum.sort()
      assert on_disk == listed

      for entry <- @manifest["files"] do
        bytes = File.read!(Path.join(@corpus, entry["path"]))

        assert :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower) == entry["sha256"],
               "#{entry["path"]}: bytes drifted from MANIFEST.json (regenerate)"

        decoded = Jason.decode!(bytes)
        assert length(decoded["vectors"]) == entry["vectorCount"]
        assert decoded["kind"] == entry["kind"]
        assert decoded["corpusVersion"] == @manifest["corpusVersion"]
        assert Enum.frequencies_by(decoded["vectors"], & &1["level"]) == entry["levels"]
      end

      assert @manifest["vectorCount"] ==
               @manifest["files"] |> Enum.map(& &1["vectorCount"]) |> Enum.sum()

      assert @manifest["corpusVersion"] == Runner.corpus_version()
      assert @manifest["lawVersion"] == AshSurface.schema_version()
    end

    test "every vector is {id, description, input, expected, notes, level} with a corpus-unique id" do
      vectors = for {_name, file} <- files(), vector <- file["vectors"], do: vector

      for vector <- vectors do
        assert Enum.sort(Map.keys(vector)) == ~w(description expected id input level notes)
        assert is_binary(vector["id"]) and vector["id"] != ""
        assert vector["level"] in @levels
      end

      ids = Enum.map(vectors, & &1["id"])
      assert ids == Enum.uniq(ids)
      assert length(ids) == @manifest["vectorCount"]
    end

    test "the manifest carries no clock, commit, or host metadata (deterministic regeneration)" do
      assert Enum.sort(Map.keys(@manifest)) ==
               ~w(corpus corpusVersion files hashAlgorithm lawVersion vectorCount)
    end
  end

  describe "replay against the real implementation" do
    for {name, file} <- Runner.load_files(Path.join(@corpus, "vectors")) do
      @file_name name
      @file_kind file["kind"]
      @file_vectors file["vectors"]

      test "#{name}: every vector replays to its recorded expected value" do
        failures =
          for vector <- @file_vectors,
              {:mismatch, want, got} <- [Runner.replay_vector(@file_kind, vector)] do
            {vector["id"], want, got}
          end

        assert failures == [],
               "#{@file_name}: #{length(failures)} vector(s) drifted from the implementation, first: #{inspect(Enum.take(failures, 1))}"
      end
    end

    test "the exhaustive transport table covers the whole small space (each declared set x available x preferred x facts)" do
      {_name, file} = Enum.find(files(), fn {name, _} -> name == "transport_selection.json" end)
      exhaustive = Enum.filter(file["vectors"], &String.starts_with?(&1["id"], "ts/d="))
      # declared sets: [h] 2 avail, [c] 2, [h,c] 5, [c,h] 5  => 14; x2 preferred x13 facts
      assert length(exhaustive) == 14 * 2 * 13

      reasons =
        exhaustive
        |> Enum.map(&get_in(&1, ["expected", "decision", "reason"]))
        |> Enum.uniq()
        |> Enum.sort()

      errors =
        exhaustive
        |> Enum.map(&get_in(&1, ["expected", "error", "kind"]))
        |> Enum.uniq()
        |> Enum.sort()

      assert reasons == [nil, "dimension_weighed", "preferred_available", "preferred_unavailable"]
      assert errors == [nil, "unsupported_transport"]
    end
  end

  describe "replay can fail" do
    test "a mutated expected value is reported as a mismatch (kind by kind)" do
      for {_name, file} <- files() do
        vector = List.first(file["vectors"])
        assert Runner.replay_vector(file["kind"], vector) == :ok

        mutated = Map.put(vector, "expected", mutate(vector["expected"]))

        assert {:mismatch, _want, _got} = Runner.replay_vector(file["kind"], mutated),
               "#{file["kind"]}: mutation went undetected"
      end
    end

    test "a mutated INPUT changes the replayed result (the replay actually consumes the input)" do
      {_n, file} = Enum.find(files(), fn {n, _} -> n == "canonical_json.json" end)
      vector = List.first(file["vectors"])
      other = put_in(vector, ["input", "json"], ~s({"zzz":1}))
      assert {:mismatch, _, _} = Runner.replay_vector("canonical_json", other)
    end
  end

  # Flips one leaf of an expected value so equality cannot survive.
  defp mutate(map) when is_map(map) do
    case Enum.sort(Map.keys(map)) do
      [] -> %{"mutated" => true}
      [key | _] -> Map.update!(map, key, &mutate/1)
    end
  end

  defp mutate(list) when is_list(list), do: [:mutated | list]
  defp mutate(bool) when is_boolean(bool), do: not bool
  defp mutate(number) when is_number(number), do: number + 1
  defp mutate(nil), do: "mutated"
  defp mutate(text) when is_binary(text), do: text <> "-mutated"

  test "canonical-json helper used by the replay is the repo's one CanonicalJSON law" do
    assert CanonicalJSON.encode(%{"b" => 1, "a" => [2]}) == ~s({"a":[2],"b":1})
  end
end
