# SPDX-FileCopyrightText: 2025 ash_typescript contributors <https://github.com/ash-project/ash_typescript/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshSurface.Ported.InputParsing.ProcessProfileResult do
  @moduledoc """
  NewType for process_profile action return type with typescript_field_names.
  """
  use Ash.Type.NewType,
    subtype_of: :map,
    constraints: [
      fields: [
        profile_name: [type: :string, allow_nil?: false],
        is_processed?: [type: :boolean, allow_nil?: false]
      ]
    ]

  def typescript_field_names do
    [
      is_processed?: "isProcessed"
    ]
  end
end
