
defmodule SparkDeadSurfaceCourt do
  @moduledoc false

  @doc """
  Pack root resolution: AEX_PACK_ROOT env wins, else walk upward from cwd looking for
  packs/ash-extension-pack/ontology.ttl. Refuses (raises) instead of guessing.
  """
  def pack_root! do
    with env when is_binary(env) <- System.get_env("AEX_PACK_ROOT"),
         root = Path.expand(env),
         true <- File.exists?(Path.join(root, "ontology.ttl")) do
      Path.expand(env)
    else
      _ -> find_root!(File.cwd!())
    end
  end

  defp find_root!(dir) do
    candidate = Path.join([dir, "packs", "ash-extension-pack", "ontology.ttl"])
    if File.exists?(candidate) do
      Path.join([dir, "packs", "ash-extension-pack"])
    else
      parent = Path.dirname(dir)
      if parent == dir do
        raise "no packs/ash-extension-pack/ontology.ttl found above #{File.cwd!()} (set AEX_PACK_ROOT)"
      end

      find_root!(parent)
    end
  end

  @doc "Declared Spark property surface: every `aex:X a rdf:Property` local name."
  def declared_properties(ontology_text) do
    Regex.scan(~r/aex:([A-Za-z_]\w*)\s+a\s+rdf:Property/, ontology_text)
    |> Enum.map(&List.last/1)
    |> Enum.sort()
    |> Enum.uniq()
  end

  @doc """
  Dead set: declared properties whose local name appears in NO template, gate, query or
  verify script. Real textual grep over templates/ gates/ queries/ verify/.
  """
  def dead_properties(ontology_text, corpus_paths) do
    declared = declared_properties(ontology_text)
    corpus = corpus_paths |> Enum.map(&File.read!/1) |> Enum.join("\n")

    Enum.filter(declared, fn name ->
      not Regex.match?(~r/aex:#{name}\b/, corpus)
    end)
  end

  @doc "Every file the court greps, relative to the pack root."
  def corpus_files(pack_root) do
    Enum.flat_map(["templates", "gates", "queries", "verify"], fn dir ->
      path = Path.join(pack_root, dir)

      case File.ls(path) do
        {:ok, entries} ->
          entries
          |> Enum.sort()
          |> Enum.map(&Path.join(path, &1))
          |> Enum.filter(&File.regular?/1)

        _ ->
          []
      end
    end)
  end
end

defmodule SparkDeadSurfaceCourtTest do
  use ExUnit.Case, async: false

  test "no decorative Spark surface: every declared aex:* property has a consumer" do
    pack_root = SparkDeadSurfaceCourt.pack_root!()
    ontology_text = File.read!(Path.join(pack_root, "ontology.ttl"))
    corpus_files = SparkDeadSurfaceCourt.corpus_files(pack_root)
    declared = SparkDeadSurfaceCourt.declared_properties(ontology_text)
    dead = SparkDeadSurfaceCourt.dead_properties(ontology_text, corpus_files)

    IO.puts("pack_root: #{pack_root}")
    IO.puts("declared properties: #{length(declared)}")
    IO.puts("corpus files grepped: #{length(corpus_files)}")

    assert dead == [],
           """
           DEAD SPARK SURFACE (#{length(dead)} of #{length(declared)} declared properties \
           have zero template/gate consumers in #{pack_root}):

           #{Enum.map_join(dead, "\n", &"  - aex:" <> &1)}
           """
  end
end
