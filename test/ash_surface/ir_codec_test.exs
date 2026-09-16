defmodule AshSurface.IrCodecTest do
  @moduledoc """
  Serialization and content-addressing law of the ash_surface IR codec.

  `AshSurface.IR.Codec` (lib/ash_surface/ir/codec.ex) content-addresses the
  canonical five-section `AshSurface.IR.Surface` map (the surface-contract
  staging IR; the per-action `AshSurface.IR` canon lives in ir.ex) with the *existing* `AshSurface` digest canon:

      canonical map
      |> canonical_term()      # keys stringified + sorted recursively;
      |>                       # list order preserved and semantic
      :erlang.term_to_binary()
      |> :crypto.hash(:sha256, &1)
      |> Base.encode16(case: :lower)

  The canon is private upstream (`AshSurface.digest/2` in lib/ash_surface.ex);
  exactly as `AshSurface.Health` does, the codec runs the same pipeline and
  agreement here is **pinned against freshly built real surfaces** — any drift
  between the codec's digest and `AshSurface.from_manifest/2`'s digest on the
  same contract breaks this build.

  ## What the law demands

    * `to_map/1` emits exactly the five section keys in canonical sorted
      order; nil sections serialize honestly as `nil` (JSON `null`), never as
      fabricated empty maps; the digest never enters the preimage.
    * `from_map/1` is the fail-closed inverse: exactly five keys, each `nil`
      or a JSON-isomorphic map; it recomputes the digest, so
      `from_map(to_map(ir)) == {:ok, ir}` whenever `ir.digest` still
      content-addresses `ir`'s sections.
    * Jason encode/decode round-trips every admitted IR structurally, and
      byte-stably across decode/re-encode.
    * golden digests and golden canonical JSON bytes are frozen in `@golden`
      and `@golden_json`; any drift in section shape, canonicalization, or
      serialization breaks the build by design.
  """

  use ExUnit.Case, async: true

  alias Ash.Info.Manifest
  alias Ash.Info.Manifest.{Action, Entrypoint}
  alias AshSurface.IR.Codec
  alias AshSurface.IR.Surface

  @section_keys ~w(actions identity profile resources transports)

  # Frozen golden digests (64 lowercase hex chars), computed from real
  # `Codec.from_map/1` execution over the 5 fixtures below. Any drift in the
  # IR section shape, the canonical term form, or the digest pipeline breaks
  # these by design.
  @golden %{
    identity_only: "633a62495c5974fced5a0758e77c07cfdcaec8bb548d6ff830100af11b9803ac",
    full_surface: "c74abce9148df05283868b4187300c9264424f0fa53acf2a0757f9ec8e146492",
    sparse: "1724ea713fcae55af51ed09c0abb109db959f181589074e81bd53ad256d64f75",
    large_profile: "b070a62e2a71974c1b702baadcd128f7cd24390a140bf4042dea14bc4ac8090b",
    refusal_actions: "e27979a7ced85c8cf986eb5e9628bddf8dbe8497d8bd393dc4cae62f53b731c8"
  }

  # Frozen golden canonical JSON bytes (Jason over to_map/1). Pins the stable
  # canonical key order end-to-end: top-level sections in canonical sorted
  # order, nil sections as JSON null.
  @golden_json %{
    identity_only:
      ~s({"actions":null,"identity":{"generatorIdentity":"ash_surface:v26.9.13","surfaceSchemaVersion":"26.9.13"},"profile":null,"resources":null,"transports":null}),
    full_surface:
      ~s({"actions":{"entries":[{"authorityBoundary":"OBSERVE","doAuthority":false,"id":"AshSurface.IrPost#read"},{"authorityBoundary":"DO","doAuthority":true,"id":"AshSurface.IrLedger#record"}]},"identity":{"generatorIdentity":"ash_surface:v26.9.13","manifestDigest":"deadbeef","surfaceSchemaVersion":"26.9.13"},"profile":{"audience":"internal","flags":{"verifyReceipts":true}},"resources":{"AshSurface.IrPost":{"attributes":["id","body"]}},"transports":{"declared":["http","phoenix_channel"],"preferred":"http"}})
  }

  defp large_profile do
    Map.new(1..40, fn i -> {"opt" <> String.pad_leading(Integer.to_string(i), 2, "0"), i} end)
  end

  defp canonical_maps do
    [
      identity_only: %{
        "actions" => nil,
        "identity" => %{
          "surfaceSchemaVersion" => "26.9.13",
          "generatorIdentity" => "ash_surface:v26.9.13"
        },
        "profile" => nil,
        "resources" => nil,
        "transports" => nil
      },
      full_surface: %{
        "actions" => %{
          "entries" => [
            %{
              "id" => "AshSurface.IrPost#read",
              "authorityBoundary" => "OBSERVE",
              "doAuthority" => false
            },
            %{
              "id" => "AshSurface.IrLedger#record",
              "authorityBoundary" => "DO",
              "doAuthority" => true
            }
          ]
        },
        "identity" => %{
          "surfaceSchemaVersion" => "26.9.13",
          "generatorIdentity" => "ash_surface:v26.9.13",
          "manifestDigest" => "deadbeef"
        },
        "profile" => %{"audience" => "internal", "flags" => %{"verifyReceipts" => true}},
        "resources" => %{"AshSurface.IrPost" => %{"attributes" => ["id", "body"]}},
        "transports" => %{"declared" => ["http", "phoenix_channel"], "preferred" => "http"}
      },
      sparse: %{
        "actions" => %{
          "entries" => [%{"id" => "AshSurface.IrPost#read", "authorityBoundary" => "OBSERVE"}]
        },
        "identity" => %{"surfaceSchemaVersion" => "26.9.13"},
        "profile" => nil,
        "resources" => nil,
        "transports" => nil
      },
      large_profile: %{
        "actions" => nil,
        "identity" => %{"surfaceSchemaVersion" => "26.9.13"},
        "profile" => large_profile(),
        "resources" => nil,
        "transports" => nil
      },
      refusal_actions: %{
        "actions" => %{
          "entries" => [
            %{
              "id" => "AshSurface.IrLedger#submit",
              "possibleRefusals" => ["REFUSED_NO_AUTHORITY", "REFUSED_UNKNOWN_REVERSIBILITY"]
            },
            %{"id" => "AshSurface.IrLedger#read", "possibleRefusals" => []}
          ]
        },
        "identity" => %{
          "surfaceSchemaVersion" => "26.9.13",
          "generatorIdentity" => "ash_surface:v26.9.13"
        },
        "profile" => %{"audience" => "public"},
        "resources" => nil,
        "transports" => %{"declared" => ["http"]}
      }
    ]
  end

  defp build(name) do
    fixture = canonical_maps()[name]
    assert {:ok, %Surface{} = ir} = Codec.from_map(fixture)
    ir
  end

  describe "IR canonical shape" do
    test "declares exactly the five sections plus digest" do
      assert Surface.sections() == [:actions, :identity, :profile, :resources, :transports]

      assert Enum.sort(Surface.__struct__() |> Map.keys() |> List.delete(:__struct__)) ==
               Enum.sort(Surface.sections() ++ [:digest])
    end

    test "a section may be nil honestly" do
      ir = build(:identity_only)

      for section <- Surface.sections() do
        assert match?(nil, Map.get(ir, section)) or is_map(Map.get(ir, section))
      end

      assert ir.profile == nil and ir.resources == nil and ir.transports == nil
      assert is_map(ir.identity)
    end
  end

  describe "to_map/1" do
    test "emits exactly the five section keys in canonical sorted order" do
      for {name, _} <- canonical_maps() do
        assert Map.keys(Codec.to_map(build(name))) == @section_keys
      end
    end

    test "nil sections serialize honestly as nil, never as fabricated maps" do
      m = Codec.to_map(build(:identity_only))

      assert m["actions"] == nil
      assert m["profile"] == nil
      assert m["resources"] == nil
      assert m["transports"] == nil

      assert m["identity"] == %{
               "surfaceSchemaVersion" => "26.9.13",
               "generatorIdentity" => "ash_surface:v26.9.13"
             }
    end

    test "section content passes through unchanged (no silent transformation)" do
      fixture = canonical_maps()[:full_surface]
      m = Codec.to_map(build(:full_surface))

      for key <- @section_keys, do: assert(m[key] == fixture[key])
    end

    test "the canonical map is the digest preimage: no digest key inside" do
      refute Map.has_key?(Codec.to_map(build(:full_surface)), "digest")
    end
  end

  describe "from_map/1 round-trip" do
    test "from_map(to_map(ir)) == {:ok, ir} — IR.digest field agreement included" do
      for {name, _} <- canonical_maps() do
        ir = build(name)
        assert {:ok, ^ir} = Codec.from_map(Codec.to_map(ir))
      end
    end

    test "round-trip through the golden canonical JSON is byte-stable" do
      for {name, json} <- @golden_json do
        ir = build(name)
        assert Jason.encode!(Codec.to_map(ir)) == json

        assert {:ok, ^ir} = Codec.from_map(Jason.decode!(json))
        assert Jason.encode!(Codec.to_map(build(name))) == json
      end
    end
  end

  describe "Jason encode/decode round-trip" do
    test "Jason.decode!(Jason.encode!(to_map(ir))) == to_map(ir)" do
      for {name, _} <- canonical_maps() do
        m = Codec.to_map(build(name))
        assert Jason.decode!(Jason.encode!(m)) == m
      end
    end

    test "JSON null round-trips to nil sections" do
      assert {:ok, ir} = Codec.from_map(Jason.decode!(@golden_json[:identity_only]))

      assert ir.actions == nil and ir.profile == nil and ir.resources == nil and
               ir.transports == nil

      assert ir.digest == @golden[:identity_only]
    end
  end

  describe "digest/1 — the existing AshSurface canon" do
    test "agrees with AshSurface.from_manifest/2 digests on real surfaces (reuse pin)" do
      ep = fn res, name, type ->
        %Entrypoint{resource: res, action: struct!(Action, name: name, type: type, custom: %{})}
      end

      plain = %Manifest{entrypoints: [ep.(AshSurface.IrPost, :read, :read)]}

      profiled = %Manifest{
        entrypoints: [ep.(AshSurface.IrLedger, :record, :create)]
      }

      assert {:ok, s1} = AshSurface.from_manifest(plain, profile: %{})
      assert Codec.digest(s1.contract) == s1.digest

      assert {:ok, s2} =
               AshSurface.from_manifest(profiled,
                 profile: %{audience: :internal, transports: [:http, :phoenix_channel]}
               )

      assert Codec.digest(s2.contract) == s2.digest
    end

    test "digest text form is 64 lowercase hex characters" do
      for {name, _} <- canonical_maps() do
        assert Codec.digest(Codec.to_map(build(name))) =~ ~r/^[0-9a-f]{64}$/
      end
    end

    test "is deterministic: repeated calls yield one digest" do
      m = Codec.to_map(build(:full_surface))
      assert Enum.uniq(for(_ <- 1..7, do: Codec.digest(m))) |> length() == 1
    end

    test "IR.digest field agreement: digest(to_map(ir)) == ir.digest" do
      for {name, _} <- canonical_maps() do
        ir = build(name)
        assert Codec.digest(Codec.to_map(ir)) == ir.digest
      end
    end

    test "golden-frozen digest vectors" do
      computed = Map.new(canonical_maps(), fn {name, _} -> {name, build(name).digest} end)
      assert computed == @golden
    end

    test "key-order independent: shuffled top-level and reversed >32-key section" do
      shuffled =
        canonical_maps()[:full_surface]
        |> Map.to_list()
        |> Enum.reverse()
        |> Map.new()

      assert Codec.digest(shuffled) == Codec.digest(canonical_maps()[:full_surface])

      reversed_profile =
        1..40
        |> Enum.reverse()
        |> Map.new(fn i -> {"opt" <> String.pad_leading(Integer.to_string(i), 2, "0"), i} end)

      assert map_size(reversed_profile) > 32

      assert Codec.digest(Map.put(canonical_maps()[:large_profile], "profile", reversed_profile)) ==
               @golden[:large_profile]
    end

    test "sensitive to any section change, to nil-vs-empty, and to list order" do
      base = canonical_maps()[:full_surface]
      base_digest = Codec.digest(base)

      for key <- @section_keys do
        changed = put_in(base[key]["mutated"], true)

        refute Codec.digest(changed) == base_digest,
               "expected change in #{key} to move the digest"
      end

      nil_vs_empty = Map.put(canonical_maps()[:identity_only], "profile", %{})
      refute Codec.digest(nil_vs_empty) == Codec.digest(canonical_maps()[:identity_only])

      [first, second] = get_in(base["actions"]["entries"])
      reordered = put_in(base["actions"]["entries"], [second, first])
      refute Codec.digest(reordered) == base_digest
    end
  end

  describe "from_map/1 refuses fail-closed" do
    test "non-map subjects" do
      for bad <- [:nope, "nope", 42, nil, [section: %{}]] do
        assert {:error, {:ir_map_required, ^bad}} = Codec.from_map(bad)
      end
    end

    test "missing section keys" do
      dropped = Map.drop(canonical_maps()[:full_surface], ["profile", "transports"])
      assert {:error, {:missing_ir_sections, ["profile", "transports"]}} = Codec.from_map(dropped)
    end

    test "unknown section keys — including a carried digest" do
      with_digest =
        Map.put(canonical_maps()[:full_surface], "digest", "0" <> String.duplicate("0", 63))

      assert {:error, {:unknown_ir_sections, ["digest"]}} = Codec.from_map(with_digest)
    end

    test "sections that are neither maps nor nil" do
      for bad_value <- [[], "entries", 7] do
        assert {:error, {:section_must_be_map_or_nil, "actions", ^bad_value}} =
                 Codec.from_map(Map.put(canonical_maps()[:full_surface], "actions", bad_value))
      end
    end

    test "non-JSON-isomorphic section content" do
      for {label, value} <- [
            {"tuple leaf", %{"t" => {:error, :tuple}}},
            {"atom nested key", %{atom_key: 1}},
            {"tuple leaf inside a list", %{"l" => ["a", {:inner, 1}]}},
            {"atom value inside a list", %{"l" => [:http]}},
            {"non-UTF-8 binary", %{"b" => <<0xFF, 0xFE>>}}
          ] do
        assert {:error, {:not_json_isomorphic, "transports", _}} =
                 Codec.from_map(Map.put(canonical_maps()[:full_surface], "transports", value)),
               label
      end
    end

    test "structs are not IR maps" do
      ir = %Surface{actions: nil, identity: nil, profile: nil, resources: nil, transports: nil}
      assert {:error, {:ir_map_required, ^ir}} = Codec.from_map(ir)
    end
  end
end
