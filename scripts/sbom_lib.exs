# Deterministic CycloneDX 1.5 SBOM generator for ash_surface.
#
# Reads ONLY committed lockfiles (mix.lock, package-lock.json) and the
# `@version` attribute of mix.exs. No network, no environment, no clock, no
# hex/npm tooling: the same inputs always produce byte-identical output, so a
# diff of the SBOM is a diff of the dependency closure. The serialNumber is a
# UUID derived from the SHA-256 of the component list, never random.
#
# Standalone: `elixir scripts/sbom.exs` (see scripts/sbom.sh). Loaded by
# test/ash_surface/supply_chain_test.exs via Code.require_file/1.
unless Code.ensure_loaded?(AshSurface.SBOM) do
  defmodule AshSurface.SBOM do
    @moduledoc false

    @spec build(Path.t(), Path.t(), Path.t()) :: map()
    def build(lock_path, npm_lock_path, mix_exs_path) do
      # with_diagnostics: mix.lock uses quoted keyword keys; keep stderr quiet.
      {{lock, _}, _diagnostics} = Code.with_diagnostics(fn -> Code.eval_file(lock_path) end)
      npm = npm_lock_path |> File.read!() |> decode_json()

      components =
        (Enum.map(lock, fn {k, v} -> hex_or_git({to_string(k), v}) end) ++ npm_components(npm))
        |> Enum.sort_by(&{&1["purl"], &1["name"]})

      %{
        "bomFormat" => "CycloneDX",
        "specVersion" => "1.5",
        "version" => 1,
        "serialNumber" => serial(components),
        "metadata" => %{
          "component" => %{
            "type" => "library",
            "bom-ref" => "pkg:hex/ash_surface@" <> mix_version(mix_exs_path),
            "name" => "ash_surface",
            "version" => mix_version(mix_exs_path),
            "purl" => "pkg:hex/ash_surface@" <> mix_version(mix_exs_path),
            "licenses" => [%{"license" => %{"id" => "MIT"}}]
          },
          "properties" => [
            %{"name" => "ash_surface:sources", "value" => "mix.lock,package-lock.json"}
          ]
        },
        "components" => components
      }
    end

    @spec encode(term()) :: String.t()
    def encode(term), do: IO.iodata_to_binary(enc(term, 0)) <> "\n"

    @spec main([String.t()]) :: :ok
    def main(argv) do
      {opts, _, _} =
        OptionParser.parse(argv,
          strict: [lock: :string, npm_lock: :string, mix_exs: :string, out: :string]
        )

      json =
        build(
          Keyword.get(opts, :lock, "mix.lock"),
          Keyword.get(opts, :npm_lock, "package-lock.json"),
          Keyword.get(opts, :mix_exs, "mix.exs")
        )
        |> encode()

      case opts[:out] do
        nil ->
          IO.write(json)

        path ->
          File.mkdir_p!(Path.dirname(path))
          File.write!(path, json)
      end
    end

    defp hex_or_git({name, {:hex, atom_name, version, inner, _mgrs, _deps, repo, outer}}) do
      purl = "pkg:hex/#{atom_name}@#{version}"

      base(name, version, purl)
      |> Map.put("hashes", [%{"alg" => "SHA-256", "content" => outer}])
      |> Map.put("properties", [
        %{"name" => "hex:inner_checksum_sha256", "value" => inner},
        %{"name" => "hex:repo", "value" => repo}
      ])
    end

    defp hex_or_git({name, {:git, url, sha, opts}}) do
      slug = url |> String.replace(~r{^https://github\.com/|\.git$}, "")
      version = Keyword.get(opts, :tag, sha)

      base(name, version, "pkg:github/#{slug}@#{sha}")
      |> Map.put("externalReferences", [%{"type" => "vcs", "url" => url}])
      |> Map.put("properties", [
        %{"name" => "git:commit", "value" => sha},
        %{"name" => "git:pinned_by", "value" => if(opts[:tag], do: "tag", else: "ref")}
      ])
    end

    defp base(name, version, purl) do
      %{
        "type" => "library",
        "bom-ref" => purl,
        "name" => name,
        "version" => version,
        "purl" => purl
      }
    end

    defp npm_components(%{"packages" => packages}) do
      for {path, meta} <- packages, path != "" do
        name = path |> String.split("node_modules/") |> List.last()

        purl =
          "pkg:npm/" <> String.replace(name, "@", "%40", global: false) <> "@" <> meta["version"]

        base(name, meta["version"], purl)
        |> put_npm_hash(meta["integrity"])
        |> put_npm_license(meta["license"])
      end
    end

    defp put_npm_hash(c, "sha512-" <> b64) do
      Map.put(c, "hashes", [
        %{"alg" => "SHA-512", "content" => b64 |> Base.decode64!() |> Base.encode16(case: :lower)}
      ])
    end

    defp put_npm_hash(c, _), do: c

    defp put_npm_license(c, id) when is_binary(id),
      do: Map.put(c, "licenses", [%{"license" => %{"id" => id}}])

    defp put_npm_license(c, _), do: c

    defp mix_version(path) do
      [_, v] = Regex.run(~r/@version "([^"]+)"/, File.read!(path))
      v
    end

    defp serial(components) do
      <<a::32, b::16, c::16, d::16, e::48, _::binary>> =
        :crypto.hash(:sha256, enc(components, 0) |> IO.iodata_to_binary())

      h = fn n, w ->
        n |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(w, "0")
      end

      "urn:uuid:#{h.(a, 8)}-#{h.(b, 4)}-#{h.(c, 4)}-#{h.(d, 4)}-#{h.(e, 12)}"
    end

    # Minimal deterministic JSON encoder (sorted keys, 2-space indent) so the
    # script needs no dependency and works under bare `elixir`.
    defp enc(map, ind) when is_map(map) and map_size(map) == 0, do: ["{}", pad(ind - ind)]

    defp enc(map, ind) when is_map(map) do
      items =
        map
        |> Enum.sort_by(fn {k, _} -> to_string(k) end)
        |> Enum.map(fn {k, v} -> [pad(ind + 1), str(to_string(k)), ": ", enc(v, ind + 1)] end)

      ["{\n", Enum.intersperse(items, ",\n"), "\n", pad(ind), "}"]
    end

    defp enc([], _), do: "[]"

    defp enc(list, ind) when is_list(list) do
      items = Enum.map(list, fn v -> [pad(ind + 1), enc(v, ind + 1)] end)
      ["[\n", Enum.intersperse(items, ",\n"), "\n", pad(ind), "]"]
    end

    defp enc(s, _) when is_binary(s), do: str(s)
    defp enc(n, _) when is_integer(n), do: Integer.to_string(n)
    defp enc(true, _), do: "true"
    defp enc(false, _), do: "false"
    defp enc(nil, _), do: "null"

    defp pad(n), do: String.duplicate("  ", max(n, 0))

    defp str(s) do
      body =
        for <<c::utf8 <- s>>, into: "" do
          case c do
            ?" -> "\\\""
            ?\\ -> "\\\\"
            ?\n -> "\\n"
            ?\r -> "\\r"
            ?\t -> "\\t"
            c when c < 0x20 -> "\\u" <> String.pad_leading(Integer.to_string(c, 16), 4, "0")
            c -> <<c::utf8>>
          end
        end

      "\"" <> body <> "\""
    end

    # Minimal JSON decoder for package-lock.json: OTP's :json (OTP 27+).
    defp decode_json(bin), do: :json.decode(bin)
  end
end
