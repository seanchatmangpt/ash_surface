# Canonical compiler IR slices — ONE owner (v50 integration reconciliation).
#
# Branch-local copies of `AshSurface.Compiler.IR` (semantic.ex, schema.ex,
# aria.ex) are superseded by this file per the wave doctrine: the local
# Section-behaviour and IR duplicates in section modules yield to the single
# canonical declaration. Slice shapes are carried verbatim from their landing
# branches:
#
#   * `Input` + `Schema` — the per-action carrier (v08's surviving shape; its
#     tests pin `%IR.Schema{}` with `action_id`/`inputs`/`presentation`/`aria`).
#   * `Semantic` — the R2RML-delegated semantic slice (v04, verbatim).
#   * `Boundary` — the schema-section slice (v07, verbatim; renamed from its
#     branch-local `Schema` name to resolve the collision with the carrier —
#     its own moduledoc calls these "boundary schemas").
#
# `AshSurface.Compiler.IR.Capability` / `.Presentation` remain declared inside
# their owning section files (capability.ex, presentation.ex); nested-named
# module declarations compose with this parent without conflict.

defmodule AshSurface.Compiler.IR do
  @moduledoc """
  Canonical compiler IR slices, one declaration site.

  Every field is a delegated fact carried verbatim from the owning upstream
  surface; a `nil` field is an honest UNKNOWN, never a fabricated default.
  """

  defmodule Input do
    @enforce_keys [:name, :type, :allow_nil?]
    defstruct [:name, :type, :allow_nil?, :description]

    @type t :: %__MODULE__{
            name: atom() | String.t(),
            type: Ash.Info.Manifest.Type.t() | atom() | nil,
            allow_nil?: boolean(),
            description: String.t() | nil
          }
  end

  defmodule Schema do
    @moduledoc """
    Per-action carrier: the action's stable identity, normalized inputs, and
    the mounted output of each compiler section under that section's name.
    """
    @enforce_keys [:action_id, :inputs]
    defstruct [:action_id, :inputs, :presentation, :aria]

    @type t :: %__MODULE__{
            action_id: String.t(),
            inputs: [Input.t()],
            presentation: map() | nil,
            aria: map() | nil
          }
  end

  defmodule Semantic do
    @moduledoc """
    Semantic identity of one `{resource, action}` pair (R2RML delegation).

      * `subject_iri` — the R2RML subject IRI contract (template or constant)
        exactly as mapped. `nil` when the subject maps to a blank node.
      * `capability_iri` — the mapped RDF class IRI the action operates on.
      * `predicates` — the mapped predicate IRIs, verbatim and in mapping
        order. Empty when the mapping admits no property mappings.
      * `shape_id` — the SHACL `sh:NodeShape` identity exactly as emitted by
        AshR2RML's SHACL renderer for this mapping.
      * `ontology` — ontology provenance: the named-graph IRIs the mapping
        admits. Empty when the mapping admits no graph.
    """

    @enforce_keys [:subject_iri, :capability_iri, :predicates, :shape_id, :ontology]
    defstruct [:subject_iri, :capability_iri, :predicates, :shape_id, :ontology]

    @type t :: %__MODULE__{
            subject_iri: String.t() | nil,
            capability_iri: String.t() | nil,
            predicates: [String.t()],
            shape_id: String.t() | nil,
            ontology: [String.t()]
          }
  end

  defmodule Boundary do
    @moduledoc """
    Per-action boundary-schema slice (the schema section's output).

    * `input` — the input description: argument name -> type description map
    * `output` — the output description: the return type description, or
      `nil` when the action returns nothing declared
    * `zod` — the zod projection as source text (paired input/output schemas
      mirroring `AshSurface.Projector.Expo`'s emission idioms)
    * `aria` — derived accessibility metadata (zero-config, from names only)
    """

    @enforce_keys [:input, :output, :zod, :aria]
    defstruct [:input, :output, :zod, :aria]

    @type t :: %__MODULE__{
            input: %{optional(String.t()) => map()},
            output: map() | nil,
            zod: String.t(),
            aria: map()
          }
  end
end
