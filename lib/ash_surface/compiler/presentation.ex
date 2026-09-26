defmodule AshSurface.Compiler.IR.Presentation do
  @moduledoc """
  Canonical presentation IR shape (owned by a compiler `ir.ex` once more
  sections exist; declared here first).

  All five fields are ash_admin-style PRESENTATION overrides — the only
  metadata ash_surface owns. They carry zero business semantics: Ash
  resources/actions/policies remain authoritative (AGENTS.md boundary #1).
  """

  defstruct label: nil, group: nil, order: 0, widget: "default", format: nil

  @type t :: %__MODULE__{
          label: String.t(),
          group: String.t() | nil,
          order: number(),
          widget: String.t(),
          format: String.t() | nil
        }
end

defmodule AshSurface.Compiler.Presentation do
  @moduledoc """
  Presentation section reader — the ONLY metadata ash_surface owns.

  ash_admin-style presentation overrides ride the action's `custom.ash_surface`
  envelope under a `"presentation"` map (string keys, matching the envelope the
  manifest decorator writes). This is the plain metadata reader FIRST: the
  Spark DSL section (a `surf:SurfaceSection` sibling, `aex:sectionName
  "presentation"`) must project into the same `build/2` truth when it is
  admitted — the DSL is a front door, never a second reader.

  The envelope key is read as `:ash_surface` (as written on the in-memory
  manifest) or `"ash_surface"` (as it returns from a JSON round-trip).
  """

  alias AshSurface.Compiler.IR.Presentation

  # Widget vocabulary is presentation-layer ONLY; it never encodes business
  # semantics. Extension goes through ontology admission (aex:FieldOneOfValue
  # on the presentation section), never ad-hoc additions here.
  @admitted_widgets ~w(default text textarea toggle select number date)

  @doc """
  Reads presentation metadata for one action from its `custom` map.

  Defaults when metadata is absent: `label` is the humanized action name,
  `group` and `format` are nil, `order` is 0, `widget` is "default". A widget
  outside the admitted vocabulary — including a wrong-kind (non-string)
  widget — is a typed rejection; the vocabulary is admitted, never guessed.
  """
  @spec build(term(), map()) :: {:ok, Presentation.t()} | {:error, [map()]}
  def build(action, custom) when is_map(custom) do
    with {:ok, name} <- action_identity(action),
         {:ok, overrides} <- presentation_overrides(custom),
         :ok <- admit_widget(name, overrides) do
      {:ok,
       %Presentation{
         label: overrides["label"] || humanize(name),
         group: overrides["group"],
         order: overrides["order"] || 0,
         widget: overrides["widget"] || "default",
         format: overrides["format"]
       }}
    end
  end

  def build(_action, _custom) do
    {:error, invalid_compilation("custom metadata must be a map")}
  end

  # The reader consumes identity only: an atom action name or anything
  # shape-compatible with a manifest entrypoint's action (`%{name: atom}`).
  # Real Ash action structs satisfy the map clause; no resource is required.
  defp action_identity(name) when is_atom(name), do: {:ok, name}

  defp action_identity(%{name: name}) when is_atom(name), do: {:ok, name}

  defp action_identity(_other) do
    {:error,
     invalid_compilation(
       "an action is an atom action name or a map with an atom :name (e.g. a manifest entrypoint action)"
     )}
  end

  defp presentation_overrides(custom) do
    case Map.get(custom, :ash_surface) || Map.get(custom, "ash_surface") do
      nil ->
        {:ok, %{}}

      %{} = envelope ->
        case Map.get(envelope, "presentation") do
          nil -> {:ok, %{}}
          %{} = overrides -> {:ok, overrides}
          _ -> {:error, invalid_compilation("custom.ash_surface presentation must be a map")}
        end

      _other ->
        {:error, invalid_compilation("custom.ash_surface must be a map")}
    end
  end

  defp admit_widget(name, %{"widget" => widget}) do
    if widget in @admitted_widgets do
      :ok
    else
      {:error,
       [
         %{
           code: "unknown_widget_presentation",
           detail:
             "presentation for #{inspect(name)} declares widget #{inspect(widget)}; admitted widgets are " <>
               inspect(@admitted_widgets)
         }
       ]}
    end
  end

  defp admit_widget(_name, _overrides), do: :ok

  # Macro.humanize semantics, vendored: core must not depend on Phoenix
  # (AGENTS.md boundary #7).
  defp humanize(name) when is_atom(name), do: humanize(Atom.to_string(name))

  defp humanize(name) when is_binary(name) do
    name |> String.replace("_", " ") |> String.capitalize()
  end

  defp invalid_compilation(detail) do
    [%{code: "invalid_presentation_compilation", detail: detail}]
  end
end
