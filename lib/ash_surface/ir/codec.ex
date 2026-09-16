defmodule AshSurface.IR.Surface do
  @moduledoc """
  Canonical shape of the ash_surface intermediate representation (IR): the
  JSON-isomorphic staging form between a verified `AshSurface.Surface`
  contract and target projectors.

  This module declares the IR's canonical shape *locally*, inside the codec's
  own file, because this change owns only `lib/ash_surface/ir/codec.ex`. When
  `lib/ash_surface/ir.ex` is admitted it must carry exactly this shape: the
  same five sections, the same enforce order, `digest/0` last.

  ## The five sections

  The IR is exactly five section maps plus one content-addressed digest:

    * `:identity` — schema/generator identity facts (surface schema version,
      generator identity, upstream manifest digest references).
    * `:resources` — resource semantics projected from the Ash manifest
      (Ash remains authoritative; the IR never duplicates resource law).
    * `:actions` — action entries with authority-boundary metadata
      (`id`, `authorityBoundary`, `doAuthority`, `possibleRefusals`, ...).
    * `:profile` — consumer projection metadata (audience, flags, ...).
    * `:transports` — declared transports and selection facets (a projection
      facet, never action identity).

  Section values are JSON-isomorphic maps or `nil`. An absent section is
  `nil` — never a fabricated empty map. `digest` is not part of the canonical
  map: it content-addresses it (`AshSurface.IR.Codec.digest/1`), so a struct
  may circulate digest-free until it crosses `from_map/1`.
  """

  @sections [:actions, :identity, :profile, :resources, :transports]

  @enforce_keys @sections
  defstruct @sections ++ [:digest]

  @typedoc "A section is a JSON-isomorphic map, or nil when honestly absent."
  @type section :: map() | nil

  @type t :: %__MODULE__{
          actions: section(),
          identity: section(),
          profile: section(),
          resources: section(),
          transports: section(),
          digest: String.t() | nil
        }

  @doc "The canonical section names in canonical (sorted) order."
  @spec sections() :: [atom()]
  def sections, do: @sections
end

defmodule AshSurface.IR.Codec do
  @moduledoc """
  Serialization and content addressing for `AshSurface.IR.Surface`.

  Laws implemented here:

    * `to_map/1` — projects an IR into its canonical map: exactly the five
      string section keys, inserted in canonical sorted order
      (`actions, identity, profile, resources, transports`), each section
      passed through unchanged (`nil` stays `nil`). The digest never enters
      the canonical map; the map is the digest preimage.
    * `from_map/1` — the fail-closed inverse: requires *exactly* the five
      section keys (missing and unknown keys are refused, `"digest"`
      included), each `nil` or a JSON-isomorphic map (binary keys, UTF-8
      string/number/boolean/nil leaves), and recomputes the digest from the
      sections so the returned struct's `digest` always agrees with its
      content.
    * `digest/1` — the existing `AshSurface` digest canon: SHA-256 over
      `:erlang.term_to_binary/1` of the canonical term (map keys stringified
      and sorted recursively; list order preserved and semantic), hex-encoded
      lowercase. The canon is private upstream; exactly as
      `AshSurface.Health` does, this module runs the same pipeline and test
      agreement is pinned against freshly built real `AshSurface.from_manifest/2`
      surfaces, so any upstream drift breaks this suite.

  Key-order honesty: JSON maps have no contractual iteration order (Jason's
  default encoder emits raw `Map.to_list/1` order, which for flatmaps is
  insertion order — the same de facto law this codec's canonical insertion
  order relies on). The *contractual* order-independence of the identity
  lives in `digest/1`, whose canon sorts keys before hashing.
  """

  alias AshSurface.IR.Surface

  @section_keys ~w(actions identity profile resources transports)

  @doc """
  Projects an IR into its canonical five-section map.

  The map is built by inserting the section keys in canonical sorted order
  and passes section values through unchanged — `nil` sections serialize as
  `nil` (JSON `null`), never as fabricated empty maps.
  """
  @spec to_map(Surface.t()) :: map()
  def to_map(%Surface{} = ir) do
    %{
      "actions" => ir.actions,
      "identity" => ir.identity,
      "profile" => ir.profile,
      "resources" => ir.resources,
      "transports" => ir.transports
    }
  end

  @doc """
  Fail-closed inverse of `to_map/1`.

  Requires exactly the five section keys, each `nil` or a JSON-isomorphic
  map, and returns `{:ok, ir}` with `digest/1` computed over the canonical
  map — so `from_map(to_map(ir))` is `{:ok, ir}` exactly when the struct's
  stored digest still content-addresses its sections.
  """
  @spec from_map(term()) :: {:ok, Surface.t()} | {:error, term()}
  def from_map(map) when is_map(map) and not is_struct(map) do
    with :ok <- require_exact_sections(map),
         :ok <- require_section_shapes(map) do
      ir = %Surface{
        actions: Map.fetch!(map, "actions"),
        identity: Map.fetch!(map, "identity"),
        profile: Map.fetch!(map, "profile"),
        resources: Map.fetch!(map, "resources"),
        transports: Map.fetch!(map, "transports")
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
  # upstream function is private; agreement is pinned by tests against real
  # from_manifest/2 surfaces (same standing as AshSurface.Health).
  defp canonical_term(term) when is_map(term) do
    term
    |> Enum.map(fn {key, value} -> {to_string(key), canonical_term(value)} end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  defp canonical_term(term) when is_list(term), do: Enum.map(term, &canonical_term/1)
  defp canonical_term(term), do: term

  defp require_exact_sections(map) do
    keys = Map.keys(map)
    missing = @section_keys -- keys
    unknown = keys -- @section_keys

    cond do
      missing != [] -> {:error, {:missing_ir_sections, Enum.sort(missing)}}
      unknown != [] -> {:error, {:unknown_ir_sections, Enum.sort(unknown)}}
      true -> :ok
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

  # Deep JSON-isomorphism admission: what Jason.encode!/1 can encode and
  # Jason.decode!/1 brings back structurally identical — binary keys only,
  # UTF-8 binaries / numbers / booleans / nil leaves, lists, and maps.
  # Anything else is refused instead of silently mutating on round-trip.
  defp json_isomorphic(section, value) do
    cond do
      is_binary(value) ->
        if String.valid?(value),
          do: nil,
          else: {:error, {:not_json_isomorphic, section, value}}

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
