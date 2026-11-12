# ported-fixtures

Shared Ash resource fixtures for the ash_typescript test port (lanes T5..T12). Read-only for
every lane except T5.

## Modules

- `AshSurface.Ported.Domain` (`domain.ex`): plain `Ash.Domain` listing every fixture
  resource. No rpc entries (ash_surface has no domain rpc DSL).
- `AshSurface.Ported.*` (`resources/`): port of `AshTypescript.Test.*` resources
  (Todo, TodoComment, User, UserSettings, OrgTodo, OrgComment, Task, NotExposed, Post,
  PostComment, Content, Article, Subscription, TenantSetting, NestedMapResource,
  StructFilterUser, MapFieldResource, EmptyResource, NoRelationshipsResource,
  InputParsing.*, embedded/typed-struct/calculation helper modules).
- `types/`: custom Ash types (GeoPoint, CustomMetadata, RouteSettings, ...).
  `AshMoney.Types.Money` is a stub type (as in the reference).

## Deltas from the reference

- `extensions: [AshTypescript.Resource]` -> `[AshSurface.Resource]`; `typescript do` ->
  `surface do` (type_name, field_names, argument_names carry over).
- Dropped: `AshPostgres.Ltree` attributes `hierarchy`/`strict_hierarchy` (no ash_postgres dep;
  T7 records ltree as a gap), channel/typed_controller resources (T13/T14), `Session`.
- Domain `typescript_rpc` actions are omitted; projections are declared per resource.
