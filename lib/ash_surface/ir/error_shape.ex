defmodule AshSurface.IR.ErrorShape do
  @moduledoc """
  The closed error-type vocabulary of the surface error contract
  (ash_typescript `AshTypescript.Rpc.Error` parity). `unknown_error` is the
  catch-all: any wire error whose `type` is not otherwise recognised is
  normalised to it, so the discriminated union over `type` is total.
  """

  @types ~w(
    invalid_changes invalid_query not_found required forbidden forbidden_field
    invalid_attribute invalid_argument invalid_keyset invalid_page tenant_required
    invalid_primary_key unknown_error authentication_failed invalid_token
    invalid_identity missing_identity sort_not_supported pagination_not_supported
    invalid_pagination
  )

  @catch_all "unknown_error"

  @enforce_keys [:type]
  defstruct [:type, fields: [], path: []]

  @type t :: %__MODULE__{type: String.t(), fields: [String.t()], path: list()}

  @doc "The closed enum of error types, in canonical order."
  @spec types() :: [String.t()]
  def types, do: @types

  @doc "The catch-all error type."
  @spec catch_all() :: String.t()
  def catch_all, do: @catch_all

  @spec valid_type?(term()) :: boolean()
  def valid_type?(type), do: type in @types

  @doc "Normalises any type (binary or atom) into the closed enum; unknown -> `unknown_error`."
  @spec normalize_type(term()) :: String.t()
  def normalize_type(type) when is_atom(type) and not is_nil(type),
    do: normalize_type(Atom.to_string(type))

  def normalize_type(type) when is_binary(type) do
    if type in @types, do: type, else: @catch_all
  end

  def normalize_type(_), do: @catch_all

  @doc "Builds a shape; the type is normalised into the closed enum."
  @spec new(term(), keyword()) :: t()
  def new(type, opts \\ []) do
    %__MODULE__{
      type: normalize_type(type),
      fields: Keyword.get(opts, :fields, []),
      path: Keyword.get(opts, :path, [])
    }
  end
end
