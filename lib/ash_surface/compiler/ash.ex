# The ash section of the AshSurface compiler.
#
# Local declarations (per compiler-section file discipline) until the shared
# `lib/ash_surface/ir.ex` and `lib/ash_surface/compiler.ex` land: the IR is
# declared here with its CANONICAL SHAPE, verbatim, so integration extracts
# rather than rewrites. Sibling sections (semantics, capability, presentation)
# own the other facets; this section populates `IR.Ash` only.
defmodule AshSurface.IR do
  @moduledoc false

  defmodule Ash do
    @moduledoc false

    @enforce_keys [:resource, :action, :action_type, :inputs, :outputs, :policies]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            resource: module(),
            action: atom(),
            action_type: atom(),
            inputs: [atom()],
            outputs: term(),
            policies: [struct()]
          }
  end

  defmodule Semantic do
    @moduledoc false

    @enforce_keys [:subject_iri, :capability_iri, :predicates, :shape_id, :ontology]
    defstruct @enforce_keys

    # Types stay permissive until the semantics section owns them.
    @type t :: %__MODULE__{
            subject_iri: term(),
            capability_iri: term(),
            predicates: term(),
            shape_id: term(),
            ontology: term()
          }
  end

  defmodule Capability do
    @moduledoc false

    @enforce_keys [:capability_id, :consequence_class, :authority_required, :receipt_required]
    defstruct @enforce_keys

    # Types stay permissive until the capability section owns them.
    @type t :: %__MODULE__{
            capability_id: term(),
            consequence_class: term(),
            authority_required: term(),
            receipt_required: term()
          }
  end

  defmodule Presentation do
    @moduledoc false

    @enforce_keys [:label, :group, :order, :widget, :format]
    defstruct @enforce_keys

    # Types stay permissive until the presentation section owns them.
    @type t :: %__MODULE__{
            label: term(),
            group: term(),
            order: term(),
            widget: term(),
            format: term()
          }
  end

  defmodule Schema do
    @moduledoc false

    @enforce_keys [:input, :output, :zod, :aria]
    defstruct @enforce_keys

    # Types stay permissive until the schema section owns them.
    @type t :: %__MODULE__{
            input: term(),
            output: term(),
            zod: term(),
            aria: term()
          }
  end

  # The ash facet is the root: no IR exists without one (Ash is authoritative;
  # every other facet is a projection OF the ash facet, filled by its own
  # section). `digest` is computed by whatever assembles the whole IR, not by
  # any single section.
  @enforce_keys [:ash]
  defstruct version: 1,
            digest: nil,
            ash: nil,
            semantic: nil,
            capability: nil,
            presentation: nil,
            schema: nil

  @type t :: %__MODULE__{
          version: non_neg_integer(),
          digest: term(),
          ash: Ash.t(),
          semantic: Semantic.t() | nil,
          capability: Capability.t() | nil,
          presentation: Presentation.t() | nil,
          schema: Schema.t() | nil
        }
end

defmodule AshSurface.Compiler.Section do
  @moduledoc false

  # Declared locally (per compiler-section file discipline) until the shared
  # `lib/ash_surface/compiler.ex` lands. One section = one projection facet of
  # one source; sections never borrow each other's facets.
  @callback build(source :: module(), opts :: keyword()) ::
              {:ok, [struct()]} | {:error, [map()]}
end

defmodule AshSurface.Compiler.Ash do
  @moduledoc false

  # The ash section: populates IR.Ash from REAL Ash metadata only —
  # Ash.Resource.Info public_actions, action_inputs, action returns, and
  # resource policies. No semantics, no capability, no presentation; those are
  # sibling sections. Policies are carried read-only (the authorizer's own
  # structs, never reinterpreted or evaluated here).
  @behaviour AshSurface.Compiler.Section

  alias AshSurface.IR

  @impl AshSurface.Compiler.Section
  def build(source, _opts \\ []) do
    if ash_resource?(source) do
      {:ok, Enum.map(Ash.Resource.Info.public_actions(source), &section(source, &1))}
    else
      {:error,
       [
         %{
           code: "not_an_ash_resource",
           detail: "ash section builds only from a compiled Ash resource, got #{inspect(source)}"
         }
       ]}
    end
  end

  defp ash_resource?(source), do: is_atom(source) and Ash.Resource.Info.resource?(source)

  defp section(resource, action) do
    %IR.Ash{
      resource: resource,
      action: action.name,
      action_type: action.type,
      inputs: inputs(resource, action),
      outputs: Map.get(action, :returns),
      policies: policies(resource)
    }
  end

  # `action_inputs/2` is the exact accepted-key set Ash persists per action
  # (arguments plus accepted attributes), keyed by BOTH atom and string forms;
  # DSL-declared keys are always atoms, so the atom entries are the exact set.
  defp inputs(resource, action) do
    resource
    |> Ash.Resource.Info.action_inputs(action.name)
    |> Enum.filter(&is_atom/1)
    |> Enum.sort()
  end

  # `Ash.Resource.Info.policies/1` does not exist in ash 3.33; the real API is
  # `Ash.Policy.Info.policies/1` (core ash since the policy authorizer moved
  # in). Prefer the Resource.Info form if a future ash exports it, and carry
  # whatever the authorizer declares, read-only, for EVERY public action.
  defp policies(resource) do
    cond do
      function_exported?(Ash.Resource.Info, :policies, 1) ->
        # apply/3: the remote call must stay dynamic or the compiler warns
        # about the not-yet-existing Ash.Resource.Info.policies/1.
        apply(Ash.Resource.Info, :policies, [resource])

      function_exported?(Ash.Policy.Info, :policies, 1) ->
        Ash.Policy.Info.policies(resource)

      true ->
        []
    end
  end
end
