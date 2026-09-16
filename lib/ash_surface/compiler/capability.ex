defmodule AshSurface.Compiler.IR.Capability do
  @moduledoc """
  Canonical IR shape for one capability entry of the capability section.

  Local canonical declaration (no `ir.ex` exists yet at this worktree); once
  a shared `AshSurface.Compiler.IR` module lands it owns this shape and this
  declaration moves there unchanged.

  Every field is delegated truth, never `ash_surface` invention:

    * `capability_id` -- verbatim `AshA2A.Skill.id`, the stable id
      `AshA2A.CapabilityIndex.Compiler.capability_id/2` derives from the
      canonical public action (`inspect(resource) <> "." <> atom(action)`).
    * `consequence_class` -- verbatim `AshA2A.Skill.consequence`
      (`:observe` / `:change` / `:external_do`, plus the fail-closed
      `:unknown` default a generic `:action` carries until its author
      classifies it).
    * `authority_required` / `receipt_required` -- read off that consequence
      by `AshA2A.CommandBus`'s published admission law (see
      `AshSurface.Compiler.Capability`).
  """

  # Mirrors AshA2A.Skill's `consequence` union verbatim (stated inline because
  # ash_a2a is a test-env-only dependency here; no remote compile-time ref).
  @type consequence_class :: :observe | :change | :external_do | :unknown

  @type t :: %__MODULE__{
          capability_id: String.t() | nil,
          consequence_class: consequence_class() | nil,
          authority_required: boolean() | nil,
          receipt_required: boolean() | nil
        }

  @enforce_keys [:capability_id, :consequence_class, :authority_required, :receipt_required]
  defstruct [:capability_id, :consequence_class, :authority_required, :receipt_required]
end

defmodule AshSurface.Compiler.Capability do
  @moduledoc """
  Capability-section builder: a pure projection of `AshA2A`'s derived
  capability index.

  `ash_surface` invents none of the capability semantics. All four truths
  come from `ash_a2a`:

    * `capability_id` -- `AshA2A.Info.capability_index/1` derives the index
      from `Ash.Resource.Info.public_actions/1` (minus `expose?: false`
      overrides); each entry's `id` is the delegated capability id.
    * `consequence_class` -- the entry's `consequence`, classified at
      compile time by `AshA2A.CapabilityIndex.Compiler` (`:read` ->
      `:observe`, `:create`/`:update`/`:destroy` -> `:change`, explicit
      `consequence:` overrides -> `:external_do`/whatever the author
      declared, unclassified generic `:action` -> `:unknown`).
    * `authority_required` / `receipt_required` -- `AshA2A.CommandBus`'s
      admission law: `:observe` is admitted with no `AshA2A.Authority` and
      anchors no receipt; `:change`/`:external_do` are refused with
      `:authority_required` on a nil authority and `RECEIPT_ANCHORED` is
      mandatory for them before DO.

  `:unknown` is ash_a2a's fail-closed fence (`:consequence_unclassified`
  refusal in `CommandBus.admit/2`), so this builder does not fabricate a
  boolean for it: `authority_required`/`receipt_required` stay `nil` until
  the resource author classifies the skill.

  An unregistered resource (no `AshA2A` extension) has no compiled index;
  `build/1` returns `nil` for it -- no id, no class, no capability invented.
  """

  alias AshSurface.Compiler.IR.Capability
  @spec build(module()) :: [Capability.t()] | nil
  def build(resource) when is_atom(resource) do
    # Direct call: v23's canonical dependency set carries ash_a2a in every
    # env, so no apply/3 laundering is needed (or lawful — no_local_do).
    index = AshA2A.Info.capability_index(resource)

    case index do
      nil -> nil
      skills -> Enum.map(skills, &project/1)
    end
  end

  # Skill-shaped map match (not %AshA2A.Skill{}): ash_a2a is test-env-only
  # in this branch, and a struct expansion would demand the module at
  # compile time in every env. The atom alias needs no loaded module.
  defp project(%{__struct__: AshA2A.Skill, id: id, consequence: consequence}) do
    %Capability{
      capability_id: id,
      consequence_class: consequence,
      authority_required: authority_required?(consequence),
      receipt_required: receipt_required?(consequence)
    }
  end

  # AshA2A.CommandBus.admit/2: a nil authority on a :change/:external_do
  # skill is refused with :authority_required; :observe is admitted with no
  # authority at all. :unknown never reaches the authority question (it is
  # refused earlier as :consequence_unclassified), so it keeps nil -- the
  # fence, not a fabricated false.
  defp authority_required?(consequence) when consequence in [:change, :external_do], do: true
  defp authority_required?(:observe), do: false
  defp authority_required?(:unknown), do: nil

  # AshA2A.CommandBus: RECEIPT_ANCHORED is mandatory for :change and
  # :external_do; prepare_receipt_anchor/3 for :observe yields {:ok, nil} --
  # no receipt exists for a never-consequence-bearing skill.
  defp receipt_required?(consequence) when consequence in [:change, :external_do], do: true
  defp receipt_required?(:observe), do: false
  defp receipt_required?(:unknown), do: nil
end
