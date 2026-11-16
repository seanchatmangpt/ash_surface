# Policy denials are not field errors; surface them under a pseudo-field so the admin
# form shows "forbidden by policy" instead of AshPhoenix logging an unhandled error.
defimpl AshPhoenix.FormData.Error, for: Ash.Error.Forbidden.Policy do
  def to_form_error(_error), do: {:_policy, "forbidden by policy", []}
end
