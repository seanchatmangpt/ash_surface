# Claim-vs-code correction (gapfix-test-surface-015): this header previously
# claimed `AshSurface.Compiler.IR` and `AshSurface.Compiler.Section` were
# "declared in this file" pending promotion. Neither ever was: this file
# declares only `AshSurface.Compiler.Aria`. The canonical IR slices live in
# lib/ash_surface/compiler/ir.ex and the Section behaviour in
# lib/ash_surface/compiler.ex (v50 integration reconciliation) — the stale
# claim is retracted, not migrated. Note lib/ash_surface/section.ex is the
# distinct `AshSurface.Section` behaviour (v29), not the compiler Section
# (correction detail per gapfix-docs-truth-013).

defmodule AshSurface.Compiler.Aria do
  @moduledoc """
  Accessibility semantics as data: a conservative ARIA contract per action input.

  `build/2` derives, for every input of an action IR schema, an entry with:

    - `"role"` — a conservative role hint from the resolved input type
      (see `role_for_type/1`). Unmapped types get `nil`, never a fabricated role.
    - `"required"` — propagated from `allow_nil?` (`true` exactly when the input
      does not permit nil). No other source invents requiredness.
    - `"label"` — taken from the presentation section's output when one is
      passed in, `nil` otherwise. Presentation never round-trips through guesses.
    - `"describedby"` — a stable element id for the input's descriptive content,
      derived purely from `action_id` + input name, present only when the input
      carries a description; otherwise `nil`.

  This module emits pure data only. It renders nothing: translating these
  contracts into attributes, elements, or components belongs to projectors
  (per the repo doctrine that AshSDUI/live_vue/Expo own rendering).

  The output is a string-keyed map keyed by input name — JSON-serializable and
  deterministic, so the same action always yields byte-identical contracts.
  """

  alias Ash.Info.Manifest.Type
  alias AshSurface.Compiler.IR

  @role_table %{
    string: "textbox",
    ci_string: "textbox",
    boolean: "checkbox",
    enum: "switch",
    integer: "slider"
  }

  @doc "The section name; its output mounts at `schema.aria`."
  @spec name() :: :aria
  def name, do: :aria

  @doc """
  Derives the ARIA contract for every input of `schema`.

  `presentation` may be the presentation section's output: a map keyed by input
  name (atom or string) whose entries may carry a `"label"`/`:label`. A map with
  an `"inputs"`/`:inputs` key holding that keyed map is also accepted. Any other
  shape is refused rather than guessed from.
  """
  @spec build(IR.Schema.t(), map() | nil) :: {:ok, map()} | {:error, term()}
  def build(%IR.Schema{} = schema, presentation \\ nil) do
    with {:ok, action_id} <- action_id(schema.action_id),
         {:ok, presentation} <- normalize_presentation(presentation) do
      inputs = List.wrap(schema.inputs)

      aria =
        Map.new(inputs, fn input ->
          input = to_input(input)
          {to_string(input.name), contract(input, action_id, presentation)}
        end)

      {:ok, aria}
    end
  end

  @doc """
  Builds the section output and mounts it at `schema.aria`, returning the schema.
  """
  @spec mount(IR.Schema.t(), map() | nil) :: {:ok, IR.Schema.t()} | {:error, term()}
  def mount(%IR.Schema{} = schema, presentation \\ nil) do
    with {:ok, aria} <- build(schema, presentation) do
      {:ok, %IR.Schema{schema | aria: aria}}
    end
  end

  @doc """
  The conservative type-to-role table, as data:

      string, ci_string -> "textbox" (free text)
      boolean           -> "checkbox" (independent state)
      enum              -> "switch" (fixed, enumerable state set)
      integer           -> "slider" (ordinal numeric input)

  Every other resolved type kind maps to `nil` — a missing hint is honest data;
  an invented one would be a fabrication. An `Ash.Info.Manifest.Type` whose
  `:kind` is `nil`/unknown is treated as unmapped.
  """
  @spec role_for_type(Type.t() | atom() | nil) :: String.t() | nil
  def role_for_type(%Type{kind: kind}) when is_atom(kind), do: Map.get(@role_table, kind)
  def role_for_type(kind) when is_atom(kind), do: Map.get(@role_table, kind)
  def role_for_type(_), do: nil

  @doc """
  The stable `aria-describedby` target id for an input: derived purely from the
  action id and the input name, so the same input of the same action always
  resolves to the same id (and distinct actions never collide). Characters
  outside `[A-Za-z0-9_-]` are folded to `-` so the id is a usable element id.
  """
  @spec describedby_id(String.t() | atom(), atom() | String.t()) :: String.t()
  def describedby_id(action_id, input_name) do
    "#{slugify(action_id)}-#{slugify(input_name)}-description"
  end

  defp contract(input, action_id, presentation) do
    %{
      "role" => role_for_type(input.type),
      "required" => input.allow_nil? == false,
      "label" => presentation_label(presentation, input.name),
      "describedby" =>
        if is_binary(input.description) and input.description != "" do
          describedby_id(action_id, input.name)
        else
          nil
        end
    }
  end

  defp to_input(input) do
    %IR.Input{
      name: Map.get(input, :name),
      type: Map.get(input, :type),
      allow_nil?: Map.get(input, :allow_nil?),
      description: Map.get(input, :description)
    }
  end

  defp action_id(action_id) when is_binary(action_id), do: {:ok, action_id}

  defp action_id(action_id) when is_atom(action_id) and not is_nil(action_id),
    do: {:ok, to_string(action_id)}

  defp action_id(_), do: {:error, :missing_action_id}

  defp normalize_presentation(nil), do: {:ok, %{}}

  defp normalize_presentation(presentation) when is_map(presentation) do
    case Map.get(presentation, :inputs) || Map.get(presentation, "inputs") do
      nil -> {:ok, normalize_keys(presentation)}
      inputs when is_map(inputs) -> {:ok, normalize_keys(inputs)}
      _ -> {:error, {:invalid_presentation, presentation}}
    end
  end

  defp normalize_presentation(other), do: {:error, {:invalid_presentation, other}}

  defp normalize_keys(map) do
    Map.new(map, fn {key, value} -> {to_string(key), value} end)
  end

  defp presentation_label(presentation, name) do
    case Map.get(presentation, to_string(name)) do
      entry when is_map(entry) ->
        case Map.get(entry, :label) || Map.get(entry, "label") do
          label when is_binary(label) -> label
          _ -> nil
        end

      label when is_binary(label) ->
        label

      _ ->
        nil
    end
  end

  defp slugify(value) do
    value
    |> to_string()
    |> String.replace(~r/[^A-Za-z0-9_-]/, "-")
  end
end
