# Single shared definition of the AshAuthentication error structs (ash_authentication is not a
# dependency; UNVERIFIED against the real module). Fake of an unavailable third-party
# collaborator, defined ONCE here so no test file defines it (duplicate-definition court).
# Fields are the union needed by every pin: [:field, :message, :count].
unless Code.ensure_loaded?(AshAuthentication.Errors.AuthenticationFailed) do
  defmodule AshAuthentication.Errors.AuthenticationFailed do
    use Splode.Error, fields: [:field, :message, :count], class: :forbidden
    def message(%{message: m}), do: m || "error"
  end
end

unless Code.ensure_loaded?(AshAuthentication.Errors.InvalidToken) do
  defmodule AshAuthentication.Errors.InvalidToken do
    use Splode.Error, fields: [:field, :message, :count], class: :forbidden
    def message(%{message: m}), do: m || "error"
  end
end
