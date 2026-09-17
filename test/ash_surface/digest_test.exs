defmodule AshSurface.DigestTest do
  @moduledoc """
  Determinism law of the SHA-256 content digest over the cross-language contract.

  `AshSurface.from_manifest/2` (lib/ash_surface.ex) digests the whole contract
  map with the private `digest/1` pipeline:

      contract
      |> canonical_term()
      |> :erlang.term_to_binary()
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

  ## The exact canonical form (frozen law; drift must break this build)

  `canonical_term/1` rewrites the contract recursively before hashing:

    * **map** -> `Enum.map(fn {k, v} -> {to_string(k), canonical_term(v)} end)`
      followed by `Enum.sort_by(&elem(&1, 0))`: a key-stringified list of
      two-element tuples sorted lexicographically (byte order) by key. Map
      iteration order — insertion order for small maps, hash order for maps
      with more than 32 keys — therefore never reaches the hash.
    * **list** -> element-wise recursion. **List order is preserved and is
      semantic content**: reordering entrypoints (or any list inside the
      contract) changes the digest.
    * **any other term** (binary, integer, boolean, nil, atom value) passes
      through unchanged.

  Profiles are JSON-normalized (`normalize_data/1`) before the contract is
  built: atom keys and atom values become strings, so `:audience` and
  `"audience"` spellings digest identically.

  ## What the law demands

    * identical contract -> identical digest, on every call;
    * structurally equal but differently ordered / differently keyed inputs ->
      identical digest;
    * any field change (action id, action type and derived authority boundary,
      manifest semantics, transport declaration, profile metadata) -> a
      different digest;
    * the golden vectors frozen in `@golden` pin 5 fixtures so that any drift
      in schema versions, generator identity, serialization, or
      canonicalization breaks the build.
  """

  use ExUnit.Case, async: true

  alias Ash.Info.Manifest
  alias Ash.Info.Manifest.{Action, Entrypoint}

  # Frozen golden digests (64 lowercase hex chars). These pin the exact
  # contract bytes of the 5 fixtures below; any drift in @surface_schema_version,
  # @generator_identity, the Ash manifest serialization, profile normalization,
  # or canonical_term breaks this test by design.
  # v26.9.16 delegation: re-frozen after semanticId/authorityBoundary/
  # doAuthority/receiptRequired stopped being derived in the surface envelope
  # (delegated facts now surface from custom.ash_surface or as nil).
  @golden %{
    minimal_read: "cab081a03811a036c50c47152f6fb1300ceb7abf337f044673c710f18eede93b",
    two_actions: "4e9ebfdb4a5c8cd60b0382e4d933b3a34f0ed8676cc343e3d6d6809a88af5ed2",
    profiled_action: "0b2ca6642b20d0a0c96b3fc7edb0d187c0cbd97c3c492fe5a3caef5c5b94c3d9",
    transport_metadata: "5fb5de537d5ec6c3a9fc9ad8e1ac6d163aff2d391b34e33964d35762fdd5599a",
    large_map_profile: "4ded9cc009991b095b1bbed7880d6078e727ca7fd91f5a2666910bdc8e5ec8a8"
  }

  defp entrypoint(resource, name, type, action_opts \\ []) do
    %Entrypoint{
      resource: resource,
      action: struct!(Action, Keyword.merge([name: name, type: type, custom: %{}], action_opts))
    }
  end

  defp manifest(entrypoints), do: %Manifest{entrypoints: entrypoints}

  defp build(manifest_fixture, profile) do
    assert {:ok, surface} = AshSurface.from_manifest(manifest_fixture, profile: profile)
    surface
  end

  defp large_map do
    Map.new(1..40, fn i ->
      {"k" <> String.pad_leading(Integer.to_string(i), 2, "0"), i}
    end)
  end

  defp large_map_reversed do
    1..40
    |> Enum.reverse()
    |> Map.new(fn i -> {"k" <> String.pad_leading(Integer.to_string(i), 2, "0"), i} end)
  end

  defp golden_fixtures do
    large_profile =
      Map.new(1..40, fn i ->
        {"opt" <> String.pad_leading(Integer.to_string(i), 2, "0"), i}
      end)

    [
      minimal_read: {
        manifest([entrypoint(AshSurface.DigestPost, :read, :read)]),
        %{}
      },
      two_actions: {
        manifest([
          entrypoint(AshSurface.DigestPost, :read, :read),
          entrypoint(AshSurface.DigestPost, :record, :create)
        ]),
        %{}
      },
      profiled_action: {
        manifest([
          entrypoint(AshSurface.DigestLedger, :record, :create,
            description: "Records an externally witnessed milestone"
          )
        ]),
        %{
          audience: :public,
          actions: %{
            "AshSurface.DigestLedger#record" => %{receiptRequired: false, evidenceRequired: true}
          }
        }
      },
      transport_metadata: {
        manifest([
          entrypoint(AshSurface.DigestPost, :list, :read, description: "Lists digests v1")
        ]),
        %{
          audience: :internal,
          transports: [:http, :phoenix_channel],
          flags: %{verify_receipts: true}
        }
      },
      large_map_profile: {
        manifest([
          entrypoint(AshSurface.DigestLedger, :read, :read),
          entrypoint(AshSurface.DigestLedger, :submit, :create,
            description: "Submits for receipt"
          )
        ]),
        Map.merge(large_profile, %{
          "actions" => %{
            "AshSurface.DigestLedger#submit" => %{"possibleRefusals" => ["REFUSED_NO_AUTHORITY"]}
          }
        })
      }
    ]
  end

  # Independent re-derivation of the documented canonical form. If the
  # implementation drifts from the moduledoc, this shadow disagrees.
  defp shadow_digest(contract) do
    contract
    |> shadow_canonical_term()
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp shadow_canonical_term(term) when is_map(term) do
    term
    |> Enum.map(fn {key, value} -> {to_string(key), shadow_canonical_term(value)} end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  defp shadow_canonical_term(term) when is_list(term),
    do: Enum.map(term, &shadow_canonical_term/1)

  defp shadow_canonical_term(term), do: term

  defp canonicalization_cases do
    manifest_fixture =
      manifest([
        entrypoint(AshSurface.DigestPost, :read, :read),
        entrypoint(AshSurface.DigestPost, :record, :create)
      ])

    [
      {"profile insertion order, including nested maps",
       {manifest_fixture, %{zeta: 26, alpha: 1, nested: %{second: 2, first: 1}}},
       {manifest_fixture, %{nested: %{first: 1, second: 2}, alpha: 1, zeta: 26}}},
      {"atom keys and values vs string spellings",
       {manifest_fixture, %{audience: :public, transports: [:http, :phoenix_channel]}},
       {manifest_fixture, %{"audience" => "public", "transports" => ["http", "phoenix_channel"]}}},
      {"large hash-ordered map (more than 32 keys), rebuilt in reverse insertion order",
       {manifest_fixture, large_map()}, {manifest_fixture, large_map_reversed()}},
      {"action profile map key order",
       {manifest_fixture,
        %{
          actions: %{
            "AshSurface.DigestPost#record" => %{receiptRequired: false},
            "AshSurface.DigestPost#read" => %{consumer: "web"}
          }
        }},
       {manifest_fixture,
        %{
          actions: %{
            "AshSurface.DigestPost#read" => %{consumer: "web"},
            "AshSurface.DigestPost#record" => %{receiptRequired: false}
          }
        }}}
    ]
  end

  defp sensitivity_cases do
    base_manifest =
      manifest([
        entrypoint(AshSurface.DigestPost, :read, :read),
        entrypoint(AshSurface.DigestPost, :record, :create)
      ])

    [
      {"action id: action name :record -> :log", {base_manifest, %{}},
       {
         manifest([
           entrypoint(AshSurface.DigestPost, :read, :read),
           entrypoint(AshSurface.DigestPost, :log, :create)
         ]),
         %{}
       }},
      # v26.9.16 delegation: authorityBoundary is no longer derived from action
      # type, but the serialized manifest action type itself still changes the
      # contract bytes.
      {"action type :read -> :create (serialized manifest semantics change)",
       {
         manifest([entrypoint(AshSurface.DigestPost, :fetch, :read)]),
         %{}
       },
       {
         manifest([entrypoint(AshSurface.DigestPost, :fetch, :create)]),
         %{}
       }},
      {"action description (manifest semantics)",
       {
         manifest([
           entrypoint(AshSurface.DigestPost, :list, :read, description: "Lists digests v1")
         ]),
         %{}
       },
       {
         manifest([
           entrypoint(AshSurface.DigestPost, :list, :read, description: "Lists digests v2")
         ]),
         %{}
       }},
      {"transport declaration (profile metadata)", {base_manifest, %{transports: [:http]}},
       {base_manifest, %{transports: [:http, :phoenix_channel]}}},
      {"profile metadata: audience public -> internal", {base_manifest, %{audience: "public"}},
       {base_manifest, %{audience: "internal"}}},
      {"action profile metadata: possibleRefusals", {base_manifest, %{}},
       {
         base_manifest,
         %{
           actions: %{
             "AshSurface.DigestPost#record" => %{possibleRefusals: ["REFUSED_NO_AUTHORITY"]}
           }
         }
       }},
      {"entrypoint declaration order (list order is semantic, not canonicalized)",
       {
         manifest([
           entrypoint(AshSurface.DigestPost, :read, :read),
           entrypoint(AshSurface.DigestPost, :record, :create)
         ]),
         %{}
       },
       {
         manifest([
           entrypoint(AshSurface.DigestPost, :record, :create),
           entrypoint(AshSurface.DigestPost, :read, :read)
         ]),
         %{}
       }}
    ]
  end

  describe "digest determinism" do
    test "is a pure function of the contract: repeated builds yield one digest" do
      for {_name, {manifest_fixture, profile}} <- golden_fixtures() do
        digests = for _ <- 1..7, do: build(manifest_fixture, profile).digest

        assert Enum.uniq(digests) == [List.first(digests)],
               "expected one unique digest across 7 builds, got: #{inspect(Enum.uniq(digests))}"
      end
    end

    test "digest text form is 64 lowercase hex characters" do
      for {_name, {manifest_fixture, profile}} <- golden_fixtures() do
        assert build(manifest_fixture, profile).digest =~ ~r/^[0-9a-f]{64}$/
      end
    end

    test "every fixture digest is re-derived by the documented canonical form" do
      for {_name, {manifest_fixture, profile}} <- golden_fixtures() do
        surface = build(manifest_fixture, profile)
        assert surface.digest == shadow_digest(surface.contract)
      end
    end
  end

  describe "canonicalization: structurally equal, differently ordered inputs" do
    test "digest identically" do
      for {label, {manifest_a, profile_a}, {manifest_b, profile_b}} <- canonicalization_cases() do
        a = build(manifest_a, profile_a)
        b = build(manifest_b, profile_b)

        assert a.digest == b.digest,
               "#{label}: expected identical digests, got #{a.digest} != #{b.digest}"
      end
    end

    test "large-map fixture really exercises hash-ordered iteration" do
      large = large_map()
      large_reversed = large_map_reversed()

      assert map_size(large) > 32
      assert map_size(large_reversed) > 32
      assert large == large_reversed
    end
  end

  describe "sensitivity: any field change" do
    test "produces a different digest" do
      for {label, {manifest_a, profile_a}, {manifest_b, profile_b}} <- sensitivity_cases() do
        a = build(manifest_a, profile_a)
        b = build(manifest_b, profile_b)

        refute a.digest == b.digest, "#{label}: expected different digests, got #{a.digest}"
      end
    end
  end

  describe "golden-frozen digest vectors" do
    test "frozen digests for the 5 contract fixtures" do
      computed =
        Map.new(golden_fixtures(), fn {name, {manifest_fixture, profile}} ->
          {name, build(manifest_fixture, profile).digest}
        end)

      assert computed == @golden
    end
  end
end
