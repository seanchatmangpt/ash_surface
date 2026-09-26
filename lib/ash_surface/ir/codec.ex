defmodule AshSurface.IR.Codec do
  @moduledoc """
  Serialization and content addressing for `AshSurface.IR` — the ONE admitted
  five-section canon (`lib/ash_surface/ir.ex`: `ash | semantic | capability |
  presentation | schema`).

  [Reconciliation, chicago-codec-canon-034: this file previously carried a
  parallel five-section staging canon of its own — the `AshSurface.IR.Surface`
  struct (`actions | identity | profile | resources | transports`) left behind
  by the transition note of the wave that first owned the file. That parallel
  canon is retired. There is one IR canon, `AshSurface.IR`, and this codec is
  its single serialization and content-addressing owner. The former
  surface-contract staging shape was always the wrapper contract's own form
  (`AshSurface.Surface.contract`, produced by `AshSurface.from_manifest/2`),
  never a second IR.]

  Laws implemented here:

    * `to_map/1` — the canonical staging map of an admitted IR: exactly the
      string keys `"version"` plus the five section keys, each section a map
      of *all* its declared fields (string keys, sorted) or `nil` when the
      section is honestly absent. Nil-honesty holds at both levels: a nil
      section is `nil` (JSON `null`), never a fabricated empty map, and a nil
      *field* inside a present section is `null`, never dropped. Values are
      staged to their JSON-isomorphic form: embedded structs (the declared
      sub-shapes `%AshSurface.IR.Input{}`, `%AshSurface.IR.Output{}`,
      `%AshSurface.IR.Policy{}`, and any other struct fact) project to
      string-keyed field maps, atoms (never booleans or `nil`) render as their
      source-alias strings, and map keys stringify recursively; terms that
      already have a JSON-isomorphic form pass through unchanged. Terms with no
      JSON-isomorphic form (tuples, references, ...) pass through untouched
      so `from_map/1` can refuse them honestly — staging never fabricates a
      value. `digest` never enters the canonical map; the map is the digest
      preimage.
    * `from_map/1` — forward-tolerant inverse: the five section keys must be
      present (missing keys are typed-rejected), but *unknown extra keys are
      ignored* — a future IR version's new sections/fields cannot break this
      reader, and a carried `"digest"` is ignored in favor of the recomputed
      one. Section values must be `nil` or JSON-isomorphic maps (binary keys;
      UTF-8 string/number/boolean/nil leaves; lists; maps) — anything else is
      typed-rejected. The returned struct's `digest` is always recomputed from
      the admitted content.
    * `digest/1` — the existing `AshSurface` digest canon: SHA-256 over
      `:erlang.term_to_binary/1` of the canonical term (map keys stringified
      and sorted recursively; list order preserved and semantic), hex-encoded
      lowercase. The canon is private upstream (`AshSurface.digest/2` in
      lib/ash_surface.ex); exactly as `AshSurface.Health` does, this module
      runs the same pipeline and agreement is pinned by tests against freshly
      built real `AshSurface.from_manifest/2` surfaces, so any upstream drift
      breaks the suite.

  Key-order honesty: every canonical map is built with keys inserted in
  sorted order, and small maps iterate key-sorted (Erlang flatmaps), so Jason
  emits byte-stable canonical JSON. The *contractual* order-independence of
  the identity lives in `digest/1`, whose canon sorts keys before hashing.
  """

  alias AshSurface.IR

  @ash_fields ~w(action action_type inputs outputs policies resource)
  @capability_fields ~w(authority_required capability_id consequence_class receipt_required)
  @presentation_fields ~w(format group label order widget)
  @schema_fields ~w(aria input output zod)
  @semantic_fields ~w(capability_iri ontology predicates shape_id subject_iri)

  @section_keys ~w(ash capability presentation schema semantic)

  @doc """
  Projects an admitted IR into its canonical staging map: `version` plus the
  five section keys, each section nil-honestly serialized (nil section ->
  nil; present section -> all declared fields, nil fields as nil, values
  staged to their JSON-isomorphic form).
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

  # The exact AshSurface canon (lib/ash_surface.ex): map keys are stringified
  # and sorted recursively; list order is preserved and is semantic content;
  # every other term passes through unchanged. Mirrored only because the
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
    Map.new(fields, fn field ->
      {field, staged(Map.get(section, String.to_existing_atom(field)))}
    end)
  end

  # Stages a section field value into its JSON-isomorphic form: embedded
  # structs (the declared sub-shapes, or any other struct fact) project to
  # string-keyed field maps; atoms render as their source-alias strings (the
  # "Elixir." alias prefix is stripped, so modules render exactly as inspect/1
  # does); map keys stringify recursively; lists preserve order (list order is
  # semantic content); already-JSON-isomorphic terms pass through unchanged.
  defp staged(value) when is_struct(value), do: value |> Map.from_struct() |> staged()

  defp staged(value) when is_map(value) do
    Map.new(value, fn {key, inner} -> {staged_key(key), staged(inner)} end)
  end

  defp staged(value) when is_atom(value) and not is_boolean(value) and not is_nil(value) do
    value |> Atom.to_string() |> String.replace_prefix("Elixir.", "")
  end

  defp staged(value) when is_list(value), do: Enum.map(value, &staged/1)
  defp staged(value), do: value

  defp staged_key(key) when is_atom(key), do: Atom.to_string(key)
  defp staged_key(key) when is_binary(key), do: key
  defp staged_key(key), do: to_string(key)

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
