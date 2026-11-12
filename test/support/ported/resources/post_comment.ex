# SPDX-FileCopyrightText: 2025 ash_typescript contributors <https://github.com/ash-project/ash_typescript/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshSurface.Ported.PostComment do
  @moduledoc """
  Test resource for post comments.
  """
  use Ash.Resource,
    domain: AshSurface.Ported.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshSurface.Resource]

  surface do
    type_name("PostComment")
  end

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:content, :string, allow_nil?: false, public?: true)
    attribute(:approved, :boolean, default: false, public?: true)
  end

  relationships do
    belongs_to(:post, AshSurface.Ported.Post, public?: true)
    belongs_to(:author, AshSurface.Ported.User, public?: true)
  end

  actions do
    defaults([:create, :read, :update, :destroy])
  end
end
