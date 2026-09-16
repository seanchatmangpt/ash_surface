
defmodule AshSurface.Intent.IR do
  @moduledoc """
  Canonical IR action shape consumed by the candidate envelope.

  Canonical-local declaration: this module owns the IR action shape until
  a dedicated `ir.ex` is admitted. An IR action is identified by
  `action_id` and carries two optional sections, each a plain map or
  `nil`:

    * `:capability` -- `%{capability_id: ...}`
    * `:semantic` -- `%{semantic_id: ..., subject_iri: ...}`

  A `nil` section is legal and meaningful: it means the source projected
  no such section, and every field that would have been pulled from it
  must surface as `nil`, never as a fabricated default.
  """

  @enforce_keys [:action_id]
  defstruct [:action_id, :capability, :semantic]

  @type section :: map() | nil

  @type t :: %__MODULE__{
          action_id: String.t(),
          capability: section(),
          semantic: section()
        }

  @doc """
  Creates an IR action. Sections default to `nil`; pass plain maps with
  atom keys (`%{capability_id: id}`, `%{semantic_id: id, subject_iri: iri}`).
  """
  @spec create(String.t(), section(), section()) :: t()
  def create(action_id, capability \\ nil, semantic \\ nil)
      when is_binary(action_id) and (is_map(capability) or is_nil(capability)) and
             (is_map(semantic) or is_nil(semantic)) do
    %__MODULE__{action_id: action_id, capability: capability, semantic: semantic}
  end
end

defmodule AshSurface.Intent.Candidate do
  @moduledoc """
  SA2A candidate envelope, shaped after `ash_a2a`'s candidate semantics.

  `to_candidate/2` folds a `SurfaceIntent` together with the IR action it
  names into the candidate envelope. Like `ash_a2a`'s resolutions, the
  envelope always self-describes as `standing: :candidate,
  authority: :none`.

  A candidate is DATA, never sent: this module performs no dispatch, no
  transport selection, and no mutation of the intent or the IR. Fields are
  pulled honestly -- `capability_id` from the IR capability section,
  `semantic_id`/`subject_iri` from the IR semantic section, and `input`
  passed through from the intent untransformed. A missing section or field
  yields `nil`, never a placeholder.
  """

  alias AshSurface.Intent
  alias AshSurface.Intent.IR

  @envelope_keys ~w(capability_id subject_iri input semantic_id standing authority)a

  @doc """
  Projects `intent` and `ir_action` into the SA2A candidate envelope.

  Returns a plain map with:

    * `:capability_id` -- from `ir_action.capability.capability_id`
    * `:subject_iri` -- from `ir_action.semantic.subject_iri`
    * `:input` -- the intent's input, untransformed
    * `:semantic_id` -- from `ir_action.semantic.semantic_id`
    * `:standing` -- always `:candidate`
    * `:authority` -- always `:none`
  """
  @spec to_candidate(Intent.t(), IR.t()) :: map()
  def to_candidate(%Intent{} = intent, %IR{} = ir_action) do
    Map.new(@envelope_keys, fn
      :capability_id -> {:capability_id, section_field(ir_action.capability, :capability_id)}
      :subject_iri -> {:subject_iri, section_field(ir_action.semantic, :subject_iri)}
      :input -> {:input, intent.input}
      :semantic_id -> {:semantic_id, section_field(ir_action.semantic, :semantic_id)}
      :standing -> {:standing, :candidate}
      :authority -> {:authority, :none}
    end)
  end

  defp section_field(nil, _field), do: nil
  defp section_field(section, field) when is_map(section), do: Map.get(section, field)
end
