defmodule AshSurface.IR do
  @moduledoc """
  The intermediate representation one public Ash action compiles to.

  `AshSurface.Compiler` (this directory's `compiler.ex`) manufactures one
  `%AshSurface.IR{}` per discovered public action. The IR is a five-section
  record: every field except `version` and `digest` is owned by one section
  builder (`AshSurface.Compiler.Section` implementations), so the compiler
  itself owns only orchestration, the single discovery pass, and the digest.
  """

  @enforce_keys [:version, :digest, :ash, :semantic, :capability, :presentation, :schema]
  defstruct [:version, :digest, :ash, :semantic, :capability, :presentation, :schema]

  @type t :: %__MODULE__{
          version: String.t(),
          digest: String.t(),
          ash: Ash.t(),
          semantic: Semantic.t(),
          capability: Capability.t(),
          presentation: Presentation.t(),
          schema: Schema.t()
        }

  defmodule Ash do
    @moduledoc "The Ash fact of the action, straight from the normalized action map."
    @enforce_keys [:resource, :action, :action_type, :inputs, :outputs, :policies]
    defstruct [:resource, :action, :action_type, :inputs, :outputs, :policies]

    @type t :: %__MODULE__{
            resource: atom() | String.t(),
            action: atom() | String.t(),
            action_type: atom(),
            inputs: term(),
            outputs: term(),
            policies: term()
          }
  end

  defmodule Semantic do
    @moduledoc "The semantic-web projection of the action."
    @enforce_keys [:subject_iri, :capability_iri, :predicates, :shape_id, :ontology]
    defstruct [:subject_iri, :capability_iri, :predicates, :shape_id, :ontology]

    @type t :: %__MODULE__{
            subject_iri: term(),
            capability_iri: term(),
            predicates: term(),
            shape_id: term(),
            ontology: term()
          }
  end

  defmodule Capability do
    @moduledoc "The consequence class and authority/receipt obligations of the action."
    @enforce_keys [:capability_id, :consequence_class, :authority_required, :receipt_required]
    defstruct [:capability_id, :consequence_class, :authority_required, :receipt_required]

    @type t :: %__MODULE__{
            capability_id: term(),
            consequence_class: term(),
            authority_required: term(),
            receipt_required: term()
          }
  end

  defmodule Presentation do
    @moduledoc "The consumer-facing presentation hints for the action."
    @enforce_keys [:label, :group, :order, :widget, :format]
    defstruct [:label, :group, :order, :widget, :format]

    @type t :: %__MODULE__{
            label: term(),
            group: term(),
            order: term(),
            widget: term(),
            format: term()
          }
  end

  defmodule Schema do
    @moduledoc "The input/output validation projection of the action."
    @enforce_keys [:input, :output, :zod, :aria]
    defstruct [:input, :output, :zod, :aria]

    @type t :: %__MODULE__{
            input: term(),
            output: term(),
            zod: term(),
            aria: term()
          }
  end
end

defmodule AshSurface.Compiler.Section do
  @moduledoc """
  Behaviour for one IR section builder.

  A section receives the compiler's normalized action map entry for a single
  discovered public action and the shared compile context, and returns its
  slice of the `AshSurface.IR`. Sections must not rediscover Ash
  resource/action semantics: discovery happened exactly once before any
  section runs, and everything discovered is in the two arguments.

  ## Callback arguments

    * `action` — the normalized action entry (plain map): `:id`, `:resource`,
      `:resource_name`, `:action`, `:action_type`, `:inputs`, `:outputs`.
    * `context` — the shared context map: `:discovery` (the single discovery
      receipt, same token for every action of one compile), `:action_id`,
      and `:source` (the admitted source as passed to `compile/2`).

  """

  @callback build(action :: map(), context :: map()) :: {:ok, term()} | {:error, term()}
end

defmodule AshSurface.Compiler do
  @moduledoc """
  AshTypescript-style orchestrator: admitted source -> `[%AshSurface.IR{}]`.

  The pipeline is, by law, exactly:

      DiscoverOnce -> Normalize -> per-action section builders -> IR assembly

    * **DiscoverOnce** — the source (an `%Ash.Info.Manifest{}` or an
      `Ash.Domain` module) is read exactly once per compile, whatever the
      number of actions or sections. The pass mints a unique discovery
      receipt token that every section invocation of the same compile
      observes, which makes double discovery observable from section state.
    * **Normalize** — every discovered action is flattened into a plain,
      deterministic action map keyed by `"Resource.action"` id. The digest
      is computed over this map.
    * **Section builders** — each section key (`:ash`, `:semantic`,
      `:capability`, `:presentation`, `:schema`) is bound to a module
      implementing `AshSurface.Compiler.Section` and is invoked once per
      action, in the declared keyword order.
    * **IR assembly** — one `%AshSurface.IR{}` per action, carrying the
      shared digest, sorted by action id.

  The digest reuses the frozen `AshSurface` canon (`canonical_term` ->
  `term_to_binary` -> SHA-256 -> lower hex) over the normalized action map,
  so it is stable across map insertion order while remaining sensitive to
  every action fact.

  The default section modules live on sibling branches and are resolved at
  call time; a missing or non-conforming module fails closed with a typed
  error instead of being silently skipped. `compile/2`'s `:sections`
  override replaces the default bindings wholesale — it exists for tests
  (inline doubles) and for callers that need a different section set.
  """

  alias Ash.Info.Manifest
  alias AshSurface.IR

  @ir_version "26.9.16"

  @section_keys [:ash, :semantic, :capability, :presentation, :schema]

  @default_sections [
    ash: AshSurface.Compiler.Section.Ash,
    semantic: AshSurface.Compiler.Section.Semantic,
    capability: AshSurface.Compiler.Section.Capability,
    presentation: AshSurface.Compiler.Section.Presentation,
    schema: AshSurface.Compiler.Section.Schema
  ]

  @doc "Compiles an admitted source with the default section bindings."
  @spec compile(Manifest.t() | atom()) :: {:ok, [IR.t()]} | {:error, term()}
  def compile(source), do: compile(source, [])

  @doc """
  Compiles an admitted source into one IR per discovered public action.

  ## Options

    * `:sections` — keyword list binding section keys to modules
      implementing `AshSurface.Compiler.Section`. Replaces the defaults
      wholesale; the keyword order is the invocation order.
  """
  @spec compile(Manifest.t() | atom(), keyword()) :: {:ok, [IR.t()]} | {:error, term()}
  def compile(source, opts) do
    with {:ok, sections} <- sections(opts),
         {:ok, actions, receipt} <- discover_once(source) do
      assemble(actions, sections, receipt, source)
    end
  end

  ## DiscoverOnce

  defp discover_once(%Manifest{entrypoints: entrypoints}) do
    actions =
      entrypoints
      |> Enum.map(fn entrypoint ->
        normalize_action(entrypoint.resource, entrypoint.action)
      end)
      |> Map.new(&{&1.id, &1})

    {:ok, actions, receipt(:manifest, map_size(actions))}
  end

  defp discover_once(domain) when is_atom(domain) do
    Code.ensure_loaded(domain)

    if function_exported?(domain, :spark_is, 0) and domain.spark_is() == Ash.Domain do
      actions =
        for resource <- domain |> Ash.Domain.Info.resources() |> Enum.sort(),
            action <- Ash.Resource.Info.actions(resource),
            action.public?,
            into: %{} do
          normalized = normalize_action(resource, action)
          {normalized.id, normalized}
        end

      {:ok, actions, receipt(:domain, map_size(actions))}
    else
      {:error, {:unsupported_source, domain}}
    end
  end

  defp discover_once(source), do: {:error, {:unsupported_source, source}}

  defp receipt(kind, count) do
    %{
      token: :erlang.unique_integer([:positive, :monotonic]),
      kind: kind,
      actions: count
    }
  end

  ## Normalize

  # Manifest actions carry the unified inputs (arguments plus accepted
  # attributes) with explicit `allow_nil?`/`has_default?` facts.
  defp normalize_action(resource, %Manifest.Action{} = action) do
    %{
      id: action_id(resource, action.name),
      resource: resource,
      resource_name: module_name(resource),
      action: action.name,
      action_type: action.type,
      inputs:
        action.inputs
        |> Kernel.||([])
        |> Enum.map(
          &%{name: to_string(&1.name), allow_nil: !!&1.allow_nil?, has_default: !!&1.has_default?}
        )
        |> Enum.sort_by(& &1.name),
      outputs:
        action.metadata
        |> Kernel.||([])
        |> Enum.map(&to_string(&1.name))
        |> Enum.sort()
    }
  end

  # Raw Ash actions (domain discovery) expose public arguments; optionality
  # is derived from `allow_nil?` and the presence of a default.
  defp normalize_action(resource, action) do
    %{
      id: action_id(resource, action.name),
      resource: resource,
      resource_name: module_name(resource),
      action: action.name,
      action_type: action.type,
      inputs:
        action.arguments
        |> Kernel.||([])
        |> Enum.filter(& &1.public?)
        |> Enum.map(
          &%{
            name: to_string(&1.name),
            allow_nil: !!&1.allow_nil?,
            has_default: !is_nil(&1.default)
          }
        )
        |> Enum.sort_by(& &1.name),
      outputs:
        action.metadata
        |> Kernel.||([])
        |> Enum.map(&to_string(&1.name))
        |> Enum.sort()
    }
  end

  defp action_id(resource, action_name) do
    "#{module_name(resource)}.#{action_name}"
  end

  ## Sections

  defp sections(opts) do
    case Keyword.get(opts, :sections, @default_sections) do
      sections when is_list(sections) ->
        keys = Keyword.keys(sections)
        unknown = Enum.uniq(keys -- @section_keys)
        missing = @section_keys -- keys

        cond do
          not Keyword.keyword?(sections) ->
            {:error, {:sections_must_bind_keys_to_modules, sections}}

          keys == [] ->
            {:error, :no_sections}

          unknown != [] ->
            {:error, {:unknown_section_keys, unknown}}

          true ->
            with {:ok, sections} <- ensure_section_modules(sections) do
              if missing == [] do
                {:ok, sections}
              else
                {:error, {:missing_section_keys, missing}}
              end
            end
        end

      other ->
        {:error, {:sections_must_bind_keys_to_modules, other}}
    end
  end

  defp ensure_section_modules(sections) do
    sections
    |> Enum.reduce_while({:ok, sections}, fn {key, module}, {:ok, acc} ->
      Code.ensure_loaded(module)

      if function_exported?(module, :build, 2) do
        {:cont, {:ok, acc}}
      else
        {:halt, {:error, {:invalid_section_module, key, module}}}
      end
    end)
  end

  ## IR assembly

  defp assemble(actions, sections, receipt, source) do
    digest = digest(actions)

    actions
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.reduce_while({:ok, []}, fn {id, action}, {:ok, irs} ->
      context = %{discovery: receipt, action_id: id, source: source}

      case build_sections(action, context, sections) do
        {:ok, built} ->
          {:cont,
           {:ok,
            [
              %IR{
                version: @ir_version,
                digest: digest,
                ash: built.ash,
                semantic: built.semantic,
                capability: built.capability,
                presentation: built.presentation,
                schema: built.schema
              }
              | irs
            ]}}

        {:error, reason} ->
          {:halt, {:error, {:section_failed, id, reason}}}
      end
    end)
    |> case do
      {:ok, irs} -> {:ok, Enum.reverse(irs)}
      error -> error
    end
  end

  defp build_sections(action, context, sections) do
    sections
    |> Enum.reduce_while({:ok, %{}}, fn {key, module}, {:ok, acc} ->
      case module.build(action, context) do
        {:ok, section} -> {:cont, {:ok, Map.put(acc, key, section)}}
        {:error, reason} -> {:halt, {:error, {key, reason}}}
      end
    end)
  end

  ## Digest (the frozen AshSurface canon, applied to the normalized map)

  defp digest(normalized) do
    normalized
    |> canonical_term()
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp canonical_term(term) when is_map(term) do
    term
    |> Enum.map(fn {key, value} -> {to_string(key), canonical_term(value)} end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  defp canonical_term(term) when is_list(term), do: Enum.map(term, &canonical_term/1)
  defp canonical_term(term), do: term

  defp module_name(module), do: module |> Module.split() |> Enum.join(".")
end
