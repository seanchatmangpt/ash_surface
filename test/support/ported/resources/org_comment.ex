# SPDX-FileCopyrightText: 2025 ash_typescript contributors <https://github.com/ash-project/ash_typescript/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshSurface.Ported.OrgComment do
  @moduledoc """
  Multitenant comments on org todos — exercises nested relationship query
  options under context multitenancy.
  """
  use Ash.Resource,
    domain: AshSurface.Ported.Domain,
    data_layer: Ash.DataLayer.Ets,
    primary_read_warning?: false,
    extensions: [AshSurface.Resource]

  surface do
    type_name("OrgComment")
  end

  ets do
    private?(true)
  end

  multitenancy do
    strategy(:context)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :content, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :rating, :integer do
      constraints(min: 1, max: 5)
      public?(true)
    end

    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :org_todo, AshSurface.Ported.OrgTodo do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :user, AshSurface.Ported.User do
      allow_nil?(false)
      public?(true)
    end
  end

  actions do
    defaults([:destroy])

    read :read do
      primary?(true)
      pagination(offset?: true, keyset?: true, countable: true, required?: false)
    end

    create :create do
      accept([:content, :rating])

      argument :user_id, :uuid do
        allow_nil?(false)
        public?(true)
      end

      argument :org_todo_id, :uuid do
        allow_nil?(false)
        public?(true)
      end

      change(manage_relationship(:user_id, :user, type: :append))
      change(manage_relationship(:org_todo_id, :org_todo, type: :append))
    end

    update :update do
      require_atomic?(false)
      accept([:content, :rating])
    end
  end
end
