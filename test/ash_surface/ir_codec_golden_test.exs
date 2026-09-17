# ---------------------------------------------------------------------------
# Canonical local declaration of lib/ash_surface/ir.ex + ir/codec.ex (absent
# at this commit). This file deepens v09's codec law (to_map/from_map/digest)
# onto the canonical v26.9.16 five-section SurfaceIR family.
#
# The IR, its five embedded section structs, and the codec are declared here so
# the golden codec law below is executable under operator file discipline
# (test/ash_surface/ir_codec_golden_test.exs ONLY). When admitted
# lib/ash_surface/ir.ex / lib/ash_surface/ir/codec.ex modules land, this local
# block must be deleted and these tests must bind to the admitted modules;
# the laws below must not change.
#
# Canonical shape frozen here (field sets pinned verbatim in tests):
#
#   AshSurface.IRCodecGoldenTest.IR.Ash          resource action action_type inputs outputs policies
#   AshSurface.IRCodecGoldenTest.IR.Semantic     subject_iri capability_iri predicates shape_id ontology
#   AshSurface.IRCodecGoldenTest.IR.Capability   capability_id consequence_class authority_required receipt_required
#   AshSurface.IRCodecGoldenTest.IR.Presentation label group order widget format
#   AshSurface.IRCodecGoldenTest.IR.Schema       input output zod aria
#   AshSurface.IR              version digest + the five sections above
# ---------------------------------------------------------------------------

defmodule AshSurface.IRCodecGoldenTest.IR.Ash do
  @moduledoc """
  Ash-semantics section: manifest-level facts about one Ash interaction.

  A pure data carrier. It must never carry an execute path.
  """

  defstruct [:resource, :action, :action_type, :inputs, :outputs, :policies]

  @type t :: %__MODULE__{
          resource: String.t() | nil,
          action: String.t() | nil,
          action_type: String.t() | nil,
          inputs: [map()] | nil,
          outputs: map() | nil,
          policies: [map()] | nil
        }
end

defmodule AshSurface.IRCodecGoldenTest.IR.Semantic do
  @moduledoc """
  Semantic section: IRI-anchored meaning (subjects, predicates, ontology).

  A pure data carrier. It must never carry an execute path.
  """

  defstruct [:subject_iri, :capability_iri, :predicates, :shape_id, :ontology]

  @type t :: %__MODULE__{
          subject_iri: String.t() | nil,
          capability_iri: String.t() | nil,
          predicates: map() | nil,
          shape_id: String.t() | nil,
          ontology: String.t() | nil
        }
end

defmodule AshSurface.IRCodecGoldenTest.IR.Capability do
  @moduledoc """
  Capability section: consequence class and authority posture of a capability.

  Recorded requirements, never grants. `authority_required`/`receipt_required`
  default to `false`; the IR confers no DO-authority either way.
  """

  defstruct [
    :capability_id,
    :consequence_class,
    authority_required: false,
    receipt_required: false
  ]

  @type t :: %__MODULE__{
          capability_id: String.t() | nil,
          consequence_class: String.t() | nil,
          authority_required: boolean(),
          receipt_required: boolean()
        }
end

defmodule AshSurface.IRCodecGoldenTest.IR.Presentation do
  @moduledoc """
  Presentation section: pure-presentation placement (label, group, widget).

  A pure data carrier. It must never carry an execute path.
  """

  defstruct [:label, :group, :order, :widget, :format]

  @type t :: %__MODULE__{
          label: String.t() | nil,
          group: String.t() | nil,
          order: non_neg_integer() | nil,
          widget: String.t() | nil,
          format: String.t() | nil
        }
end

defmodule AshSurface.IRCodecGoldenTest.IR.Schema do
  @moduledoc """
  Schema section: shape facts for the consumer boundary (input, output, zod, aria).

  A pure data carrier. It must never carry an execute path.
  """

  defstruct [:input, :output, :zod, :aria]

  @type t :: %__MODULE__{
          input: map() | nil,
          output: map() | nil,
          zod: String.t() | nil,
          aria: map() | nil
        }
end

defmodule AshSurface.IRCodecGoldenTest.IR do
  @moduledoc """
  Intermediate representation between the Ash manifest and consumer projections.

  The IR is a pure data term: five independently nil-able sections plus
  `version`/`digest`. The all-sections-nil IR is legal (the pure-presentation
  dumb screen). No module in this namespace carries an execute path.
  """

  @sections [:ash, :semantic, :capability, :presentation, :schema]

  defstruct [:version, :digest | @sections]

  @type section_key :: :ash | :semantic | :capability | :presentation | :schema
  @type t :: %__MODULE__{
          version: String.t() | nil,
          digest: String.t() | nil,
          ash: AshSurface.IRCodecGoldenTest.IR.Ash.t() | nil,
          semantic: AshSurface.IRCodecGoldenTest.IR.Semantic.t() | nil,
          capability: AshSurface.IRCodecGoldenTest.IR.Capability.t() | nil,
          presentation: AshSurface.IRCodecGoldenTest.IR.Presentation.t() | nil,
          schema: AshSurface.IRCodecGoldenTest.IR.Schema.t() | nil
        }

  @doc "The canonical section keys in source order. Deterministic."
  @spec sections() :: [section_key()]
  def sections, do: @sections
end

defmodule AshSurface.IRCodecGoldenTest.Codec do
  @moduledoc """
  Serialization and content addressing for the five-section `AshSurface.IR`.

  Laws implemented here (deepening v09's codec law onto the v26.9.16 canonical
  section family):

    * `to_map/1` — the canonical map: exactly the string keys `"version"` plus
      the five section keys, each section a map of *all* its declared fields
      (string keys, sorted) or `nil` when the section is honestly absent.
      Nil-honesty holds at both levels: a nil section is `nil` (JSON `null`),
      never a fabricated empty map, and a nil *field* inside a present section
      is `null`, never dropped. `digest` never enters the canonical map; the
      map is the digest preimage.
    * `from_map/1` — forward-tolerant inverse: the five section keys must be
      present (missing keys are typed-rejected), but *unknown extra keys are
      ignored* — a future IR version's new sections/fields cannot break this
      reader, and a carried `"digest"` is ignored in favor of the recomputed
      one. Section values must be `nil` or JSON-isomorphic maps (binary keys;
      UTF-8 string/number/boolean/nil leaves; lists; maps) — anything else is
      typed-rejected. The returned struct's `digest` is always recomputed from
      the admitted content.
    * `digest/1` — the existing `AshSurface` digest canon (private upstream in
      lib/ash_surface.ex): SHA-256 over `:erlang.term_to_binary/1` of the
      canonical term (map keys stringified and sorted recursively; list order
      preserved and semantic), hex-encoded lowercase. Agreement is pinned
      against freshly built real `AshSurface.from_manifest/2` surfaces.

  Key-order honesty: every canonical map is built with keys inserted in sorted
  order, and small maps iterate key-sorted (Erlang flatmaps), so Jason emits
  byte-stable golden JSON. The *contractual* order-independence lives in
  `digest/1`, whose canon sorts keys before hashing.
  """

  alias AshSurface.IRCodecGoldenTest.IR

  @ash_fields ~w(action action_type inputs outputs policies resource)
  @semantic_fields ~w(capability_iri ontology predicates shape_id subject_iri)
  @capability_fields ~w(authority_required capability_id consequence_class receipt_required)
  @presentation_fields ~w(format group label order widget)
  @schema_fields ~w(aria input output zod)

  @section_keys ~w(ash capability presentation schema semantic)

  @doc """
  Projects an IR into its canonical map: `version` plus the five section keys,
  each section nil-honestly serialized (nil section -> nil; present section ->
  all declared fields, nil fields as nil).
  """
  @spec to_map(IR.t()) :: map()
  def to_map(%IR{} = ir) do
    %{
      "ash" => section_to_map(ir.ash, IR.Ash, @ash_fields),
      "capability" => section_to_map(ir.capability, IR.Capability, @capability_fields),
      "presentation" => section_to_map(ir.presentation, IR.Presentation, @presentation_fields),
      "schema" => section_to_map(ir.schema, IR.Schema, @schema_fields),
      "semantic" => section_to_map(ir.semantic, IR.Semantic, @semantic_fields),
      "version" => ir.version
    }
  end

  @doc """
  Forward-tolerant inverse of `to_map/1`.

  Requires the five section keys (each `nil` or a JSON-isomorphic map) and a
  string-or-nil `version`. Unknown top-level and section-internal keys are
  ignored. Recomputes the digest over the admitted content.
  """
  @spec from_map(term()) :: {:ok, IR.t()} | {:error, term()}
  def from_map(map) when is_map(map) and not is_struct(map) do
    with :ok <- require_sections(map),
         :ok <- require_version(map),
         :ok <- require_section_shapes(map) do
      ir = %IR{
        version: map["version"],
        ash: build_section(map["ash"], IR.Ash, @ash_fields),
        semantic: build_section(map["semantic"], IR.Semantic, @semantic_fields),
        capability: build_section(map["capability"], IR.Capability, @capability_fields),
        presentation: build_section(map["presentation"], IR.Presentation, @presentation_fields),
        schema: build_section(map["schema"], IR.Schema, @schema_fields)
      }

      {:ok, %{ir | digest: digest(to_map(ir))}}
    end
  end

  def from_map(other), do: {:error, {:ir_map_required, other}}

  @doc """
  Content-addresses a canonical map with the existing `AshSurface` digest
  canon: SHA-256 over `:erlang.term_to_binary/1` of the canonical term, as
  lowercase hex (64 characters).
  """
  @spec digest(map()) :: String.t()
  def digest(canonical_map) when is_map(canonical_map) do
    canonical_map
    |> canonical_term()
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  def digest(other), do: raise(ArgumentError, "digest/1 requires a map, got: #{inspect(other)}")

  # The exact AshSurface canon (lib/ash_surface.ex), mirrored only because the
  # upstream function is private (same standing as AshSurface.Health);
  # agreement is pinned by tests against real from_manifest/2 surfaces.
  defp canonical_term(term) when is_map(term) do
    term
    |> Enum.map(fn {key, value} -> {to_string(key), canonical_term(value)} end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  defp canonical_term(term) when is_list(term), do: Enum.map(term, &canonical_term/1)
  defp canonical_term(term), do: term

  defp section_to_map(nil, _module, _fields), do: nil

  defp section_to_map(%module{} = section, module, fields) do
    Map.new(fields, fn field -> {field, Map.get(section, String.to_existing_atom(field))} end)
  end

  defp require_sections(map) do
    missing = Enum.filter(@section_keys, fn key -> not Map.has_key?(map, key) end)

    if missing == [],
      do: :ok,
      else: {:error, {:missing_ir_sections, Enum.sort(missing)}}
  end

  defp require_version(map) do
    case map do
      %{"version" => version} when not is_binary(version) and not is_nil(version) ->
        {:error, {:version_must_be_string_or_nil, version}}

      _ ->
        :ok
    end
  end

  defp require_section_shapes(map) do
    Enum.find_value(@section_keys, :ok, fn key ->
      case Map.fetch!(map, key) do
        nil -> nil
        value when is_map(value) and not is_struct(value) -> json_isomorphic(key, value)
        value -> {:error, {:section_must_be_map_or_nil, key, value}}
      end
    end)
  end

  # Rebuilds a section struct from its JSON map. Only declared fields are read
  # (unknown fields are forward-tolerantly ignored); a nil/absent field means
  # the struct's declared default — nil-honest at the leaf level too.
  defp build_section(nil, _module, _fields), do: nil

  defp build_section(map, module, fields) when is_map(map) do
    kw =
      for field <- fields,
          value = Map.get(map, field),
          not is_nil(value),
          do: {String.to_existing_atom(field), value}

    struct(module, kw)
  end

  # Deep JSON-isomorphism admission: what Jason.encode!/1 can encode and
  # Jason.decode!/1 brings back structurally identical — binary keys only,
  # UTF-8 binaries / numbers / booleans / nil leaves, lists, and maps.
  defp json_isomorphic(section, value) do
    cond do
      is_binary(value) ->
        if String.valid?(value), do: nil, else: {:error, {:not_json_isomorphic, section, value}}

      is_number(value) or is_boolean(value) or is_nil(value) ->
        nil

      is_list(value) ->
        Enum.find_value(value, nil, &json_isomorphic(section, &1))

      is_map(value) and not is_struct(value) ->
        Enum.find_value(value, nil, fn {k, v} ->
          if is_binary(k),
            do: json_isomorphic(section, v),
            else: {:error, {:not_json_isomorphic, section, k}}
        end)

      true ->
        {:error, {:not_json_isomorphic, section, value}}
    end
  end
end

defmodule AshSurface.IrCodecGoldenTest do
  @moduledoc """
  Golden-depth law of the five-section IR codec: `to_map/1`, `from_map/1`,
  `digest/1`.

  ## What the law demands (this change's mission)

    * **golden JSON** — the fully-populated five-section IR and the minimal
      presentation-only IR each have frozen canonical JSON bytes (`@golden_json`)
      and frozen digests (`@golden`); any drift in section shape, field
      serialization, canonicalization, or the digest pipeline breaks the build
      by design.
    * **nil-section honesty** — every section key is present in the canonical
      map; an absent section is `nil` (JSON `null`), never a fabricated empty
      map; nil *fields* inside a present section serialize as `null` too; and
      `null` is never silently equal to a present-but-empty section.
    * **digest sensitivity table** — a one-field change in *each* section (and
      in `version`) flips the digest; nil-vs-present and nil-vs-empty-struct
      flips flip it too.
    * **from_map forward-tolerance** — unknown extra top-level keys (including
      a carried `"digest"`) and unknown section-internal fields are ignored;
      wrong-typed subjects, missing sections, wrong-typed section values,
      wrong-typed `version`, and non-JSON-isomorphic content are typed-rejected.
    * **reuse pin** — the codec's digest canon agrees with real
      `AshSurface.from_manifest/2` surface digests, so upstream drift in the
      private canon breaks this suite.
  """

  use ExUnit.Case, async: true

  alias Ash.Info.Manifest
  alias Ash.Info.Manifest.{Action, Entrypoint}
  alias AshSurface.IRCodecGoldenTest.IR
  alias AshSurface.IRCodecGoldenTest.Codec

  # Frozen golden digests (64 lowercase hex chars), computed from real
  # `Codec.digest(Codec.to_map(ir))` execution over the two fixtures below.
  # Any drift in section shape, field serialization, canonicalization, or the
  # digest pipeline breaks these by design.
  @golden %{
    full: "9916f58e8cbd7fab8e731c5a046a5677001a914ddbc8f20d34e6881ef8780038",
    presentation_only: "eb83ace3025f20235104aecc8b13cb15058580ddcb2adc96115316666b742190"
  }

  # Frozen golden canonical JSON bytes (Jason over to_map/1). Pins the stable
  # canonical key order end-to-end: top-level in sorted order, nil sections as
  # JSON null, nil fields inside present sections as null.
  @golden_json %{
    full:
      ~s'{"ash":{"action":"read","action_type":"read","inputs":[{"name":"id","required":true,"type":"uuid"}],"outputs":{"fields":["id","body"]},"policies":[{"name":"can_read","type":"allow"}],"resource":"AshSurface.GoldenPost"},"capability":{"authority_required":false,"capability_id":"cap:post:read","consequence_class":"OBSERVE","receipt_required":true},"presentation":{"format":"compact","group":"content","label":"Posts","order":1,"widget":"table"},"schema":{"aria":{"label":"Posts","role":"table"},"input":{"properties":{"id":{"type":"string"}},"type":"object"},"output":{"properties":{"body":{"type":"string"}},"type":"object"},"zod":"z.object({ id: z.string().uuid() })"},"semantic":{"capability_iri":"https://ash.surface/c/post#read","ontology":"dfcm","predicates":{"describes":"post","grants":"observe"},"shape_id":"shape:post:read:v1","subject_iri":"https://ash.surface/i/user"},"version":"26.9.17"}',
    presentation_only:
      ~s'{"ash":null,"capability":null,"presentation":{"format":null,"group":null,"label":"Dumb screen","order":null,"widget":null},"schema":null,"semantic":null,"version":null}'
  }

  defp full_ir do
    ir = %IR{
      version: "26.9.17",
      ash: %IR.Ash{
        resource: "AshSurface.GoldenPost",
        action: "read",
        action_type: "read",
        inputs: [%{"name" => "id", "required" => true, "type" => "uuid"}],
        outputs: %{"fields" => ["id", "body"]},
        policies: [%{"name" => "can_read", "type" => "allow"}]
      },
      semantic: %IR.Semantic{
        subject_iri: "https://ash.surface/i/user",
        capability_iri: "https://ash.surface/c/post#read",
        predicates: %{"describes" => "post", "grants" => "observe"},
        shape_id: "shape:post:read:v1",
        ontology: "dfcm"
      },
      capability: %IR.Capability{
        capability_id: "cap:post:read",
        consequence_class: "OBSERVE",
        authority_required: false,
        receipt_required: true
      },
      presentation: %IR.Presentation{
        label: "Posts",
        group: "content",
        order: 1,
        widget: "table",
        format: "compact"
      },
      schema: %IR.Schema{
        input: %{"properties" => %{"id" => %{"type" => "string"}}, "type" => "object"},
        output: %{"properties" => %{"body" => %{"type" => "string"}}, "type" => "object"},
        zod: "z.object({ id: z.string().uuid() })",
        aria: %{"label" => "Posts", "role" => "table"}
      }
    }

    %{ir | digest: Codec.digest(Codec.to_map(ir))}
  end

  defp presentation_only_ir do
    ir = %IR{
      version: nil,
      ash: nil,
      semantic: nil,
      capability: nil,
      presentation: %IR.Presentation{label: "Dumb screen"},
      schema: nil
    }

    %{ir | digest: Codec.digest(Codec.to_map(ir))}
  end

  defp fixture(:full), do: full_ir()
  defp fixture(:presentation_only), do: presentation_only_ir()

  defp build(name), do: fixture(name)

  defp full_map, do: Codec.to_map(full_ir())

  # One-field mutation per section, plus version, plus the honesty flips:
  # nil section -> present-empty section, present section -> nil.
  defp sensitivity_cases do
    base = full_ir()
    minimal = presentation_only_ir()

    [
      {"ash: one field (action read -> destroy)", base,
       %{base | ash: %{base.ash | action: "destroy"}}},
      {"semantic: one field (shape_id bump)", base,
       %{base | semantic: %{base.semantic | shape_id: "shape:post:read:v2"}}},
      {"capability: one field (receipt_required true -> false)", base,
       %{base | capability: %{base.capability | receipt_required: false}}},
      {"presentation: one field (order 1 -> 2)", base,
       %{base | presentation: %{base.presentation | order: 2}}},
      {"schema: one field (zod string change)", base,
       %{base | schema: %{base.schema | zod: "z.object({ id: z.string() })"}}},
      {"version: 26.9.17 -> 27.0.0", base, %{base | version: "27.0.0"}},
      {"honesty: nil ash section -> present-but-all-nil-fields ash section", minimal,
       %{minimal | ash: %IR.Ash{}}},
      {"honesty: present presentation section -> nil section", minimal,
       %{minimal | presentation: nil}}
    ]
  end

  describe "IR canonical shape" do
    test "declares version, digest, and exactly the five sections" do
      assert IR.sections() == [:ash, :semantic, :capability, :presentation, :schema]

      assert IR.__struct__() |> Map.keys() |> List.delete(:__struct__) |> Enum.sort() ==
               Enum.sort(IR.sections() ++ [:version, :digest])
    end

    test "each section struct carries exactly its declared fields" do
      fields = fn module ->
        module.__struct__() |> Map.keys() |> List.delete(:__struct__) |> Enum.sort()
      end

      assert fields.(IR.Ash) == ~w(action action_type inputs outputs policies resource)a
      assert fields.(IR.Semantic) == ~w(capability_iri ontology predicates shape_id subject_iri)a

      assert fields.(IR.Capability) ==
               ~w(authority_required capability_id consequence_class receipt_required)a

      assert fields.(IR.Presentation) == ~w(format group label order widget)a
      assert fields.(IR.Schema) == ~w(aria input output zod)a
    end

    test "every section of the full fixture is populated; the minimal fixture is presentation-only" do
      full = build(:full)

      for section <- IR.sections(), do: assert(%{} = Map.get(full, section))

      minimal = build(:presentation_only)

      for section <- IR.sections() -- [:presentation], do: refute(Map.get(minimal, section))

      assert %IR.Presentation{label: "Dumb screen"} = minimal.presentation
    end
  end

  describe "to_map/1 — canonical map" do
    test "emits exactly version + the five section keys, in canonical sorted order" do
      assert Map.keys(Codec.to_map(build(:full))) ==
               ~w(ash capability presentation schema semantic version)

      assert Map.keys(Codec.to_map(build(:presentation_only))) ==
               ~w(ash capability presentation schema semantic version)
    end

    test "section content passes through unchanged (no silent transformation)" do
      m = Codec.to_map(build(:full))

      assert m["ash"] == %{
               "action" => "read",
               "action_type" => "read",
               "inputs" => [%{"name" => "id", "required" => true, "type" => "uuid"}],
               "outputs" => %{"fields" => ["id", "body"]},
               "policies" => [%{"name" => "can_read", "type" => "allow"}],
               "resource" => "AshSurface.GoldenPost"
             }

      assert m["capability"] == %{
               "authority_required" => false,
               "capability_id" => "cap:post:read",
               "consequence_class" => "OBSERVE",
               "receipt_required" => true
             }
    end

    test "the canonical map is the digest preimage: no digest key inside" do
      refute Map.has_key?(Codec.to_map(build(:full)), "digest")
      refute Map.has_key?(Codec.to_map(build(:presentation_only)), "digest")
    end
  end

  describe "nil-section honesty" do
    test "nil sections serialize as nil with keys present, never as fabricated empty maps" do
      m = Codec.to_map(build(:presentation_only))

      assert m["ash"] == nil and m["semantic"] == nil and m["capability"] == nil and
               m["schema"] == nil

      for key <- ~w(ash semantic capability schema), do: assert(Map.has_key?(m, key))
    end

    test "nil version serializes as nil (honest, key present)" do
      assert Codec.to_map(build(:presentation_only))["version"] == nil
      assert Codec.to_map(build(:full))["version"] == "26.9.17"
    end

    test "nil fields inside a present section serialize as null, never dropped" do
      m = Codec.to_map(build(:presentation_only))

      assert m["presentation"] == %{
               "format" => nil,
               "group" => nil,
               "label" => "Dumb screen",
               "order" => nil,
               "widget" => nil
             }
    end

    test "JSON null round-trips to nil sections and nil fields" do
      assert {:ok, ir} = Codec.from_map(Jason.decode!(@golden_json[:presentation_only]))

      assert ir.ash == nil and ir.semantic == nil and ir.capability == nil and ir.schema == nil
      assert ir.version == nil
      assert ir.presentation == %IR.Presentation{label: "Dumb screen"}
      assert ir.digest == @golden[:presentation_only]
    end

    test "null is not a present-but-empty section: digests differ" do
      nil_section = Codec.to_map(build(:presentation_only))
      empty_section = Map.put(nil_section, "ash", %{})

      refute Codec.digest(empty_section) == Codec.digest(nil_section)
    end
  end

  describe "golden JSON" do
    test "frozen canonical JSON bytes for the fully-populated five-section IR" do
      assert Jason.encode!(Codec.to_map(build(:full))) == @golden_json[:full]
    end

    test "frozen canonical JSON bytes for the minimal presentation-only IR" do
      assert Jason.encode!(Codec.to_map(build(:presentation_only))) ==
               @golden_json[:presentation_only]
    end

    test "golden JSON is byte-stable across decode/re-encode" do
      for {name, json} <- @golden_json do
        assert Jason.encode!(Jason.decode!(json)) == json
        assert Jason.encode!(Codec.to_map(build(name))) == json
      end
    end

    test "from_map over the golden JSON rebuilds the exact fixture (digest included)" do
      for {name, json} <- @golden_json do
        assert {:ok, ir} = Codec.from_map(Jason.decode!(json))
        assert ir == build(name)
      end
    end
  end

  describe "from_map/to_map round-trip" do
    test "from_map(to_map(ir)) == {:ok, ir} — digest field agreement included" do
      for name <- [:full, :presentation_only] do
        ir = build(name)
        assert {:ok, ^ir} = Codec.from_map(Codec.to_map(ir))
      end
    end

    test "digest(to_map(ir)) == ir.digest" do
      for name <- [:full, :presentation_only] do
        ir = build(name)
        assert Codec.digest(Codec.to_map(ir)) == ir.digest
      end
    end
  end

  describe "digest sensitivity table" do
    test "a one-field change in each section flips the digest" do
      for {label, base, mutated} <- sensitivity_cases() do
        base_digest = Codec.digest(Codec.to_map(base))
        mutated_digest = Codec.digest(Codec.to_map(mutated))

        refute base_digest == mutated_digest,
               "#{label}: expected the digest to flip, both were #{base_digest}"
      end
    end

    test "golden-frozen digests for both fixtures" do
      computed = %{
        full: build(:full).digest,
        presentation_only: build(:presentation_only).digest
      }

      assert computed == @golden
    end
  end

  describe "digest determinism and canon" do
    test "digest text form is 64 lowercase hex characters" do
      for name <- [:full, :presentation_only] do
        assert Codec.digest(Codec.to_map(build(name))) =~ ~r/^[0-9a-f]{64}$/
      end
    end

    test "deterministic: repeated calls yield one digest" do
      m = Codec.to_map(build(:full))
      assert [digest] = Enum.uniq(for(_ <- 1..7, do: Codec.digest(m)))
      assert digest == @golden[:full]
    end

    test "key-order independent: shuffled top-level and reversed >32-key section" do
      m = full_map()

      shuffled =
        m |> Map.to_list() |> Enum.reverse() |> Map.new()

      assert Codec.digest(shuffled) == Codec.digest(m)

      large =
        Map.new(1..40, fn i ->
          {"p" <> String.pad_leading(Integer.to_string(i), 2, "0"), i}
        end)

      assert map_size(large) > 32

      reversed =
        1..40
        |> Enum.reverse()
        |> Map.new(fn i -> {"p" <> String.pad_leading(Integer.to_string(i), 2, "0"), i} end)

      with_large = Map.put(m, "semantic", %{m["semantic"] | "predicates" => large})

      assert Codec.digest(Map.put(m, "semantic", %{m["semantic"] | "predicates" => reversed})) ==
               Codec.digest(with_large)
    end

    test "agrees with AshSurface.from_manifest/2 digests on real surfaces (reuse pin)" do
      ep = fn res, name, type ->
        %Entrypoint{resource: res, action: struct!(Action, name: name, type: type, custom: %{})}
      end

      plain = %Manifest{entrypoints: [ep.(AshSurface.GoldenIrPost, :read, :read)]}

      profiled = %Manifest{entrypoints: [ep.(AshSurface.GoldenIrLedger, :record, :create)]}

      assert {:ok, s1} = AshSurface.from_manifest(plain, profile: %{})
      assert Codec.digest(s1.contract) == s1.digest

      assert {:ok, s2} =
               AshSurface.from_manifest(profiled,
                 profile: %{audience: :internal, transports: [:http, :phoenix_channel]}
               )

      assert Codec.digest(s2.contract) == s2.digest
    end
  end

  describe "from_map forward-tolerance" do
    test "unknown extra top-level keys are ignored, including a carried digest" do
      {:ok, plain} = Codec.from_map(full_map())

      future =
        Map.merge(full_map(), %{
          "futureFacet" => %{"x" => 1},
          "v2_sections" => [],
          "digest" => String.duplicate("0", 64)
        })

      assert {:ok, ^plain} = Codec.from_map(future)
    end

    test "unknown fields inside a section are ignored" do
      {:ok, plain} = Codec.from_map(full_map())

      extended =
        Map.put(full_map(), "ash", Map.put(full_map()["ash"], "futureField", 42))

      assert {:ok, ^plain} = Codec.from_map(extended)
    end

    test "absent version key is tolerated as nil (older writers)" do
      {:ok, plain} = Codec.from_map(full_map())

      assert {:ok, ir} = Codec.from_map(Map.delete(full_map(), "version"))
      assert ir.version == nil
      assert ir.digest != plain.digest
    end

    test "nil leaf means the declared default (null == absent at leaf level)" do
      with_nil_leaf =
        Map.put(full_map(), "capability", %{
          full_map()["capability"]
          | "authority_required" => nil
        })

      without_leaf = Map.delete(full_map()["capability"], "authority_required")

      assert Codec.from_map(with_nil_leaf) ==
               Codec.from_map(Map.put(full_map(), "capability", without_leaf))
    end
  end

  describe "from_map typed rejections" do
    test "non-map subjects" do
      for bad <- [:nope, "nope", 42, nil, [ash: nil]] do
        assert {:error, {:ir_map_required, ^bad}} = Codec.from_map(bad)
      end
    end

    test "structs are not IR maps" do
      ir = build(:presentation_only)
      assert {:error, {:ir_map_required, ^ir}} = Codec.from_map(ir)
    end

    test "missing section keys are named" do
      dropped = Map.drop(full_map(), ["presentation", "semantic"])

      assert {:error, {:missing_ir_sections, ["presentation", "semantic"]}} =
               Codec.from_map(dropped)
    end

    test "sections that are neither maps nor nil are typed-rejected" do
      for {key, bad_value} <- [
            {"ash", []},
            {"presentation", "pretty"},
            {"schema", 7}
          ] do
        assert {:error, {:section_must_be_map_or_nil, ^key, ^bad_value}} =
                 Codec.from_map(Map.put(full_map(), key, bad_value))
      end
    end

    test "wrong-typed version is typed-rejected" do
      assert {:error, {:version_must_be_string_or_nil, 26.9}} =
               Codec.from_map(Map.put(full_map(), "version", 26.9))
    end

    test "non-JSON-isomorphic section content is typed-rejected" do
      for {label, value} <- [
            {"tuple leaf", %{"t" => {:error, :tuple}}},
            {"atom nested key", %{atom_key: 1}},
            {"tuple leaf inside a list", %{"l" => ["a", {:inner, 1}]}},
            {"atom value inside a list", %{"l" => [:http]}},
            {"non-UTF-8 binary", %{"b" => <<0xFF, 0xFE>>}}
          ] do
        assert {:error, {:not_json_isomorphic, "semantic", _}} =
                 Codec.from_map(Map.put(full_map(), "semantic", value)),
               label
      end
    end
  end
end
