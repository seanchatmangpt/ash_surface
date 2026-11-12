defmodule AshSurface.Ported.Domain do
  @moduledoc "Shared ported-fixture domain (counterpart of AshTypescript.Test.Domain, rpc entries omitted)."
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(AshSurface.Ported.Todo)
    resource(AshSurface.Ported.TodoComment)
    resource(AshSurface.Ported.User)
    resource(AshSurface.Ported.UserSettings)
    resource(AshSurface.Ported.OrgTodo)
    resource(AshSurface.Ported.OrgComment)
    resource(AshSurface.Ported.Task)
    resource(AshSurface.Ported.NotExposed)
    resource(AshSurface.Ported.Post)
    resource(AshSurface.Ported.PostComment)
    resource(AshSurface.Ported.NoRelationshipsResource)
    resource(AshSurface.Ported.EmptyResource)
    resource(AshSurface.Ported.MapFieldResource)
    resource(AshSurface.Ported.Content)
    resource(AshSurface.Ported.Article)
    resource(AshSurface.Ported.Subscription)
    resource(AshSurface.Ported.TenantSetting)
    resource(AshSurface.Ported.InputParsing.Resource)
    resource(AshSurface.Ported.NestedMapResource)
    resource(AshSurface.Ported.StructFilterUser)
  end
end
