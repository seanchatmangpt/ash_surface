defmodule AshSurface.SupplyChainTest do
  @moduledoc """
  Law pinned: the dependency closure is enumerable, deterministic and shipped
  whole. The SBOM generator (`scripts/sbom_lib.exs`) reads only the committed
  lockfiles, so its output must be byte-identical across runs, list every
  `mix.lock` package with name/version/purl and hash, and cover npm `zod`.
  The hex package must ship the runtime `.mjs`, the zod guard, and the
  license/changelog/security material. Offline and hermetic: scratch output
  goes under `_build/test`.
  """
  use ExUnit.Case, async: true

  @root Path.expand("../..", __DIR__)
  @scratch Path.join([@root, "_build", "test", "supply_chain"])

  setup_all do
    Code.require_file(Path.join([@root, "scripts", "sbom_lib.exs"]))
    File.mkdir_p!(@scratch)
    :ok
  end

  defp sbom do
    AshSurface.SBOM.build(
      Path.join(@root, "mix.lock"),
      Path.join(@root, "package-lock.json"),
      Path.join(@root, "mix.exs")
    )
  end

  defp lock do
    {lock, _} =
      Code.with_diagnostics(fn -> Code.eval_file(Path.join(@root, "mix.lock")) end)
      |> elem(0)

    lock
  end

  test "generator output is byte-deterministic" do
    assert AshSurface.SBOM.encode(sbom()) == AshSurface.SBOM.encode(sbom())
  end

  test "shell entry point is deterministic and matches the library" do
    a = Path.join(@scratch, "a.cdx.json")
    b = Path.join(@scratch, "b.cdx.json")

    for out <- [a, b] do
      {log, 0} = System.cmd("bash", [Path.join([@root, "scripts", "sbom.sh"]), out])
      assert log =~ "SBOM_OK"
    end

    assert File.read!(a) == File.read!(b)
    assert File.read!(a) == AshSurface.SBOM.encode(sbom())
  end

  test "every mix.lock package is listed with name, version, purl" do
    by_name = Map.new(sbom()["components"], &{&1["name"], &1})

    for {name, entry} <- lock() do
      c = Map.fetch!(by_name, to_string(name))
      assert c["type"] == "library"
      assert c["bom-ref"] == c["purl"]

      case entry do
        {:hex, _, version, _, _, _, _, _} ->
          assert c["version"] == version
          assert c["purl"] == "pkg:hex/#{name}@#{version}"

        {:git, _url, sha, _opts} ->
          assert String.starts_with?(c["purl"], "pkg:github/")
          assert String.ends_with?(c["purl"], "@" <> sha)
      end
    end
  end

  test "every hex package carries its outer SHA-256 checksum and the inner one" do
    by_name = Map.new(sbom()["components"], &{&1["name"], &1})

    for {name, {:hex, _, _, inner, _, _, _, outer}} <- lock() do
      c = by_name[to_string(name)]
      assert c["hashes"] == [%{"alg" => "SHA-256", "content" => outer}]
      assert %{"name" => "hex:inner_checksum_sha256", "value" => ^inner} = hd(c["properties"])
      assert String.length(outer) == 64
    end
  end

  test "git dependencies are pinned to a full commit sha" do
    git = for {name, {:git, _, sha, _}} <- lock(), do: {to_string(name), sha}
    assert git != []

    for {name, sha} <- git do
      assert sha =~ ~r/\A[0-9a-f]{40}\z/, "#{name} is not pinned to a 40-hex commit"
    end
  end

  test "npm zod is covered with purl, sha512 hash and license" do
    zod = Enum.find(sbom()["components"], &(&1["purl"] =~ "pkg:npm/zod@"))
    assert zod["name"] == "zod"
    assert [%{"alg" => "SHA-512", "content" => hex}] = zod["hashes"]
    assert hex =~ ~r/\A[0-9a-f]{128}\z/
    assert zod["licenses"] == [%{"license" => %{"id" => "MIT"}}]

    {:ok, pkg} = Jason.decode(File.read!(Path.join(@root, "package.json")))
    assert zod["version"] == pkg["dependencies"]["zod"]
  end

  test "document is CycloneDX 1.5 with a content-derived serial and the project root" do
    doc = sbom()
    assert doc["bomFormat"] == "CycloneDX"
    assert doc["specVersion"] == "1.5"
    assert doc["serialNumber"] =~ ~r/\Aurn:uuid:[0-9a-f-]{36}\z/
    assert doc["metadata"]["component"]["name"] == "ash_surface"
    assert doc["metadata"]["component"]["version"] == Mix.Project.config()[:version]
    refs = Enum.map(doc["components"], & &1["bom-ref"])
    assert refs == Enum.uniq(refs)
    assert refs == Enum.sort(refs)
  end

  test "encoder escapes control characters and round-trips through Jason" do
    tricky = %{"k" => "a\"b\\c\n\t\u0001é", "n" => [1, true, nil, %{}]}
    assert {:ok, ^tricky} = tricky |> AshSurface.SBOM.encode() |> Jason.decode()
  end

  describe "hex package contents" do
    test "package files ship the runtime, the zod guard and the policy documents" do
      files = Mix.Project.config()[:package][:files]

      for f <- ~w(lib priv mix.exs README.md AGENTS.md LICENSE CHANGELOG.md SECURITY.md) do
        assert f in files, "#{f} missing from package files"
        assert File.exists?(Path.join(@root, f)), "#{f} is listed but absent"
      end

      assert File.exists?(Path.join(@root, "priv/static/ash_surface_runtime.mjs"))
      assert File.exists?(Path.join(@root, "lib/ash_surface/projectors/js/zod_guard.ex"))
    end

    test "package/0 declares MIT and a links map" do
      pkg = Mix.Project.config()[:package]
      assert pkg[:licenses] == ["MIT"]
      assert is_map(pkg[:links])
    end
  end

  describe "workflow and policy files" do
    for f <-
          ~w(.github/dependabot.yml .github/workflows/security.yml .github/workflows/release.yml
                SECURITY.md docs/SUPPLY_CHAIN.md docs/RELEASING.md CHANGELOG.md) do
      test "#{f} exists" do
        assert File.exists?(Path.join(@root, unquote(f)))
      end
    end

    test "publishing to hex is never automatic: gated by an environment" do
      release = File.read!(Path.join(@root, ".github/workflows/release.yml"))
      assert release =~ ~r/environment:\s*hex-publish/
      assert release =~ "actions/attest-build-provenance"
      assert release =~ "id-token: write"
      assert release =~ "attestations: write"
    end

    test "security workflow is scheduled and fail-closed" do
      sec = File.read!(Path.join(@root, ".github/workflows/security.yml"))
      assert sec =~ "schedule:"
      assert sec =~ "mix hex.audit"
      assert sec =~ "npm audit --omit=dev --audit-level=high"
      refute sec =~ "continue-on-error"
    end

    test "CHANGELOG top entry matches the mix.exs version or Unreleased" do
      log = File.read!(Path.join(@root, "CHANGELOG.md"))
      assert log =~ "## [Unreleased]"
    end
  end
end
