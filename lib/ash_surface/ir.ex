defmodule AshSurface.IR do
  @moduledoc """
  The canonical normalized SurfaceIR: the single intersection every wave of the
  surface projects from.

  The IR is a dumb carrier. Invariant, wave-wide law:

  > IR determines NOTHING about existence, meaning, or DO-authority — it
  > carries admitted facts from its five sources.

  The five sources, in section order:

  1. `Ash` — the normalized Ash manifest (resource/action identity, inputs,
     outputs, policies). Ash remains authoritative; the IR re-states, never
     re-decides.
  2. `Semantic` — the semantic layer (subject/capability IRIs, predicates,
     shape, ontology).
  3. `Capability` — capability law (consequence class, authority and receipt
     requirements as admitted facts, never as grants).
  4. `Presentation` — presentation descriptors (label, group, order, widget,
     format).
  5. `Schema` — boundary schemas (input, output, the Zod projection, aria).

  Serialization and content addressing of this IR — the JSON-isomorphic
  staging map and the content digest — is owned by `AshSurface.IR.Codec`
  (`lib/ash_surface/ir/codec.ex`). There is one IR canon (this struct) and one
  codec for it; no parallel staging shape is admitted
  (chicago-codec-canon-034).

  Reading a fact here is not evidence that the fact was verified in this
  session, and no field of this struct authorizes a DO. Consumers must
  re-derive standing from the sources; the IR only transports what those
  sources admitted.

  ## Delegated facts (v26.9.16 slimming, v10)

  `semanticId`, `authorityBoundary`, `doAuthority`, and `receiptRequired`
  are delegated facts, never local derivations: each is read from the
  manifest's `custom.ash_surface` profile metadata when a delegating
  authority stored it there, and is `nil` otherwise. See `delegated/2`.
  """

  @enforce_keys []
  defstruct [:version, :digest, :ash, :semantic, :capability, :presentation, :schema]

  @type section_name :: :ash | :semantic | :capability | :presentation | :schema

  @type t :: %__MODULE__{
          version: String.t() | nil,
          digest: String.t() | nil,
          ash: __MODULE__.Ash.t() | nil,
          semantic: __MODULE__.Semantic.t() | nil,
          capability: __MODULE__.Capability.t() | nil,
          presentation: __MODULE__.Presentation.t() | nil,
          schema: __MODULE__.Schema.t() | nil
        }

  @section_modules %{
    ash: __MODULE__.Ash,
    semantic: __MODULE__.Semantic,
    capability: __MODULE__.Capability,
    presentation: __MODULE__.Presentation,
    schema: __MODULE__.Schema
  }

  @doc """
  Constructs an empty IR (all sections nil), or one from the admitted
  top-level fields. Unknown fields raise — the shape is law, not a suggestion.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    struct!(__MODULE__, opts)
  end

  @doc """
  Returns the five section names, in source order.
  """
  @spec sections() :: [section_name()]
  def sections do
    [:ash, :semantic, :capability, :presentation, :schema]
  end

  @doc """
  Typed accessor for a section's struct type: `section(:ash)` is the module
  `AshSurface.IR.Ash`, so `%{IR.section(:ash)}{}` constructs it.
  """
  @spec section(section_name()) :: module()
  def section(name) when is_map_key(@section_modules, name) do
    @section_modules[name]
  end

  @doc """
  Reads one of the five embedded structs out of an IR.
  """
  @spec section(t(), section_name()) ::
          __MODULE__.Ash.t()
          | __MODULE__.Semantic.t()
          | __MODULE__.Capability.t()
          | __MODULE__.Presentation.t()
          | __MODULE__.Schema.t()
          | nil
  def section(%__MODULE__{} = ir, name) when is_map_key(@section_modules, name) do
    Map.get(ir, name)
  end

  # -- Delegated facts (v10 slimming, merged after sections per wave order) --

  @delegated_facts ~w(semanticId authorityBoundary doAuthority receiptRequired)

  @doc "The canonical delegated-fact section keys."
  @spec delegated_facts() :: [String.t(), ...]
  def delegated_facts, do: @delegated_facts

  @doc """
  Reads a delegated fact for a manifest entrypoint from its `custom.ash_surface`
  IR section.

  Returns the delegated value when the manifest metadata carries it, `nil`
  otherwise. No default is inferred and no value is re-derived.
  """
  @spec delegated(Ash.Info.Manifest.Entrypoint.t(), String.t()) :: term() | nil
  def delegated(%Ash.Info.Manifest.Entrypoint{action: action}, fact)
      when fact in @delegated_facts do
    action
    |> surface_section()
    |> profile_section()
    |> Kernel.||(%{})
    |> Map.get(fact)
  end

  defp surface_section(%{custom: custom}) do
    case custom do
      %{ash_surface: section} -> section
      %{"ash_surface" => section} -> section
      _ -> %{}
    end
  end

  defp profile_section(%{profile: profile}) when is_map(profile), do: profile
  defp profile_section(%{"profile" => profile}) when is_map(profile), do: profile
  defp profile_section(_), do: nil

  defmodule Ash do
    @moduledoc """
    Facts admitted from the normalized Ash manifest. Ash stays authoritative;
    this section carries identity and shape, never decisions.
    """

    defstruct [:resource, :action, :action_type, :inputs, :outputs, :policies]

    @type t :: %__MODULE__{
            resource: module() | String.t() | nil,
            action: String.t() | atom() | nil,
            action_type: String.t() | atom() | nil,
            inputs: [map()] | map() | nil,
            outputs: [map()] | map() | nil,
            policies: [map()] | nil
          }
  end

  defmodule Semantic do
    @moduledoc """
    Facts admitted from the semantic layer: IRIs, predicates, shape, ontology.
    Carrying a `capability_iri` here does not make the capability mean, exist,
    or authorize anything.

    Two carried shapes are admitted, and the type states both truthfully:

      * **Compiled** (`AshSurface.Compiler.Section.Semantic`, the R2RML
        delegation) carries `AshSurface.Compiler.IR.Semantic` verbatim:
        `predicates` is a LIST of predicate IRIs in mapping order and
        `ontology` a LIST of named-graph IRIs (both possibly empty).
      * **Authored** (hand-built or decoded IR) may carry `predicates` as a
        map of named predicate facts (e.g. `%{"relationships" => [...]}`,
        the shape `AshSurface.Projectors.LiveView` reads relationships from)
        and `ontology` as a single provenance string.

    Consumers must accept either (or `nil`); a list of IRIs carries no
    relationship structure.
    """

    defstruct [:subject_iri, :capability_iri, :predicates, :shape_id, :ontology]

    @type t :: %__MODULE__{
            subject_iri: String.t() | nil,
            capability_iri: String.t() | nil,
            predicates: [String.t()] | %{optional(String.t() | atom()) => term()} | nil,
            shape_id: String.t() | nil,
            ontology: [String.t()] | String.t() | nil
          }
  end

  # -- Ash-facet sub-shapes (v29, verbatim; carried inside IR.Ash inputs/outputs/policies) --

  defmodule Input do
    @moduledoc """
    One declared action argument.

    `type` is the witnessed Ash type name (Ash's own short-name registry,
    inverted; module name for types outside it). `required` is the mechanical
    negation of the argument's `allow_nil?`. `default` is the declared default,
    surfaced verbatim (`nil` when none was declared).

    `constraints` is the argument's declared type constraint set (keyword or
    map in the source; carried as a map, `%{}` when none was declared).
    `subtype_of` is the declared subtype parent type name (`nil` when the
    argument declares none) and `subtype_constraints` its constraint set
    (`%{}` when none). All three are passed through verbatim from the
    discovery entry — never re-derived.
    """

    @enforce_keys [:name, :type, :required, :default]
    defstruct [
      :name,
      :type,
      :required,
      :default,
      :subtype_of,
      constraints: %{},
      subtype_constraints: %{}
    ]

    @type t :: %__MODULE__{
            name: atom(),
            type: String.t(),
            required: boolean(),
            default: term(),
            constraints: map(),
            subtype_of: String.t() | nil,
            subtype_constraints: map()
          }
  end

  defmodule Output do
    @moduledoc """
    The action's declared output.

    Only generic `:action` actions declare `returns` in the Ash DSL, so reads,
    creates, updates, and destroys carry `nil` unless their action type actually
    declares a return type. No record-shape or pagination story is invented here.
    """

    @enforce_keys [:returns]
    defstruct [:returns]

    @type t :: %__MODULE__{returns: String.t() | nil}
  end

  defmodule Policy do
    @moduledoc """
    One declared resource policy, read-only.

    `conditions` and `checks` are the authored policy scope and check set
    (module name plus authored opts; the authorizer compiler's injected
    `:access_type` execution hint is not an authored fact and is dropped).
    Policies are never evaluated, filtered, or interpreted here.
    """

    @enforce_keys [:bypass, :conditions, :checks]
    defstruct [:bypass, :conditions, :checks]

    @type check :: %{check: String.t(), kind: atom()}
    @type condition :: %{check: String.t(), opts: map()}
    @type t :: %__MODULE__{
            bypass: boolean(),
            conditions: [condition()],
            checks: [check()]
          }
  end

  defmodule Presentation do
    @moduledoc """
    Facts admitted from presentation descriptors: how a surface element is
    labeled, grouped, ordered, and rendered.
    """

    defstruct [:label, :group, :order, :widget, :format]

    @type t :: %__MODULE__{
            label: String.t() | nil,
            group: String.t() | nil,
            order: non_neg_integer() | nil,
            widget: String.t() | atom() | nil,
            format: String.t() | nil
          }
  end

  defmodule Schema do
    @moduledoc """
    Facts admitted from the boundary schemas: input/output shapes, the Zod
    projection of the boundary, and aria semantics.
    """

    # Per-action Zod fragments (nil when the action does not admit them):
    # filter (typed filter union), sort (sort-string envelope), page
    # (pagination envelope), capability_flags (string-keyed booleans: get,
    # offset, keyset, required, countable), response_zod (nil until a record
    # schema is carried) and error
    # (reference to the closed `AshSurface.IR.ErrorShape` vocabulary; carries
    # the per-action `carry` / `field_errors` expressions).
    #
    # Wave 3 carry-through (all nil when the action does not admit them):
    # get (`%{"input" => get_by zod, "identities" => %{name => zod}}`),
    # tenant (tenant parameter zod), load (relationship load envelope),
    # selection (field-selection admission), calculations
    # (`%{"load" => zod, "results" => %{name => zod}}`), aggregates
    # (`%{name => result zod}`), validation_error (per-input validation-error
    # shape), facts (the non-zod facts those were rendered from: pagination
    # incl. default_limit/max_page_size, get_by, not_found_error?,
    # identities, multitenancy, loads, sortable_fields, relationships,
    # calculations, aggregates) and nil_reasons (typed reason for every
    # honest-nil fragment: field name -> reason string or
    # `%{"reason" => tag, "detail" => text}`).

    defstruct [
      :input,
      :output,
      :zod,
      :aria,
      :filter,
      :sort,
      :page,
      :capability_flags,
      :response_zod,
      :error,
      :get,
      :tenant,
      :load,
      :selection,
      :calculations,
      :aggregates,
      :validation_error,
      :facts,
      :nil_reasons
    ]

    @type t :: %__MODULE__{
            input: map() | nil,
            output: map() | nil,
            zod: String.t() | nil,
            aria: map() | nil,
            filter: String.t() | nil,
            sort: String.t() | nil,
            page: String.t() | nil,
            capability_flags: %{optional(String.t()) => boolean()} | nil,
            response_zod: String.t() | nil,
            error: map() | nil,
            get: map() | nil,
            tenant: String.t() | nil,
            load: String.t() | nil,
            selection: String.t() | nil,
            calculations: map() | nil,
            aggregates: map() | nil,
            validation_error: String.t() | nil,
            facts: map() | nil,
            nil_reasons: %{optional(String.t()) => String.t() | map()} | nil
          }
  end
end
