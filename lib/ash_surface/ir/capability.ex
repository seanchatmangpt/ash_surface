# The IR capability section — owner file per the no_local_do law: the ONLY
# module on the surface that may define, or be called through, for
# `authority_required`. Extracted verbatim from ir.ex at v50 integration.

defmodule AshSurface.IR.Capability do
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
  
  @doc """
  Reads the recorded authority requirement — a carried fact, never a grant.
  """
  @spec authority_required(t()) :: boolean()
  def authority_required(%__MODULE__{authority_required: required}), do: required == true
end
