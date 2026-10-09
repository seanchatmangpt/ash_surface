#  reference

<!-- ============================================================= -->
<!-- AGENT-FORBIDDEN-BEGIN: reference body is RIGID                -->
<!-- Every row below is rendered from queries/ast_extract.rq.      -->
<!-- Agents MUST NOT add, edit, reorder, or remove any row or      -->
<!-- table cell. Prose outside the fenced slot below is refused    -->
<!-- by the doc_quality court.                                     -->
<!-- ============================================================= -->

## Modules


### AshSurface.Health

| `check` | function | check/0 |  |  |  |  |

| `check_surface` | function | check_surface/2 |  |  |  |  |

| `ready?` | function | ready?/0 |  |  |  |  |

| `to_map` | function | to_map/1 |  |  |  |  |

| `check_result` | type | @type check_result :: %{ name: atom(), status: :ok | :error, detail: term() } |  |  |  |  |

| `refusal` | type | @type refusal :: %{ standing: :REFUSED_INVALID_SUBJECT | :REFUSED_INVALID_OPTION, reason: term(), authority_boundary: :OBSERVE } |  |  |  |  |

| `report` | type | @type report :: %{ status: :ok | :degraded, authority_boundary: :OBSERVE, checks: [check_result()], checked_at: DateTime.t() } |  |  |  |  |

| `surface_report` | type | @type surface_report :: %{ status: surface_status(), subject: String.t(), authority_boundary: :OBSERVE, checks: [check_result()] } |  |  |  |  |

| `surface_status` | type | @type surface_status :: :healthy | :missing_runtime | :digest_drift |  |  |  |  |



<!-- AGENT-FORBIDDEN-END -->

## Signature/type/default/errors table

<!-- RIGID table: header order is fixed; rows come only from the query. -->

| Item | Type | Signature | Params | Defaults | Errors | Invariants |
|------|------|-----------|--------|----------|--------|------------|

| `check` | function | check/0 |  |  |  |  |

| `check_surface` | function | check_surface/2 |  |  |  |  |

| `ready?` | function | ready?/0 |  |  |  |  |

| `to_map` | function | to_map/1 |  |  |  |  |

| `check_result` | type | @type check_result :: %{ name: atom(), status: :ok | :error, detail: term() } |  |  |  |  |

| `refusal` | type | @type refusal :: %{ standing: :REFUSED_INVALID_SUBJECT | :REFUSED_INVALID_OPTION, reason: term(), authority_boundary: :OBSERVE } |  |  |  |  |

| `report` | type | @type report :: %{ status: :ok | :degraded, authority_boundary: :OBSERVE, checks: [check_result()], checked_at: DateTime.t() } |  |  |  |  |

| `surface_report` | type | @type surface_report :: %{ status: surface_status(), subject: String.t(), authority_boundary: :OBSERVE, checks: [check_result()] } |  |  |  |  |

| `surface_status` | type | @type surface_status :: :healthy | :missing_runtime | :digest_drift |  |  |  |  |


<!-- ============================================================= -->
<!-- AGENT-FORBIDDEN-END: nothing below this line may describe     -->
<!-- code behavior.                                                -->
<!-- ============================================================= -->
