defmodule AshSurface.IR do
  @moduledoc """
  Truth intermediate representation (IR) for consumer surface sections.

  IR nodes carry only facts witnessed on compiled Ash resources through public
  Ash introspection. Presentation facts (labels, placeholders, widgets, icons,
  ordering) and semantic guesses (inferred formats, examples, domain meaning a
  resource never declared) are not representable in these structs: every field
  is enforced and traced back to `public_actions`, action `arguments`, declared
  `returns`, or declared policies.
  """

  defmodule Ash do
    @moduledoc """
    Truth projection of exactly one public Ash action.

    Sourced from `Ash.Resource.Info.public_actions/1` (admission), the action's
    `arguments` (typed inputs, `allow_nil?` as required-vs-optional, declared
    defaults), the action's declared `returns` (outputs, `nil` when the action
    type declares none), and `Ash.Policy.Info.policies/1` (read-only policy
    facts, never evaluations).
    """

    @enforce_keys [:resource, :action, :action_type, :inputs, :outputs, :policies]
    defstruct [:resource, :action, :action_type, :inputs, :outputs, :policies]

    @type t :: %__MODULE__{
            resource: module(),
            action: atom(),
            action_type: atom(),
            inputs: [AshSurface.IR.Input.t()],
            outputs: AshSurface.IR.Output.t() | nil,
            policies: [AshSurface.IR.Policy.t()]
          }
  end

  defmodule Input do
    @moduledoc """
    One declared action argument.

    `type` is the witnessed Ash type name (Ash's own short-name registry,
    inverted; module name for types outside it). `required` is the mechanical
    negation of the argument's `allow_nil?`. `default` is the declared default,
    surfaced verbatim (`nil` when none was declared).
    """

    @enforce_keys [:name, :type, :required, :default]
    defstruct [:name, :type, :required, :default]

    @type t :: %__MODULE__{
            name: atom(),
            type: String.t(),
            required: boolean(),
            default: term()
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
end
