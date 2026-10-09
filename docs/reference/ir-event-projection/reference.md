#  reference

<!-- ============================================================= -->
<!-- AGENT-FORBIDDEN-BEGIN: reference body is RIGID                -->
<!-- Every row below is rendered from queries/ast_extract.rq.      -->
<!-- Agents MUST NOT add, edit, reorder, or remove any row or      -->
<!-- table cell. Prose outside the fenced slot below is refused    -->
<!-- by the doc_quality court.                                     -->
<!-- ============================================================= -->

## Modules


### AshSurface.IR.EventProjection

| `from_receipt` | function | from_receipt/2 |  |  |  |  |

| `ir_action` | type | @type ir_action :: %{ optional(:resource) => String.t(), optional(:action) => String.t(), optional(:semantic) => semantic(), # JSON-decoded receipts/actions arrive with string keys; every key # above is read through both spellings (see `fetch/2`). optional(String.t()) => term() } |  |  |  |  |

| `receipt` | type | @type receipt :: map() |  |  |  |  |

| `refusal` | type | @type refusal :: %{ required(:standing) => atom(), required(:reason) => term(), required(:authority_boundary) => :OBSERVE } |  |  |  |  |

| `semantic` | type | @type semantic :: %{ optional(:subject_iri) => String.t() | nil, optional(String.t()) => term() } |  |  |  |  |



<!-- AGENT-FORBIDDEN-END -->

## Signature/type/default/errors table

<!-- RIGID table: header order is fixed; rows come only from the query. -->

| Item | Type | Signature | Params | Defaults | Errors | Invariants |
|------|------|-----------|--------|----------|--------|------------|

| `from_receipt` | function | from_receipt/2 |  |  |  |  |

| `ir_action` | type | @type ir_action :: %{ optional(:resource) => String.t(), optional(:action) => String.t(), optional(:semantic) => semantic(), # JSON-decoded receipts/actions arrive with string keys; every key # above is read through both spellings (see `fetch/2`). optional(String.t()) => term() } |  |  |  |  |

| `receipt` | type | @type receipt :: map() |  |  |  |  |

| `refusal` | type | @type refusal :: %{ required(:standing) => atom(), required(:reason) => term(), required(:authority_boundary) => :OBSERVE } |  |  |  |  |

| `semantic` | type | @type semantic :: %{ optional(:subject_iri) => String.t() | nil, optional(String.t()) => term() } |  |  |  |  |


<!-- ============================================================= -->
<!-- AGENT-FORBIDDEN-END: nothing below this line may describe     -->
<!-- code behavior.                                                -->
<!-- ============================================================= -->
