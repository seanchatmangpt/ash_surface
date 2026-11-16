defmodule Playground.Jobs do
  @moduledoc "Demo domain carrying AshOban triggers/scheduled actions shown in the admin Jobs page."
  use Ash.Domain, otp_app: :playground, validate_config_inclusion?: false

  resources do
    resource Playground.Jobs.Digest
  end
end
