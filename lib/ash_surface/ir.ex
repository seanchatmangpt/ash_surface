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

  Reading a fact here is not evidence that the fact was verified in this
  session, and no field of this struct authorizes a DO. Consumers must
  re-derive standing from the sources; the IR only transports what those
  sources admitted.
  """

  @enforce_keys []
  defstruct [:version, :digest, :ash, :semantic, :capability, :presentation, :schema]

  @type section_name :: :ash | :semantic | :capability | :presentation | :schema

  @type t :: %__MODULE__{
          version: String.t() | nil,
          digest: String.t() | nil,
          ash: Ash.t() | nil,
          semantic: Semantic.t() | nil,
          capability: Capability.t() | nil,
          presentation: Presentation.t() | nil,
          schema: Schema.t() | nil
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
          Ash.t() | Semantic.t() | Capability.t() | Presentation.t() | Schema.t() | nil
  def section(%__MODULE__{} = ir, name) when is_map_key(@section_modules, name) do
    Map.get(ir, name)
  end

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

  defmodule Capability do
    @moduledoc """
    Facts admitted from capability law. `authority_required` and
    `receipt_required` are recorded requirements, not grants: the IR confers
    no DO-authority.
    """

    defstruct [
      :capability_id,
      :consequence_class,
      authority_required: false,
      receipt_required: false
    ]

    @type t :: %__MODULE__{
            capability_id: String.t() | nil,
            consequence_class: String.t() | atom() | nil,
            authority_required: boolean(),
            receipt_required: boolean()
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

    defstruct [:input, :output, :zod, :aria]

    @type t :: %__MODULE__{
            input: map() | nil,
            output: map() | nil,
            zod: String.t() | nil,
            aria: map() | nil
          }
  end
end
