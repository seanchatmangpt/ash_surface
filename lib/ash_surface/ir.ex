defmodule AshSurface.IR do
  @moduledoc false

  # DiscoverOnce law carrier: the normalized term produced by exactly ONE
  # discovery pass over a source. Compilation sections never see the raw
  # source; every section of a run receives this struct, identical for all
  # of them. Normalization is canonical — equal sources normalize to the
  # identical term regardless of input order or omitted defaults.

  @enforce_keys [:actions, :digest]
  defstruct [:actions, :digest]

  @admitted_transports [:auto, :http, :phoenix_channel]

  @type action :: %{
          required(:action) => atom(),
          required(:transport) => transport(),
          required(:public) => boolean()
        }

  @type transport :: :auto | :http | :phoenix_channel

  @type t :: %__MODULE__{actions: [action()], digest: String.t()}

  @spec normalize([atom() | action()]) :: t()
  def normalize(raw_actions) when is_list(raw_actions) do
    actions =
      raw_actions
      |> Enum.map(&normalize_action/1)
      |> Enum.sort_by(& &1.action)

    %__MODULE__{actions: actions, digest: digest(actions)}
  end

  def normalize(_other) do
    raise ArgumentError, "AshSurface.IR.normalize/1 expects a list of action declarations"
  end

  # Atom declarations become full maps with the canonical defaults; map
  # declarations have defaults filled. Anything else — including a transport
  # outside the admitted projection facets — is refused at normalization,
  # never silently coerced.
  defp normalize_action(name) when is_atom(name) do
    %{action: name, transport: :auto, public: true}
  end

  defp normalize_action(%{action: name} = declaration) when is_atom(name) do
    transport = Map.get(declaration, :transport, :auto)

    if transport in @admitted_transports do
      %{action: name, transport: transport, public: Map.get(declaration, :public, true)}
    else
      raise ArgumentError,
            "action #{inspect(name)} declares inadmitted transport #{inspect(transport)}"
    end
  end

  defp normalize_action(other) do
    raise ArgumentError,
          "every action declaration must be an atom or a map with an atom :action, got: #{inspect(other)}"
  end

  defp digest(actions) do
    :sha256
    |> :crypto.hash(:erlang.term_to_binary(actions))
    |> Base.encode16(case: :lower)
  end
end
