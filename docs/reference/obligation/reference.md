#  reference

<!-- ============================================================= -->
<!-- AGENT-FORBIDDEN-BEGIN: reference body is RIGID                -->
<!-- Every row below is rendered from queries/ast_extract.rq.      -->
<!-- Agents MUST NOT add, edit, reorder, or remove any row or      -->
<!-- table cell. Prose outside the fenced slot below is refused    -->
<!-- by the doc_quality court.                                     -->
<!-- ============================================================= -->

## Modules


### AshSurface.Obligation

| `create` | function | create/4 |  |  |  |  |

| `to_map` | function | to_map/1 |  |  |  |  |

| `AshSurface.Obligation` | struct | defstruct obligation_id, exact_subject, capability_id, cause_ref, status, state_digest, assigned_to, receipt_ref, postcondition_ref, escalation_path: [], evidence_refs: [], authority_boundary: :OBSERVE |  |  |  |  |

| `status` | type | @type status :: :open | :assigned | :acknowledged | :executing | :resolved | :blocked | :unknown |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ obligation_id: String.t(), exact_subject: String.t(), capability_id: String.t(), cause_ref: String.t(), status: status(), state_digest: String.t(), assigned_to: String.t() | nil, receipt_ref: String.t() | nil, postcondition_ref: String.t() | nil, escalation_path: [String.t()], evidence_refs: [String.t()], authority_boundary: :OBSERVE } |  |  |  |  |



<!-- AGENT-FORBIDDEN-END -->

## Signature/type/default/errors table

<!-- RIGID table: header order is fixed; rows come only from the query. -->

| Item | Type | Signature | Params | Defaults | Errors | Invariants |
|------|------|-----------|--------|----------|--------|------------|

| `create` | function | create/4 |  |  |  |  |

| `to_map` | function | to_map/1 |  |  |  |  |

| `AshSurface.Obligation` | struct | defstruct obligation_id, exact_subject, capability_id, cause_ref, status, state_digest, assigned_to, receipt_ref, postcondition_ref, escalation_path: [], evidence_refs: [], authority_boundary: :OBSERVE |  |  |  |  |

| `status` | type | @type status :: :open | :assigned | :acknowledged | :executing | :resolved | :blocked | :unknown |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ obligation_id: String.t(), exact_subject: String.t(), capability_id: String.t(), cause_ref: String.t(), status: status(), state_digest: String.t(), assigned_to: String.t() | nil, receipt_ref: String.t() | nil, postcondition_ref: String.t() | nil, escalation_path: [String.t()], evidence_refs: [String.t()], authority_boundary: :OBSERVE } |  |  |  |  |


<!-- ============================================================= -->
<!-- AGENT-FORBIDDEN-END: nothing below this line may describe     -->
<!-- code behavior.                                                -->
<!-- ============================================================= -->
