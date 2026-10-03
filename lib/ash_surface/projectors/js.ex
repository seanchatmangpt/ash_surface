defmodule AshSurface.Projectors.JS do
  @moduledoc """
  JSDoc + Zod client projector over the canonical `AshSurface.IR`.

  `project_ir/2` emits ONE `.mjs` artifact (default prefix
  `ash_surface_client`) exporting:

  - JSDoc-typed resource namespaces of action descriptors,
  - Zod boundary schemas, embedded verbatim from the admitted
    `IR.Schema.zod` strings,
  - action descriptors where DO-boundary actions carry dispatch-INTENT
    descriptors only: `dispatchIntent/2` mints frozen data and there is no
    invoke/dispatch execution path anywhere in the artifact.

  The projection is byte-deterministic: entries are id-sorted, namespaces
  resource-sorted, and descriptor field order is fixed.

  ## Admission (fail-closed)

  Resource short names become top-level `export const` bindings and action
  names become object members, so `project_ir/2` refuses — with
  `{:error, reason}` and no artifact — any input that would emit broken or
  silently-wrong JavaScript:

  - `{:not_an_ir, term}` — an element that is not `%AshSurface.IR{}`;
  - `{:unsafe_js_namespace, name}` — a resource short name that is not an
    ASCII JS identifier, is a reserved word, shadows an ECMAScript global
    (`Object`, `Error`, ...), or is a binding the artifact itself declares
    (`z`, `ACTIONS`, `SCHEMAS`, `NAMESPACES`, `getAction`, `dispatchIntent`);
  - `{:unsafe_js_member, id}` — an action name that is not an ASCII JS
    identifier, or is `__proto__`;
  - `{:js_namespace_collision, short_name, [resource]}` — two distinct
    resources sharing one short name (`MyApp.Blog.Post` and
    `MyApp.Forum.Post` would merge into one `Post` namespace);
  - `{:duplicate_js_member, id}` — the same action id projected twice;
  - `{:js_binding_collision, name}` — two top-level bindings (schema
    constants or namespaces) with the same name;
  - `{:invalid_prefix, prefix}` — the `:prefix` option is not a non-empty string;
  - `{:unadmitted_field, id, field}` — a descriptor field (`label`,
    `capability_iri`, `authority_boundary`, ...) is neither a string nor nil;
  - `{:unadmitted_zod, id, reason}` — an `IR.Schema.zod` string outside the
    `AshSurface.Projectors.JS.ZodGuard` grammar (the zod string is embedded
    as code, so decoded IR must not smuggle arbitrary JavaScript).

  Text interpolated into comments has `*/` neutralized.
  """

  @behaviour AshSurface.Projector.IR

  alias AshSurface.Projector.IREntry
  alias AshSurface.Projectors.JS.ZodGuard

  @identifier ~r/\A[A-Za-z_$][A-Za-z0-9_$]*\z/

  # ECMAScript reserved words (incl. strict-mode and module-goal ones) plus
  # the strict-mode-unbindable `arguments`/`eval`.
  @reserved_words ~w(
    await break case catch class const continue debugger default delete do
    else enum export extends false finally for function if implements import
    in instanceof interface let new null package private protected public
    return static super switch this throw true try typeof var void while
    with yield arguments eval
  )

  # ECMAScript standard global bindings. A module-level `export const Object`
  # shadows the global for the whole module (TDZ ReferenceError at
  # `Object.freeze`; `Error` breaks `dispatchIntent`), so every standard
  # global is refused, not only the ones this artifact reads today.
  @globals ~w(
    globalThis Infinity NaN undefined Object Function Array Number Boolean
    String Symbol BigInt Date Promise RegExp Error AggregateError EvalError
    RangeError ReferenceError SyntaxError TypeError URIError JSON Math Intl
    Reflect Proxy Map Set WeakMap WeakSet WeakRef FinalizationRegistry
    ArrayBuffer SharedArrayBuffer DataView Atomics Int8Array Uint8Array
    Uint8ClampedArray Int16Array Uint16Array Int32Array Uint32Array
    Float32Array Float64Array BigInt64Array BigUint64Array Iterator
    parseInt parseFloat isNaN isFinite decodeURI decodeURIComponent
    encodeURI encodeURIComponent escape unescape
  )

  # Top-level bindings this artifact declares itself.
  @artifact_bindings ~w(z ACTIONS SCHEMAS NAMESPACES getAction dispatchIntent)

  @calver "26.10.1"
  @default_prefix "ash_surface_client"

  @doc """
  Projects one IR (or a list of IRs) into a single JSDoc + Zod `.mjs` client
  artifact.

  Options:

  - `:prefix` — artifact filename prefix (default `#{@default_prefix}`);
    the sole emitted file is `#{String.replace_suffix(@default_prefix, "", ".mjs")}`.
  - `:target_dir` — when set, the artifact is also written there.

  Returns `{:ok, artifacts, meta}` where `artifacts` has exactly one entry and
  `meta` carries `:prefix`, `:action_count`, and `:namespace_count`, or
  `{:error, reason}` (see "Admission") with nothing rendered or written.
  """
  @impl true
  @spec project_ir(AshSurface.Projector.IR.input(), keyword()) ::
          {:ok, %{optional(String.t()) => String.t()}, map()} | {:error, term()}
  def project_ir(ir, opts \\ []) do
    with :ok <- check_prefix(Keyword.get(opts, :prefix, @default_prefix)),
         {:ok, entries, zod_forms} <- admit(List.wrap(ir)) do
      emit(entries, zod_forms, opts)
    end
  end

  # The prefix names the artifact file and is echoed into its header.
  defp check_prefix(prefix) when is_binary(prefix) and prefix != "", do: :ok
  defp check_prefix(prefix), do: {:error, {:invalid_prefix, prefix}}

  defp emit(entries, zod_forms, opts) do
    prefix = Keyword.get(opts, :prefix, @default_prefix)
    code = render(entries, zod_forms, prefix)
    filename = prefix <> ".mjs"

    case Keyword.get(opts, :target_dir) do
      nil ->
        :ok

      target_dir ->
        File.mkdir_p!(target_dir)
        File.write!(Path.join(target_dir, filename), code)
    end

    {:ok, %{filename => code},
     %{
       prefix: prefix,
       action_count: length(entries),
       namespace_count: entries |> Enum.map(& &1.resource) |> Enum.uniq() |> length()
     }}
  end

  ## Admission

  defp admit(irs) do
    with {:ok, pairs} <- describe_all(irs),
         entries = pairs |> Enum.map(&elem(&1, 0)) |> Enum.sort_by(& &1.id),
         :ok <- check_each(entries, &check_fields/1),
         :ok <- check_each(entries, &check_namespace/1),
         :ok <- check_each(entries, &check_member/1),
         :ok <- check_short_names(pairs),
         :ok <- check_duplicate_ids(entries),
         {:ok, entries, zod_forms} <- admit_zod(entries),
         :ok <- check_bindings(entries) do
      {:ok, entries, zod_forms}
    end
  end

  defp describe_all(irs) do
    Enum.reduce_while(irs, {:ok, []}, fn
      %AshSurface.IR{} = ir, {:ok, acc} ->
        case AshSurface.IR.Codec.validate_facts(ir) do
          :ok -> {:cont, {:ok, [{IREntry.describe(ir), full_resource(ir)} | acc]}}
          {:error, _} = error -> {:halt, error}
        end

      other, _acc ->
        {:halt, {:error, {:not_an_ir, other}}}
    end)
  end

  defp full_resource(%AshSurface.IR{ash: %{resource: resource}}) when is_atom(resource),
    do: resource |> to_string() |> String.replace_prefix("Elixir.", "")

  defp full_resource(%AshSurface.IR{ash: %{resource: resource}}), do: resource
  defp full_resource(%AshSurface.IR{}), do: nil

  defp check_each(entries, check) do
    Enum.find_value(entries, :ok, fn entry ->
      case check.(entry) do
        :ok -> nil
        error -> error
      end
    end)
  end

  # Decoded or hand-built IR can carry any term in a descriptor field; each is
  # rendered through js_string/1, which admits only strings and nil. Refuse
  # anything else typed rather than raise mid-render.
  @string_fields ~w(id resource action action_type authority_boundary capability_iri label)a

  defp check_fields(%IREntry{} = entry) do
    Enum.find_value(@string_fields, :ok, fn field ->
      value = Map.fetch!(entry, field)

      if is_nil(value) or is_binary(value),
        do: nil,
        else: {:error, {:unadmitted_field, entry.id, field}}
    end)
  end

  defp check_namespace(%IREntry{resource: name}) do
    if safe_binding?(name), do: :ok, else: {:error, {:unsafe_js_namespace, name}}
  end

  # Members are property keys, where reserved words are legal
  # (`Post.delete`); only non-identifiers and the prototype-setting
  # `__proto__` key are refused.
  defp check_member(%IREntry{action: action, id: id}) do
    if Regex.match?(@identifier, action) and action != "__proto__",
      do: :ok,
      else: {:error, {:unsafe_js_member, id}}
  end

  defp safe_binding?(name) do
    Regex.match?(@identifier, name) and name not in @reserved_words and
      name not in @globals and name not in @artifact_bindings
  end

  defp check_short_names(pairs) do
    pairs
    |> Enum.group_by(fn {entry, _full} -> entry.resource end, &elem(&1, 1))
    |> Enum.map(fn {short, fulls} -> {short, fulls |> Enum.uniq() |> Enum.sort()} end)
    |> Enum.sort()
    |> Enum.find_value(:ok, fn
      {_short, [_one]} -> nil
      {short, many} -> {:error, {:js_namespace_collision, short, many}}
    end)
  end

  defp check_duplicate_ids(entries) do
    entries
    |> Enum.map(& &1.id)
    |> Enum.frequencies()
    |> Enum.sort()
    |> Enum.find_value(:ok, fn
      {_id, 1} -> nil
      {id, _} -> {:error, {:duplicate_js_member, id}}
    end)
  end

  # Replaces each entry's zod with its admitted embeddable expression and
  # returns the admitted form per id (`:expression` embeds byte-verbatim;
  # `:program` embeds the compiled program's input-schema expression).
  defp admit_zod(entries) do
    Enum.reduce_while(entries, {:ok, []}, fn
      %IREntry{zod: nil} = entry, {:ok, acc} ->
        {:cont, {:ok, [{entry, nil} | acc]}}

      %IREntry{zod: zod} = entry, {:ok, acc} ->
        case ZodGuard.admit(zod) do
          {:ok, form, expr} -> {:cont, {:ok, [{%{entry | zod: expr}, form} | acc]}}
          {:error, reason} -> {:halt, {:error, {:unadmitted_zod, entry.id, reason}}}
        end
    end)
    |> case do
      {:ok, acc} ->
        forms = Map.new(acc, fn {entry, form} -> {entry.id, form} end)
        {:ok, acc |> Enum.map(&elem(&1, 0)) |> Enum.reverse(), forms}

      error ->
        error
    end
  end

  defp check_bindings(entries) do
    schema_consts = entries |> Enum.filter(& &1.zod) |> Enum.map(&schema_const/1)
    namespaces = entries |> Enum.map(& &1.resource) |> Enum.uniq()

    (schema_consts ++ namespaces ++ @artifact_bindings)
    |> Enum.frequencies()
    |> Enum.sort()
    |> Enum.find_value(:ok, fn
      {_name, 1} -> nil
      {name, _} -> {:error, {:js_binding_collision, name}}
    end)
  end

  ## Rendering

  defp render(entries, zod_forms, prefix) do
    [
      header(prefix),
      schema_consts(entries, zod_forms),
      namespaces(entries),
      registries(entries)
    ]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
    |> Kernel.<>("\n")
  end

  defp header(prefix) do
    """
    // @generated by AshSurface.Projectors.JS (CalVer #{@calver}); prefix #{line_comment_string(prefix)}
    // Do not edit directly; change the admitted IR sources, then re-project.
    // Law: pi_JS(IR) = JavaScript + JSDoc + Zod. TypeScript-free, no build step.
    // DO-boundary actions project dispatch-INTENT descriptors only: an intent
    // is data and carries no execution authority; this artifact contains no
    // invoke/dispatch execution path.

    import { z } from "zod";

    /**
     * A dispatch intent for a DO-boundary action. DATA ONLY: minting an
     * intent never executes the action. Execution requires a separately
     * admitted, brokered, receipt-bearing dispatch path.
     * @typedef {Object} DispatchIntent
     * @property {"DISPATCH_INTENT"} kind
     * @property {string} actionId
     * @property {Record<string, unknown>} input - boundary-validated by the action Zod schema when present
     */\
    """
  end

  defp schema_consts(entries, zod_forms) do
    entries
    |> Enum.filter(& &1.zod)
    |> Enum.map(fn entry ->
      """
      /** Zod boundary schema for `#{comment(entry.id)}` (#{zod_provenance(zod_forms[entry.id])}). */
      export const #{schema_const(entry)} = #{entry.zod};\
      """
    end)
    |> Enum.join("\n\n")
  end

  defp namespaces(entries) do
    entries
    |> Enum.group_by(& &1.resource)
    |> Enum.sort_by(fn {resource, _} -> resource end)
    |> Enum.map(fn {resource, group} -> namespace_block(resource, group) end)
    |> Enum.join("\n\n")
  end

  defp namespace_block(resource, group) do
    member_docs =
      group
      |> Enum.map(fn entry ->
        " * @property {Object} #{entry.action} - `#{comment(entry.id)}` (authorityBoundary: #{boundary_doc(entry)}, descriptorKind: \"#{descriptor_kind(entry)}\")"
      end)
      |> Enum.join("\n")

    members =
      group
      |> Enum.map(fn entry ->
        """
        #{indent(2)}/** `#{comment(entry.id)}` — #{boundary_doc(entry)}; #{intent_doc(entry)}. */
        #{indent(2)}#{entry.action}: #{descriptor(entry)}\
        """
      end)
      |> Enum.join(",\n")

    """
    /**
     * JSDoc-typed namespace for resource `#{comment(resource)}` (#{length(group)} #{pluralize(length(group), "action")}: #{group |> Enum.map_join(", ", & &1.action) |> comment()}).
     * @typedef {Object} #{resource}Namespace
    #{member_docs}
     */
    export const #{resource} = Object.freeze({
    #{members}
    });\
    """
  end

  defp descriptor(entry) do
    fields = [
      "id: #{js_string(entry.id)}",
      "resource: #{js_string(entry.resource)}",
      "action: #{js_string(entry.action)}",
      "actionType: #{js_string(entry.action_type)}",
      "authorityBoundary: #{js_string(entry.authority_boundary)}",
      "receiptRequired: #{entry.receipt_required}",
      "descriptorKind: #{js_string(descriptor_kind(entry))}",
      "capabilityIri: #{js_string(entry.capability_iri)}",
      "label: #{js_string(entry.label)}",
      "schema: #{schema_ref(entry)}"
    ]

    fields_body = Enum.map_join(fields, ",\n", &(indent(4) <> &1))

    "Object.freeze({\n" <> fields_body <> "\n" <> indent(2) <> "})"
  end

  defp registries(entries) do
    """
    /**
     * Every action descriptor, sorted by id. DO-boundary descriptors carry
     * descriptorKind "DISPATCH_INTENT"; every other descriptor is a plain
     * "DESCRIPTOR". Members are the namespace objects themselves, so
     * descriptor identity is shared.
     */
    export const ACTIONS = Object.freeze([
    #{Enum.map_join(entries, ",\n", &(indent(2) <> member_ref(&1)))}
    ]);

    /** Zod boundary schemas by action id, present only where the IR delegated one. */
    export const SCHEMAS = Object.freeze({
    #{schema_registry(entries)}
    });

    /** Resource namespaces, sorted by resource name. */
    export const NAMESPACES = Object.freeze({
    #{namespace_registry(entries)}
    });

    /** Descriptor lookup by action id; null when unknown. */
    export function getAction(id) {
      return ACTIONS.find((a) => a.id === id) ?? null;
    }

    /**
     * Mints a dispatch INTENT for a DO-boundary action. Refused for unknown
     * actions and for any action whose delegated boundary is not exactly
     * "DO". Input is boundary-validated by the action's Zod schema when the
     * IR delegated one. Never executes anything.
     * @param {string} id
     * @param {Record<string, unknown>} input
     * @returns {DispatchIntent}
     */
    export function dispatchIntent(id, input) {
      const action = getAction(id);
      if (action === null) {
        throw new Error("REFUSED_UNKNOWN_ACTION: " + id);
      }
      if (action.descriptorKind !== "DISPATCH_INTENT") {
        throw new Error("REFUSED_NOT_DO_BOUNDARY: " + id + " has descriptorKind " + action.descriptorKind);
      }
      const parsed = action.schema ? action.schema.parse(input) : input;
      return Object.freeze({ kind: "DISPATCH_INTENT", actionId: id, input: parsed });
    }\
    """
  end

  defp schema_registry(entries) do
    entries
    |> Enum.filter(& &1.zod)
    |> Enum.map(&(indent(2) <> "#{js_string(&1.id)}: #{schema_const(&1)}"))
    |> Enum.join(",\n")
  end

  defp namespace_registry(entries) do
    entries
    |> Enum.map(& &1.resource)
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.map(&(indent(2) <> &1))
    |> Enum.join(",\n")
  end

  defp member_ref(entry), do: "#{entry.resource}.#{entry.action}"
  defp schema_const(entry), do: "#{sanitize(entry.id)}_schema"
  defp schema_ref(%{zod: nil}), do: "null"
  defp schema_ref(entry), do: schema_const(entry)

  defp descriptor_kind(entry),
    do: if(IREntry.do_boundary?(entry), do: "DISPATCH_INTENT", else: "DESCRIPTOR")

  defp boundary_doc(%{authority_boundary: nil}), do: "not delegated"
  defp boundary_doc(entry), do: "\"#{comment(entry.authority_boundary)}\""

  defp intent_doc(entry) do
    if IREntry.do_boundary?(entry) do
      "dispatch-intent only"
    else
      "no dispatch intent"
    end
  end

  defp zod_provenance(:program), do: "input schema of the compiled IR.Schema.zod program"
  defp zod_provenance(:expression), do: "IR.Schema.zod, verbatim"

  # Block-comment content: `*/` would close the comment and turn the rest of
  # the text into code, so it is neutralized as `*\/`. Identity for every
  # string that does not contain `*/`.
  defp comment(text), do: String.replace(text, "*/", "*\\/")

  # A `//` comment ends at any line terminator; JSON-encode with the
  # javascript_safe escape so U+2028/U+2029 are escaped too (identity for
  # every prefix without them).
  defp line_comment_string(value), do: Jason.encode!(value, escape: :javascript_safe)

  defp sanitize(name), do: String.replace(name, ~r/[^A-Za-z0-9_$]/, "_")

  defp js_string(nil), do: "null"
  defp js_string(value) when is_binary(value), do: Jason.encode!(value)
  defp js_string(value) when is_boolean(value), do: to_string(value)

  defp indent(n), do: String.duplicate(" ", n)

  defp pluralize(1, word), do: word
  defp pluralize(n, word) when n > 1, do: word <> "s"
end
