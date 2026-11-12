defmodule AshSurface.Ported.RFP do
  @moduledoc """
  Test entry for the ported requested-fields processor: builds the real
  `Ash.Info.Manifest` of `AshSurface.Ported.Domain` once, decorates it, and delegates to
  `AshSurface.RuntimeParity.RequestedFieldsProcessor` (same arities as the reference).
  """
  alias AshSurface.RuntimeParity.RequestedFields.Compat
  alias AshSurface.RuntimeParity.RequestedFieldsProcessor

  @otp_app :ash_surface_ported
  @key {__MODULE__, :handle}

  def manifest do
    case :persistent_term.get(@key, nil) do
      nil ->
        Application.put_env(@otp_app, :ash_domains, [AshSurface.Ported.Domain])
        {:ok, manifest} = Ash.Info.Manifest.generate(otp_app: @otp_app)
        handle = Compat.prepare(manifest)
        :persistent_term.put(@key, handle)
        handle

      handle ->
        handle
    end
  end

  def process(resource, action, fields, opts \\ []),
    do: RequestedFieldsProcessor.process(resource, action, fields, manifest(), opts)

  def atomize_requested_fields(fields, resource \\ nil),
    do: RequestedFieldsProcessor.atomize_requested_fields(fields, resource, manifest())
end
