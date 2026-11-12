defmodule AshSurface.Ported.AshNames do
  @moduledoc """
  Test pin: the identity output formatter. Courts written before emitted keys followed
  `Config.output_field_formatter/0` (default `:camel_case`, lane F1-fieldwire) assert
  naming-independent schema semantics over Ash names; their compile helpers run under this
  formatter so those pins stay about what they test. Default-on camelCase, explicit formatters
  and mappings are asserted in `formatter_artifact_test.exs` and the field-naming court.
  """

  @doc "Identity formatter: the Ash name verbatim."
  def verbatim(name), do: to_string(name)

  @doc """
  Runs `fun` with the identity formatter as the calling process's output formatter
  (`AshSurface.FieldName.with_formatter/2`: process-scoped, safe under async tests). A formatter
  set explicitly in the application env wins, so courts that configure one still exercise it.
  """
  def with_verbatim(fun) do
    case Application.fetch_env(:ash_surface, :output_field_formatter) do
      {:ok, formatter} when not is_nil(formatter) ->
        AshSurface.FieldName.with_formatter(formatter, fun)

      _ ->
        AshSurface.FieldName.with_formatter({__MODULE__, :verbatim}, fun)
    end
  end

  @doc "`ResourceFacts.build/2` under the identity formatter (Ash names in the facts)."
  def facts(resource, action),
    do: with_verbatim(fn -> AshSurface.Compiler.ResourceFacts.build(resource, action) end)
end
