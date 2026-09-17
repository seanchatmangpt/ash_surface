defmodule AshSurface.Projectors.ARIA do
  @moduledoc """
  Accessibility projector over the canonical `AshSurface.IR`.

  `project_ir/2` projects the delegated aria and presentation facts into an
  ARIA contract map, with optional `.json` emission. The contract carries
  semantics, never rendering: no markup, styles, scripts, or component trees
  are produced.

  Sources, read and never derived:

  - `IR.Schema.aria` — the sole per-input aria carrier. Atom and string keys
    are tolerated so in-memory and round-tripped manifests feed the same
    read path. Shape: optional `"role"` (surface role), optional `"live"`
    (live-region politeness; OBSERVE-only admission), and inputs either
    under `"inputs"` (a list of input maps or a name-keyed map) or as the
    remaining name-keyed map entries. Per-input facts: `"role"`,
    `"required"`, `"describedby"`.
  - `IR.Presentation` — `label` (surface label), `group` (grouping fact),
    `order` (tab order fact).

  Laws:

  > **Live regions are OBSERVE-only.** A surface whose delegated authority
  > boundary is exactly "OBSERVE" carries a live-region hint: the delegated
  > politeness when one was stored, otherwise "polite". Every other surface
  > carries no live fact at all — a delegated politeness on a non-OBSERVE
  > surface is dropped, never honored.

  > **Ordering is law.** Surfaces are id-sorted; name-keyed inputs are
  > name-sorted; groups are id-sorted; `tabOrder` sorts by the delegated
  > presentation order (nil last) with the surface id as tie-break; input
  > `tabIndex` is sequential from 1 in input order. The projection is
  > byte-deterministic for the same admitted facts.

  > **Facts are read, never inferred.** Absent optional facts project as
  > `nil`/`false`; no surface role, label, or requirement is guessed from an
  > action type, widget, or default. An invalid delegated politeness or an
  > unnamed list-form input raises — the shape is law, not a suggestion.
  """

  alias AshSurface.IR
  alias AshSurface.Projector.IREntry

  @calver "26.9.16"
  @default_prefix "ash_surface_aria"
  @politeness ~w(polite assertive off)
  @reserved ~w(inputs live role)

  @doc """
  Projects one IR (or a list of IRs) into the ARIA contract map.

  Options:

  - `:prefix` — emitted filename prefix (default `#{@default_prefix}`); the
    emitted file is `<prefix>.json`.
  - `:target_dir` — when set, the contract is also emitted there as compact
    JSON.

  Returns `{:ok, contract, meta}` where `meta` carries `:prefix`,
  `:surface_count`, `:group_count`, and `:emitted` (the written filename, or
  `nil` when nothing was written).
  """
  @spec project_ir(IR.t() | [IR.t()], keyword()) :: {:ok, map(), map()}
  def project_ir(ir, opts \\ []) do
    prefix = Keyword.get(opts, :prefix, @default_prefix)
    irs = List.wrap(ir)
    contract = contract(irs)
    filename = prefix <> ".json"

    emitted =
      case Keyword.get(opts, :target_dir) do
        nil ->
          nil

        target_dir ->
          bytes = to_json(contract)
          File.mkdir_p!(target_dir)
          File.write!(Path.join(target_dir, filename), bytes)
          filename
      end

    {:ok, contract,
     %{
       prefix: prefix,
       surface_count: length(contract["surfaces"]),
       group_count: length(contract["groups"]),
       emitted: emitted
     }}
  end

  @doc """
  Pure map projection of the ARIA contract: labelled groups, per-input
  role/required/aria-describedby with sequential `tabIndex`, the surface
  tab order, and live-region hints on OBSERVE surfaces only.
  """
  @spec contract(IR.t() | [IR.t()]) :: map()
  def contract(ir_or_irs) do
    irs = List.wrap(ir_or_irs)

    surfaces =
      irs
      |> Enum.map(&surface/1)
      |> Enum.sort_by(& &1["id"])

    %{
      "contract" => "aria",
      "version" => @calver,
      "surfaces" => surfaces,
      "groups" => groups(surfaces),
      "tabOrder" => tab_order(irs)
    }
  end

  @doc """
  Byte-deterministic compact JSON rendering of the contract.
  """
  @spec to_json(map()) :: String.t()
  def to_json(contract), do: Jason.encode!(contract)

  defp surface(%IR{} = ir) do
    entry = IREntry.describe(ir)
    presentation = ir.presentation || %IR.Presentation{}
    aria = (ir.schema || %IR.Schema{}).aria

    base = %{
      "id" => entry.id,
      "resource" => entry.resource,
      "action" => entry.action,
      "label" => entry.label,
      "group" => presentation.group,
      "role" => fact(aria, "role"),
      "inputs" =>
        aria
        |> inputs()
        |> Enum.with_index(1)
        |> Enum.map(fn {input, tab_index} -> Map.put(input, "tabIndex", tab_index) end)
    }

    Map.merge(base, live_hint(ir, aria))
  end

  # Live-region hints are OBSERVE-only: the delegated politeness is admitted
  # (defaulting to "polite") exactly when the delegated boundary is OBSERVE,
  # and is dropped for every other surface, delegated or not.
  defp live_hint(%IR{} = ir, aria) do
    if observe?(ir) do
      %{"live" => politeness(fact(aria, "live"))}
    else
      %{}
    end
  end

  defp observe?(%IR{} = ir), do: IREntry.authority_boundary(ir) == "OBSERVE"

  defp politeness(nil), do: "polite"

  defp politeness(delegated) do
    downcased = delegated |> to_string() |> String.downcase()

    if downcased in @politeness do
      downcased
    else
      raise ArgumentError,
            "invalid delegated live politeness #{inspect(delegated)}; " <>
              "expected one of #{inspect(@politeness)}"
    end
  end

  defp inputs(nil), do: []

  defp inputs(aria) when is_map(aria) do
    case fact(aria, "inputs") do
      nil ->
        name_keyed_inputs(aria)

      entries when is_list(entries) ->
        Enum.map(entries, &list_form_input/1)

      entries when is_map(entries) ->
        name_keyed_inputs(entries)
    end
  end

  defp name_keyed_inputs(map) do
    map
    |> Enum.reject(fn {key, value} -> reserved?(key) or not is_map(value) end)
    |> Enum.map(fn {name, input_facts} -> input(to_string(name), input_facts) end)
    |> Enum.sort_by(& &1["name"])
  end

  defp list_form_input(%{} = entry) do
    case fact(entry, "name") || fact(entry, "field") do
      nil ->
        raise ArgumentError,
              "unnamed list-form aria input #{inspect(entry)}; " <>
                "every input carries a \"name\" (or \"field\") fact"

      name ->
        input(to_string(name), entry)
    end
  end

  defp list_form_input(entry) do
    raise ArgumentError, "list-form aria inputs must be maps, got #{inspect(entry)}"
  end

  defp input(name, input_facts) do
    %{
      "name" => name,
      "role" => fact(input_facts, "role"),
      "required" => fact(input_facts, "required") == true,
      "aria-describedby" => fact(input_facts, "describedby")
    }
  end

  defp groups(surfaces) do
    surfaces
    |> Enum.filter(& &1["group"])
    |> Enum.group_by(& &1["group"])
    |> Enum.sort_by(fn {group, _} -> group end)
    |> Enum.map(fn {group, members} ->
      %{
        "id" => group,
        "label" => group,
        "role" => "group",
        "members" => Enum.map(members, & &1["id"])
      }
    end)
  end

  # Tab order from the delegated presentation order: nil sorts last, the
  # surface id breaks ties. Never derived from position or action type.
  defp tab_order(irs) do
    irs
    |> Enum.map(fn ir ->
      order = (ir.presentation || %IR.Presentation{}).order
      {order_rank(order), entry_id(ir)}
    end)
    |> Enum.sort()
    |> Enum.map(&elem(&1, 1))
  end

  defp order_rank(nil), do: {1, 0}
  defp order_rank(order) when is_integer(order) and order >= 0, do: {0, order}

  defp entry_id(ir), do: IREntry.describe(ir).id

  defp reserved?(key), do: to_string(key) in @reserved

  defp fact(nil, _fact_name), do: nil

  defp fact(%{} = map, fact_name) do
    Enum.find_value(map, fn
      {key, value} when is_atom(key) or is_binary(key) ->
        if to_string(key) == fact_name, do: value

      _ ->
        nil
    end)
  end
end
