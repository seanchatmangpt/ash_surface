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
  - `{:invalid_namespace_prefix, value}` — the `:namespace_prefix` option is set
    but is not a non-empty string;
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
  @artifact_bindings ~w(z ACTIONS SCHEMAS QUERY_SCHEMAS NAMESPACES getAction dispatchIntent)

  @calver "26.10.8"
  @default_prefix "ash_surface_client"

  @doc """
  Projects one IR (or a list of IRs) into a single JSDoc + Zod `.mjs` client
  artifact.

  Options:

  - `:prefix` — artifact filename prefix (default `#{@default_prefix}`);
    the sole emitted file is `#{String.replace_suffix(@default_prefix, "", ".mjs")}`.
  - `:namespace_prefix` — when set to a non-empty string, every resource
    namespace binding is emitted as `namespace_prefix <> short_name`
    (e.g. `Xaas.Ocel.Object` projects as `XaasObject` instead of the
    refused `Object`). Default `nil`: namespaces are emitted unprefixed and
    built-in-colliding short names are refused as
    `{:unsafe_js_namespace, name}` exactly as before.
  - `:namespace_names` — opt-in explicit namespace bindings keyed by the
    resource's full module name (`"App.Conference.Event" => "AppConfEvent"`),
    for full-app runs where two resources share a short name (e.g. two
    `Event` resources). An override wins over `:namespace_prefix` for that
    resource; overridden names must be safe JS artifacts or the projection
    refuses. Default `%{}`: no overrides applied.
  - `:embedded_filters` — list of embedded resource modules; each is exported as
    `<Short>EmbeddedFilterSchema` (its typed filter, admitted by the guard), sorted by name.
    Default `[]`: no embedded filter exports.
  - `:run_endpoint` / `:validate_endpoint` — when set (absolute-path string, else
    `{:invalid_endpoint, key, value}`), the artifact exports `AshSurfaceEndpoints`
    (`{run, validate}`); unset emits nothing.
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
         ns_prefix = Keyword.get(opts, :namespace_prefix),
         :ok <- check_namespace_prefix(ns_prefix),
         ns_names = Keyword.get(opts, :namespace_names, %{}),
         :ok <- check_namespace_names(ns_names),
         {:ok, entries, zod_forms} <- admit(List.wrap(ir), ns_prefix, ns_names),
         {:ok, embedded} <-
           admit_embedded(
             Keyword.get(opts, :embedded_filters, []),
             entries,
             ns_prefix,
             ns_names,
             zod_forms
           ) do
      emit(entries, zod_forms, embedded, opts)
    end
  end

  # The prefix names the artifact file and is echoed into its header.
  defp check_prefix(prefix) when is_binary(prefix) and prefix != "", do: :ok
  defp check_prefix(prefix), do: {:error, {:invalid_prefix, prefix}}

  defp check_namespace_prefix(nil), do: :ok
  defp check_namespace_prefix(prefix) when is_binary(prefix) and prefix != "", do: :ok

  defp check_namespace_prefix(value), do: {:error, {:invalid_namespace_prefix, value}}

  # Opt-in explicit namespace bindings keyed by the resource's full module
  # name (`"Xaas.Conference.Event" => "XaasConferenceEvent"`). Values must be
  # safe JS bindings; keys/shapes are validated before any admission.
  defp check_namespace_names(names) do
    if is_map(names) and Enum.all?(names, fn {k, v} -> is_binary(k) and is_binary(v) end) do
      Enum.find_value(names, :ok, fn {_k, v} ->
        if safe_binding?(v), do: :ok, else: {:error, {:unsafe_js_namespace, v}}
      end)
    else
      {:error, {:invalid_namespace_names, names}}
    end
  end

  @doc """
  Writes an artifacts map (`filename => content`) under `dir`, returning the
  written paths. Used by `:target_dir` and `mix ash_surface.codegen`.
  """
  @spec write_artifacts(%{optional(String.t()) => String.t()}, Path.t()) :: [Path.t()]
  def write_artifacts(artifacts, dir) do
    File.mkdir_p!(dir)

    artifacts
    |> Enum.sort()
    |> Enum.map(fn {name, content} ->
      path = Path.join(dir, name)
      File.write!(path, content)
      path
    end)
  end

  defp emit(entries, zod_forms, embedded, opts) do
    with {:ok, endpoints} <- check_endpoints(opts) do
      do_emit(entries, zod_forms, embedded, opts, endpoints)
    end
  end

  # `:run_endpoint` / `:validate_endpoint` (nil = not requested, nothing emitted so existing
  # artifact bytes are unchanged). A requested endpoint must be an absolute-path string.
  defp check_endpoints(opts) do
    Enum.reduce_while([:run_endpoint, :validate_endpoint], {:ok, []}, fn key, {:ok, acc} ->
      case Keyword.get(opts, key) do
        nil ->
          {:cont, {:ok, acc}}

        "/" <> _ = value ->
          {:cont, {:ok, [{key, value} | acc]}}

        value ->
          {:halt, {:error, {:invalid_endpoint, key, value}}}
      end
    end)
    |> case do
      {:ok, acc} -> {:ok, Enum.sort(acc)}
      error -> error
    end
  end

  defp do_emit(entries, zod_forms, embedded, opts, endpoints) do
    prefix = Keyword.get(opts, :prefix, @default_prefix)
    ns_prefix = Keyword.get(opts, :namespace_prefix)
    ns_names = Keyword.get(opts, :namespace_names, %{})
    code = render(entries, zod_forms, embedded, prefix, ns_prefix, ns_names, endpoints)
    filename = prefix <> ".mjs"

    artifacts = %{filename => code}

    # Thin wrapper: the codegen task owns writing; `:target_dir` just delegates.
    case Keyword.get(opts, :target_dir) do
      nil -> :ok
      target_dir -> write_artifacts(artifacts, target_dir)
    end

    {:ok, artifacts,
     %{
       prefix: prefix,
       action_count: length(entries),
       namespace_count: entries |> Enum.map(& &1.resource) |> Enum.uniq() |> length()
     }}
  end

  ## Admission

  defp admit(irs, ns_prefix, ns_names) do
    with {:ok, pairs} <- describe_all(irs),
         entries = pairs |> Enum.map(&elem(&1, 0)) |> Enum.sort_by(& &1.id),
         :ok <- check_each(entries, &check_fields/1),
         :ok <- check_each(entries, &check_namespace(&1, ns_prefix, ns_names)),
         :ok <- check_each(entries, &check_member/1),
         :ok <- check_short_names(pairs, ns_prefix, ns_names),
         entries = Enum.map(entries, &disambiguate_id(&1, ns_prefix, ns_names)),
         entries = Enum.sort_by(entries, & &1.id),
         :ok <- check_duplicate_ids(entries),
         {:ok, entries, zod_forms} <- admit_zod(entries),
         :ok <- check_bindings(entries, ns_prefix, ns_names, zod_forms) do
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

  # The JS namespace binding for one entry: an explicit `:namespace_names`
  # override for its full resource name wins; otherwise `ns_name/2`.
  defp bound(%IREntry{} = entry, ns_prefix, ns_names) do
    case entry.full_resource && Map.fetch(ns_names, entry.full_resource) do
      {:ok, name} -> name
      _ -> ns_name(ns_prefix, entry.resource)
    end
  end

  # After namespace disambiguation the artifact-facing action id follows the
  # resolved namespace binding (`XaasOcelEvent.destroy`), so ids stay unique
  # across colliding short names. With no override/prefix (the default), the
  # binding equals the short name and the id is unchanged.
  defp disambiguate_id(%IREntry{} = entry, ns_prefix, ns_names) do
    binding = bound(entry, ns_prefix, ns_names)

    if binding == entry.resource do
      entry
    else
      %{entry | id: "#{binding}.#{entry.action}"}
    end
  end

  defp check_namespace(%IREntry{} = entry, ns_prefix, ns_names) do
    bound = bound(entry, ns_prefix, ns_names)

    if safe_binding?(bound), do: :ok, else: {:error, {:unsafe_js_namespace, bound}}
  end

  # The top-level JS binding a resource's namespace is emitted as. `nil`
  # prefix = the short name itself (default, unchanged); a prefix is
  # concatenated in front of it (`"Xaas" <> "Object"` = `"XaasObject"`).
  defp ns_name(nil, short), do: short
  defp ns_name(ns_prefix, short) when is_binary(ns_prefix), do: ns_prefix <> short

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

  defp check_short_names(pairs, ns_prefix, ns_names) do
    pairs
    |> Enum.group_by(fn {entry, _full} -> bound(entry, ns_prefix, ns_names) end, &elem(&1, 1))
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
    Enum.reduce_while(entries, {:ok, []}, fn entry, {:ok, acc} ->
      with {:ok, form, entry} <- admit_zod_field(entry),
           {:ok, _, entry} <- admit_field(entry, :filter_zod),
           {:ok, _, entry} <- admit_field(entry, :sort_zod),
           {:ok, _, entry} <- admit_field(entry, :page_zod),
           {:ok, _, entry} <- admit_field(entry, :response_zod),
           :ok <- check_flags(entry) do
        {:cont, {:ok, [{entry, form} | acc]}}
      else
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, acc} ->
        forms = Map.new(acc, fn {entry, form} -> {entry.id, form} end)

        with :ok <- check_declarations(forms) do
          {:ok, acc |> Enum.map(&elem(&1, 0)) |> Enum.reverse(), forms}
        end

      error ->
        error
    end
  end

  # The main `zod` slot may be a compiled program with named declarations (KD-02): the
  # declarations are admitted by `ZodGuard.admit/2` (declared-identifier allowlist) and
  # carried beside the form to be emitted once at artifact top level.
  defp admit_zod_field(%IREntry{zod: zod} = entry) when is_binary(zod) do
    decls =
      zod
      |> ZodGuard.declarations()
      |> Enum.map(fn {name, expr} -> {name, embed_regex(expr)} end)

    with {:ok, form, entry} <- admit_field(entry, :zod), do: {:ok, {form, decls}, entry}
  end

  defp admit_zod_field(entry) do
    with {:ok, form, entry} <- admit_field(entry, :zod), do: {:ok, {form, []}, entry}
  end

  defp check_declarations(forms) do
    forms
    |> Map.values()
    |> Enum.flat_map(fn {_form, decls} -> decls end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.sort()
    |> Enum.find_value(:ok, fn {name, bodies} ->
      if length(Enum.uniq(bodies)) > 1, do: {:error, {:declaration_conflict, name}}
    end)
  end

  defp declared_names(zod_forms) do
    zod_forms
    |> Map.values()
    |> Enum.flat_map(fn {_form, decls} -> Enum.map(decls, &elem(&1, 0)) end)
    |> Enum.uniq()
  end

  defp declarations_block(zod_forms) do
    zod_forms
    |> Map.values()
    |> Enum.flat_map(fn {_form, decls} -> decls end)
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.map_join("\n\n", fn {name, expr} -> "const #{name} = #{expr};" end)
  end

  defp admit_field(entry, field) do
    case Map.fetch!(entry, field) do
      nil ->
        {:ok, nil, entry}

      zod ->
        case ZodGuard.admit(zod) do
          {:ok, form, expr} -> {:ok, form, Map.put(entry, field, embed_regex(expr))}
          {:error, reason} -> {:error, {:unadmitted_zod, entry.id, reason}}
        end
    end
  end

  # zod 4 throws at parse on `.regex("string")` (it requires a RegExp). The
  # guard admits only literal arguments, so the string-arg form is converted
  # AFTER admission, at the embed site, to `.regex(new RegExp("..."))`.
  defp embed_regex(expr),
    do: Regex.replace(~r/\.regex\(("(?:[^"\\]|\\.)*")\)/, expr, ".regex(new RegExp(\\1))")

  defp check_flags(%IREntry{capability_flags: nil}), do: :ok

  defp check_flags(%IREntry{capability_flags: flags} = entry) do
    if is_map(flags) and Enum.all?(flags, fn {k, v} -> is_binary(k) and is_boolean(v) end),
      do: :ok,
      else: {:error, {:unadmitted_field, entry.id, :capability_flags}}
  end

  defp check_bindings(entries, ns_prefix, ns_names, zod_forms) do
    schema_consts = Enum.flat_map(entries, fn e -> Enum.map(schema_slots(e), &elem(&1, 1)) end)

    namespaces =
      entries
      |> Enum.map(&bound(&1, ns_prefix, ns_names))
      |> Enum.uniq()

    (schema_consts ++ namespaces ++ @artifact_bindings ++ declared_names(zod_forms))
    |> Enum.frequencies()
    |> Enum.sort()
    |> Enum.find_value(:ok, fn
      {_name, 1} -> nil
      {name, _} -> {:error, {:js_binding_collision, name}}
    end)
  end

  # Embedded-resource filter schemas (`:embedded_filters`, a list of embedded resource modules):
  # each renders `FilterSchema.render_embedded/1` (wire names formatter/field_names-aware), is
  # admitted through ZodGuard, and is exported as `<Short>EmbeddedFilterSchema`, sorted by name.
  defp admit_embedded(mods, entries, ns_prefix, ns_names, zod_forms) when is_list(mods) do
    mods = Enum.uniq(mods)
    shorts = Enum.frequencies_by(mods, &embedded_short/1)

    mods
    |> Enum.reduce_while({:ok, []}, fn mod, {:ok, acc} ->
      with true <- embedded_resource?(mod),
           {:ok, zod} <- AshSurface.Compiler.FilterSchema.render_embedded(mod),
           {:ok, _, expr} <- ZodGuard.admit(zod) do
        short = embedded_stem(mod, ns_names, shorts)
        {:cont, {:ok, [{short <> "EmbeddedFilterSchema", mod, embed_regex(expr)} | acc]}}
      else
        {:error, reason} -> {:halt, {:error, {:unadmitted_embedded_filter, mod, reason}}}
        false -> {:halt, {:error, {:unadmitted_embedded_filter, mod, :not_an_embedded_resource}}}
      end
    end)
    |> case do
      {:ok, acc} ->
        acc = Enum.sort_by(acc, &elem(&1, 0))

        taken =
          Enum.flat_map(entries, fn e -> Enum.map(schema_slots(e), &elem(&1, 1)) end) ++
            Enum.map(entries, &bound(&1, ns_prefix, ns_names)) ++
            @artifact_bindings ++ declared_names(zod_forms)

        names = Enum.map(acc, &elem(&1, 0))

        case Enum.find(names, &(&1 in taken or Enum.count(names, fn n -> n == &1 end) > 1)) do
          nil -> {:ok, acc}
          name -> {:error, {:js_binding_collision, name}}
        end

      error ->
        error
    end
  end

  defp admit_embedded(other, _, _, _, _), do: {:error, {:invalid_embedded_filters, other}}

  defp embedded_short(mod) when is_atom(mod) and not is_nil(mod) do
    if String.starts_with?(Atom.to_string(mod), "Elixir."),
      do: mod |> Module.split() |> List.last() |> sanitize()
  end

  defp embedded_short(_), do: nil

  # Export stem: an explicit `:namespace_names` entry for the module wins; a short name shared by
  # several embedded modules is qualified deterministically by the full module path.
  defp embedded_stem(mod, ns_names, shorts) do
    short = embedded_short(mod)

    case Map.fetch(ns_names, inspect(mod)) do
      {:ok, name} ->
        name

      :error ->
        if Map.get(shorts, short, 0) > 1,
          do: mod |> Module.split() |> Enum.join() |> sanitize(),
          else: short
    end
  end

  defp embedded_resource?(mod) when is_atom(mod) and not is_nil(mod) do
    Code.ensure_loaded?(mod) and function_exported?(mod, :spark_is, 0) and
      Ash.Resource.Info.embedded?(mod)
  end

  defp embedded_resource?(_), do: false

  defp embedded_consts(embedded) do
    Enum.map_join(embedded, "\n\n", fn {name, mod, expr} ->
      """
      /** Zod filter schema for embedded resource `#{comment(inspect(mod))}` (FilterSchema.render_embedded, admitted). */
      export const #{name} = #{expr};\
      """
    end)
  end

  ## Rendering

  defp render(entries, zod_forms, embedded, prefix, ns_prefix, ns_names, endpoints) do
    [
      header(prefix, AshSurface.Config.zod_import_path()),
      declarations_block(zod_forms),
      schema_consts(entries, zod_forms),
      embedded_consts(embedded),
      endpoints_block(endpoints),
      namespaces(entries, ns_prefix, ns_names),
      registries(entries, ns_prefix, ns_names)
    ]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
    |> Kernel.<>("\n")
  end

  defp endpoints_block([]), do: ""

  defp endpoints_block(endpoints) do
    members =
      Enum.map_join(endpoints, ",\n", fn {key, value} ->
        indent(2) <>
          "#{key |> to_string() |> String.replace_suffix("_endpoint", "")}: #{js_string(value)}"
      end)

    """
    /** Endpoints the artifact was generated for (`mix ash_surface.codegen --run-endpoint/--validate-endpoint`). */
    export const AshSurfaceEndpoints = Object.freeze({
    #{members}
    });\
    """
  end

  defp header(prefix, zod_path) do
    """
    // @generated by AshSurface.Projectors.JS (CalVer #{@calver}); prefix #{line_comment_string(prefix)}
    // Do not edit directly; change the admitted IR sources, then re-project.
    // Law: pi_JS(IR) = JavaScript + JSDoc + Zod. TypeScript-free, no build step.
    // DO-boundary actions project dispatch-INTENT descriptors only: an intent
    // is data and carries no execution authority; this artifact contains no
    // invoke/dispatch execution path.

    import { z } from #{js_string(zod_path)};

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
    |> Enum.flat_map(fn entry ->
      Enum.map(schema_slots(entry), fn
        {:zod, const, expr} ->
          """
          /** Zod boundary schema for `#{comment(entry.id)}` (#{zod_provenance(zod_forms[entry.id] |> elem(0))}). */
          export const #{const} = #{expr};\
          """

        {kind, const, expr} ->
          """
          /** Zod #{kind} schema for `#{comment(entry.id)}` (IR.Schema.#{kind}, admitted). */
          export const #{const} = #{expr};\
          """
      end)
    end)
    |> Enum.join("\n\n")
  end

  defp namespaces(entries, ns_prefix, ns_names) do
    entries
    |> Enum.group_by(&bound(&1, ns_prefix, ns_names))
    |> Enum.sort_by(fn {binding, _} -> binding end)
    |> Enum.map(fn {binding, group} -> namespace_block(binding, group) end)
    |> Enum.join("\n\n")
  end

  defp namespace_block(binding, group) do
    resource = hd(group).resource

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
     * @typedef {Object} #{binding}Namespace
    #{member_docs}
     */
    export const #{binding} = Object.freeze({
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
      "schema: #{schema_ref(entry)}",
      "filterSchema: #{slot_ref(entry, :filter)}",
      "sortSchema: #{slot_ref(entry, :sort)}",
      "pageSchema: #{slot_ref(entry, :page)}",
      "responseSchema: #{slot_ref(entry, :response)}",
      "capabilityFlags: #{flags_literal(entry.capability_flags)}"
    ]

    fields_body = Enum.map_join(fields, ",\n", &(indent(4) <> &1))

    "Object.freeze({\n" <> fields_body <> "\n" <> indent(2) <> "})"
  end

  defp registries(entries, ns_prefix, ns_names) do
    """
    /**
     * Every action descriptor, sorted by id. DO-boundary descriptors carry
     * descriptorKind "DISPATCH_INTENT"; every other descriptor is a plain
     * "DESCRIPTOR". Members are the namespace objects themselves, so
     * descriptor identity is shared.
     */
    export const ACTIONS = Object.freeze([
    #{Enum.map_join(entries, ",\n", &(indent(2) <> member_ref(&1, ns_prefix, ns_names)))}
    ]);

    /** Zod boundary schemas by action id, present only where the IR delegated one. */
    export const SCHEMAS = Object.freeze({
    #{schema_registry(entries)}
    });

    /** Query-envelope schemas (filter/sort/page/response) by action id; null where absent. */
    export const QUERY_SCHEMAS = Object.freeze({
    #{query_schema_registry(entries)}
    });

    /** Resource namespaces, sorted by resource name. */
    export const NAMESPACES = Object.freeze({
    #{namespace_registry(entries, ns_prefix, ns_names)}
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
        throw Object.assign(new Error("REFUSED_UNKNOWN_ACTION: " + id), {
          refusal: "REFUSED_UNKNOWN_ACTION",
          standing: "BLOCKED",
          detail: { actionId: id },
        });
      }
      if (action.descriptorKind !== "DISPATCH_INTENT") {
        throw Object.assign(new Error("REFUSED_NOT_DO_BOUNDARY: " + id + " has descriptorKind " + action.descriptorKind), {
          refusal: "REFUSED_NOT_DO_BOUNDARY",
          standing: "BLOCKED",
          detail: { actionId: id, descriptorKind: action.descriptorKind },
        });
      }
      if (action.schema) {
        const result = action.schema.safeParse(input);
        if (!result.success) {
          const err = new Error("INPUT_VALIDATION_FAILED: " + id);
          err.name = "SurfaceRuntimeError";
          err.code = "INPUT_VALIDATION_FAILED";
          err.refusal = null;
          err.standing = "BLOCKED";
          err.issues = result.error.issues.map((i) => ({
            path: i.path.join("."),
            message: i.message,
            code: i.code,
          }));
          err.detail = { actionId: id, issues: err.issues };
          throw err;
        }
        input = result.data;
      }
      return Object.freeze({ kind: "DISPATCH_INTENT", actionId: id, input: input });
    }\
    """
  end

  defp schema_registry(entries) do
    entries
    |> Enum.filter(& &1.zod)
    |> Enum.map(&(indent(2) <> "#{js_string(&1.id)}: #{schema_const(&1)}"))
    |> Enum.join(",\n")
  end

  defp namespace_registry(entries, ns_prefix, ns_names) do
    entries
    |> Enum.uniq_by(& &1.resource)
    |> Enum.sort_by(& &1.resource)
    |> Enum.map(&bound(&1, ns_prefix, ns_names))
    |> Enum.map(&(indent(2) <> &1))
    |> Enum.join(",\n")
  end

  defp member_ref(entry, ns_prefix, ns_names),
    do: "#{bound(entry, ns_prefix, ns_names)}.#{entry.action}"

  defp schema_const(entry), do: "#{sanitize(entry.id)}_schema"

  # {kind, const_name, admitted_expr} for every schema the entry carries.
  defp schema_slots(entry) do
    [
      {:zod, schema_const(entry), entry.zod},
      {:filter, "#{sanitize(entry.id)}_filter_schema", entry.filter_zod},
      {:sort, "#{sanitize(entry.id)}_sort_schema", entry.sort_zod},
      {:page, "#{sanitize(entry.id)}_page_schema", entry.page_zod},
      {:response, "#{sanitize(entry.id)}_response_schema", entry.response_zod}
    ]
    |> Enum.reject(fn {_, _, expr} -> is_nil(expr) end)
  end

  defp slot_ref(entry, kind) do
    case Enum.find(schema_slots(entry), &(elem(&1, 0) == kind)) do
      nil -> "null"
      {_, const, _} -> const
    end
  end

  defp flags_literal(nil), do: "null"

  defp flags_literal(flags) do
    body = flags |> Enum.sort() |> Enum.map_join(", ", fn {k, v} -> "#{js_string(k)}: #{v}" end)
    "Object.freeze({#{body}})"
  end

  defp query_schema_registry(entries) do
    entries
    |> Enum.filter(&Enum.any?(schema_slots(&1), fn {k, _, _} -> k != :zod end))
    |> Enum.map(fn e ->
      members =
        [:filter, :sort, :page, :response]
        |> Enum.map_join(", ", fn k -> "#{k}: #{slot_ref(e, k)}" end)

      indent(2) <> "#{js_string(e.id)}: Object.freeze({#{members}})"
    end)
    |> Enum.join(",\n")
  end

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
