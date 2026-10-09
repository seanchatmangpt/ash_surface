#  reference

<!-- ============================================================= -->
<!-- AGENT-FORBIDDEN-BEGIN: reference body is RIGID                -->
<!-- Every row below is rendered from queries/ast_extract.rq.      -->
<!-- Agents MUST NOT add, edit, reorder, or remove any row or      -->
<!-- table cell. Prose outside the fenced slot below is refused    -->
<!-- by the doc_quality court.                                     -->
<!-- ============================================================= -->

## Modules


### AshSurface.Idempotency

| `admit` | function | admit/3 |  |  |  |  |

| `complete` | function | complete/4 |  |  |  |  |

| `derive_key` | function | derive_key/2 |  |  |  |  |

| `protocol` | function | protocol/0 |  |  |  |  |

| `request_digest` | function | request_digest/2 |  |  |  |  |

| `reserve` | function | reserve/3 |  |  |  |  |

| `valid_key?` | function | valid_key?/1 |  |  |  |  |

| `validate_key` | function | validate_key/1 |  |  |  |  |

| `admission` | type | @type admission :: :first | {:replay, term()} | {:conflict, :digest_mismatch | :in_flight} |  |  |  |  |

| `entry` | type | @type entry :: %{digest: String.t(), outcome: :pending | {:done, term()}} |  |  |  |  |

| `state` | type | @type state :: %{optional(String.t()) => entry()} |  |  |  |  |



<!-- AGENT-FORBIDDEN-END -->

## Signature/type/default/errors table

<!-- RIGID table: header order is fixed; rows come only from the query. -->

| Item | Type | Signature | Params | Defaults | Errors | Invariants |
|------|------|-----------|--------|----------|--------|------------|

| `admit` | function | admit/3 |  |  |  |  |

| `complete` | function | complete/4 |  |  |  |  |

| `derive_key` | function | derive_key/2 |  |  |  |  |

| `protocol` | function | protocol/0 |  |  |  |  |

| `request_digest` | function | request_digest/2 |  |  |  |  |

| `reserve` | function | reserve/3 |  |  |  |  |

| `valid_key?` | function | valid_key?/1 |  |  |  |  |

| `validate_key` | function | validate_key/1 |  |  |  |  |

| `admission` | type | @type admission :: :first | {:replay, term()} | {:conflict, :digest_mismatch | :in_flight} |  |  |  |  |

| `entry` | type | @type entry :: %{digest: String.t(), outcome: :pending | {:done, term()}} |  |  |  |  |

| `state` | type | @type state :: %{optional(String.t()) => entry()} |  |  |  |  |


<!-- ============================================================= -->
<!-- AGENT-FORBIDDEN-END: nothing below this line may describe     -->
<!-- code behavior.                                                -->
<!-- ============================================================= -->
