defmodule AshSurface.Projectors.JS.Inference do
  @moduledoc """
  Deterministic TypeScript inference block (UnionToIntersection, InferResult,
  UnifiedFieldSelection, pagination result types) adapted from
  `AshTypescript.Codegen.UtilityTypes`, plus per-resource schema meta types.

  The output is a `.d.ts`-style declaration artifact (a non-expression string). It is
  NOT passed through `AshSurface.Projectors.JS.ZodGuard`, which admits only Zod
  expressions. Resource and field names are validated as identifiers /
  emitted as JSON string literals, so no caller text reaches code unescaped.
  """

  @utility ~S"""
  // Sort string type — allows optional direction prefix on sort field names
  // Prefixes per Ash.Query.sort/3: + (asc), - (desc), ++ (asc_nils_first), -- (desc_nils_last)
  export type SortString<T extends string> = T | `+${T}` | `-${T}` | `++${T}` | `--${T}`;

  // Nested relationship pagination input, keyed by the relationship's
  // __pagination marker ("offset" | "keyset" | "mixed"). Keys of the other
  // pagination family are typed `never` so passing them is a structural
  // error (excess-property checking does not fire through the envelope's
  // conditional types).
  export type NestedPageInput<P extends string> = P extends "offset"
    ? { limit?: number; offset?: number; count?: boolean; after?: never; before?: never }
    : P extends "keyset"
      ? { limit?: number; after?: string; before?: string; count?: boolean; offset?: never }
      :
          | { limit?: number; offset?: number; count?: boolean; after?: never; before?: never }
          | { limit?: number; after?: string; before?: string; count?: boolean; offset?: never };

  // Resource schema constraint
  export type TypedSchema = {
    __type: "Resource" | "TypedMap" | "Union";
    __primitiveFields: string;
  };

  // Utility type to convert union to intersection
  export type UnionToIntersection<U> = (U extends any ? (k: U) => void : never) extends (
    k: infer I,
  ) => void
    ? I
    : never;

  // Helper type to infer union field values, avoiding duplication between array and non-array unions
  // Selection-object walkers use key remapping to drop keys whose value is
  // undefined: hoisting a selection with `satisfies` widens the array to a
  // union whose object members grow synthetic `?: undefined` siblings, and
  // walking those as real selections would collapse the result to never.
  // `FieldSelection[FieldIndex] extends infer Sel` re-binds the element to a
  // naked type parameter so widened (non-tuple) selections distribute over
  // their element union instead of falling through to never.
  export type InferUnionFieldValue<
    UnionSchema extends { __type: "Union"; __primitiveFields: any },
    FieldSelection extends any[],
  > = UnionToIntersection<
    {
      [FieldIndex in keyof FieldSelection]: FieldSelection[FieldIndex] extends infer Sel
        ? Sel extends UnionSchema["__primitiveFields"]
          ? Sel extends keyof UnionSchema
            ? { [P in Sel]: UnionSchema[Sel] }
            : never
          : Sel extends Record<string, any>
            ? {
                [UnionKey in keyof Sel as Sel[UnionKey] extends undefined ? never : UnionKey]: UnionKey extends keyof UnionSchema
                  ? NonNullable<UnionSchema[UnionKey]> extends { __array: true; __type: "TypedMap"; __primitiveFields: infer TypedMapFields }
                    ? Sel[UnionKey] extends any[]
                      ? Array<
                          UnionToIntersection<
                            {
                              [FieldIdx in keyof Sel[UnionKey]]: Sel[UnionKey][FieldIdx] extends TypedMapFields
                                ? Sel[UnionKey][FieldIdx] extends keyof NonNullable<UnionSchema[UnionKey]>
                                  ? { [P in Sel[UnionKey][FieldIdx]]: NonNullable<UnionSchema[UnionKey]>[P] }
                                  : never
                                : never;
                            }[number]
                          >
                        > | null
                      : never
                    : NonNullable<UnionSchema[UnionKey]> extends { __type: "TypedMap"; __primitiveFields: infer TypedMapFields }
                      ? Sel[UnionKey] extends any[]
                        ? UnionToIntersection<
                            {
                              [FieldIdx in keyof Sel[UnionKey]]: Sel[UnionKey][FieldIdx] extends TypedMapFields
                                ? Sel[UnionKey][FieldIdx] extends keyof NonNullable<UnionSchema[UnionKey]>
                                  ? { [P in Sel[UnionKey][FieldIdx]]: NonNullable<UnionSchema[UnionKey]>[P] }
                                  : never
                                : never;
                            }[number]
                          > | null
                        : never
                      : NonNullable<UnionSchema[UnionKey]> extends TypedSchema
                        ? InferResult<NonNullable<UnionSchema[UnionKey]>, Sel[UnionKey]>
                        : never
                  : never;
              }
            : never
        : never;
    }[number]
  >;

  export type HasComplexFields<T extends TypedSchema> = keyof Omit<
    T,
    "__primitiveFields" | "__type" | T["__primitiveFields"]
  > extends never
    ? false
    : true;

  export type ComplexFieldKeys<T extends TypedSchema> = keyof Omit<
    T,
    "__primitiveFields" | "__type" | T["__primitiveFields"]
  >;

  export type LeafFieldSelection<T extends TypedSchema> = T["__primitiveFields"];

  // Query-option envelope for many-cardinality relationships. Each optional
  // key is usable only when the corresponding capability marker is present
  // and the action-level flag (F = filter, S = sort) is enabled; otherwise
  // the key is typed `never` so passing a value is a structural error (plain
  // excess-property checking does not fire through these conditional types).
  // `page` and bare `limit`/`offset` are mutually exclusive: the pagination
  // part is a union of the two shapes, each `never`-typing the other's keys.
  export type RelationshipQueryEnvelope<
    Meta,
    Dest extends TypedSchema,
    F extends boolean = true,
    S extends boolean = true,
  > = {
    fields: UnifiedFieldSelection<Dest, F, S>[];
  } & (F extends true
    ? Meta extends { __filterInput: infer FI }
      ? { filter?: FI }
      : { filter?: never }
    : { filter?: never }) &
    (S extends true
      ? Meta extends { __sortField: infer SF extends string }
        ? { sort?: SortString<SF> | SortString<SF>[] }
        : { sort?: never }
      : { sort?: never }) &
    (Meta extends { __pagination: infer P extends string }
      ? (
          | { page?: NestedPageInput<P>; limit?: never; offset?: never }
          | { limit?: number; offset?: number; page?: never }
        )
      : { limit?: number; offset?: number; page?: never });

  export type ComplexFieldSelection<
    T extends TypedSchema,
    F extends boolean = true,
    S extends boolean = true,
  > = {
    [K in ComplexFieldKeys<T>]?: T[K] extends {
      __type: "Relationship";
      __resource: infer Resource;
    }
      ? NonNullable<Resource> extends TypedSchema
        ? T[K] extends { __array: true }
          ?
              | UnifiedFieldSelection<NonNullable<Resource>, F, S>[]
              | RelationshipQueryEnvelope<T[K], NonNullable<Resource>, F, S>
          : UnifiedFieldSelection<NonNullable<Resource>, F, S>[]
        : never
      : T[K] extends {
            __type: "ComplexCalculation";
            __returnType: infer ReturnType;
          }
        ? T[K] extends { __args: infer Args }
          ? NonNullable<ReturnType> extends TypedSchema
            ? (
                | {
                    args: Args;
                    fields: UnifiedFieldSelection<NonNullable<ReturnType>, F, S>[];
                  }
                | ({} extends Args ? UnifiedFieldSelection<NonNullable<ReturnType>, F, S>[] : never)
              )
            : { args: Args }
          : NonNullable<ReturnType> extends TypedSchema
            ? (
                | { fields: UnifiedFieldSelection<NonNullable<ReturnType>, F, S>[] }
                | UnifiedFieldSelection<NonNullable<ReturnType>, F, S>[]
              )
            : never
        : T[K] extends { __type: "TypedMap" }
          ? NonNullable<T[K]> extends TypedSchema
            ? UnifiedFieldSelection<NonNullable<T[K]>, F, S>[]
            : never
          : T[K] extends { __type: "Union"; __primitiveFields: infer PrimitiveFields }
            ? T[K] extends { __array: true }
              ? (PrimitiveFields | {
                  [UnionKey in keyof Omit<T[K], "__type" | "__primitiveFields" | "__array">]?: NonNullable<T[K][UnionKey]> extends { __type: "TypedMap"; __primitiveFields: any }
                    ? NonNullable<T[K][UnionKey]>["__primitiveFields"][]
                    : NonNullable<T[K][UnionKey]> extends TypedSchema
                      ? UnifiedFieldSelection<NonNullable<T[K][UnionKey]>, F, S>[]
                      : never;
                })[]
              : (PrimitiveFields | {
                  [UnionKey in keyof Omit<T[K], "__type" | "__primitiveFields">]?: NonNullable<T[K][UnionKey]> extends { __type: "TypedMap"; __primitiveFields: any }
                    ? NonNullable<T[K][UnionKey]>["__primitiveFields"][]
                    : NonNullable<T[K][UnionKey]> extends TypedSchema
                      ? UnifiedFieldSelection<NonNullable<T[K][UnionKey]>, F, S>[]
                      : never;
                })[]
              : NonNullable<T[K]> extends TypedSchema
                ? UnifiedFieldSelection<NonNullable<T[K]>, F, S>[]
                : never;
  };

  // Main type: Use explicit base case detection to prevent infinite recursion
  export type UnifiedFieldSelection<
    T extends TypedSchema,
    F extends boolean = true,
    S extends boolean = true,
  > =
    HasComplexFields<T> extends false
      ? LeafFieldSelection<T> // Base case: only primitives, no recursion
      : LeafFieldSelection<T> | ComplexFieldSelection<T, F, S>; // Recursive case

  // Infers the result value of one selected member inside a TypedMap:
  // Relationship-wrapped members (embedded resources) recurse through the
  // wrapped resource; plain TypedSchema members (nested TypedMaps) recurse
  // directly. The Selection guard satisfies InferResult's constraint.
  export type InferTypedMapMemberValue<M, Selection> = M extends {
    __type: "Relationship";
    __resource: infer Resource;
  }
    ? NonNullable<Resource> extends TypedSchema
      ? Selection extends UnifiedFieldSelection<NonNullable<Resource>>[] | undefined
        ? M extends { __array: true }
          ? null extends Resource
            ? Array<InferResult<NonNullable<Resource>, Selection>> | null
            : Array<InferResult<NonNullable<Resource>, Selection>>
          : null extends Resource
            ? InferResult<NonNullable<Resource>, Selection> | null
            : InferResult<NonNullable<Resource>, Selection>
        : never
      : never
    : NonNullable<M> extends TypedSchema
      ? Selection extends UnifiedFieldSelection<NonNullable<M>>[] | undefined
        ? null extends M
          ? InferResult<NonNullable<M>, Selection> | null
          : InferResult<NonNullable<M>, Selection>
        : never
      : never;

  export type InferFieldValue<
    T extends TypedSchema,
    Field,
  > = Field extends T["__primitiveFields"]
    ? Field extends keyof T
      ? { [K in Field]: T[Field] }
      : never
    : Field extends Record<string, any>
      ? {
          [K in keyof Field as Field[K] extends undefined ? never : K]: K extends keyof T
            ? T[K] extends {
                __type: "Relationship";
                __resource: infer Resource;
              }
              ? NonNullable<Resource> extends TypedSchema
                ? Field[K] extends { fields: infer NestedFields }
                  ? NestedFields extends UnifiedFieldSelection<NonNullable<Resource>>[]
                    ? Field[K] extends { page: infer Page }
                      ? T[K] extends { __pagination: infer P extends string }
                        ? NestedPageResult<NonNullable<Resource>, NestedFields, P, Page>
                        : never
                      : T[K] extends { __array: true }
                        ? Array<InferResult<NonNullable<Resource>, NestedFields>>
                        : never
                    : never
                  : T[K] extends { __array: true }
                    ? null extends Resource
                      ? Array<InferResult<NonNullable<Resource>, Field[K]>> | null
                      : Array<InferResult<NonNullable<Resource>, Field[K]>>
                    : null extends Resource
                      ? InferResult<NonNullable<Resource>, Field[K]> | null
                      : InferResult<NonNullable<Resource>, Field[K]>
              : never
            : T[K] extends {
                  __type: "ComplexCalculation";
                  __returnType: infer ReturnType;
                }
              ? NonNullable<ReturnType> extends TypedSchema
                ? null extends ReturnType
                  ? InferResult<NonNullable<ReturnType>, Field[K] extends any[] ? Field[K] : Field[K]["fields"]> | null
                  : InferResult<NonNullable<ReturnType>, Field[K] extends any[] ? Field[K] : Field[K]["fields"]>
                : ReturnType
              : NonNullable<T[K]> extends { __type: "TypedMap"; __primitiveFields: infer TypedMapFields }
                ? NonNullable<T[K]> extends { __array: true }
                  ? Field[K] extends any[]
                    ? null extends T[K]
                      ? Array<
                          UnionToIntersection<
                            {
                              [FieldIndex in keyof Field[K]]: Field[K][FieldIndex] extends infer E
                                ? E extends TypedMapFields
                                  ? E extends keyof NonNullable<T[K]>
                                    ? { [P in E]: NonNullable<T[K]>[P] }
                                    : never
                                  : E extends Record<string, any>
                                    ? {
                                        [NestedKey in keyof E as E[NestedKey] extends undefined ? never : NestedKey]: NestedKey extends keyof NonNullable<T[K]>
                                            ? InferTypedMapMemberValue<NonNullable<T[K]>[NestedKey], E[NestedKey]>
                                          : never;
                                      }
                                    : E extends keyof NonNullable<T[K]>
                                      ? { [P in E]: NonNullable<T[K]>[P] }
                                      : never
                                : never;
                            }[number]
                          >
                        > | null
                      : Array<
                          UnionToIntersection<
                            {
                              [FieldIndex in keyof Field[K]]: Field[K][FieldIndex] extends infer E
                                ? E extends TypedMapFields
                                  ? E extends keyof NonNullable<T[K]>
                                    ? { [P in E]: NonNullable<T[K]>[P] }
                                    : never
                                  : E extends Record<string, any>
                                    ? {
                                        [NestedKey in keyof E as E[NestedKey] extends undefined ? never : NestedKey]: NestedKey extends keyof NonNullable<T[K]>
                                            ? InferTypedMapMemberValue<NonNullable<T[K]>[NestedKey], E[NestedKey]>
                                          : never;
                                      }
                                    : E extends keyof NonNullable<T[K]>
                                      ? { [P in E]: NonNullable<T[K]>[P] }
                                      : never
                                : never;
                            }[number]
                          >
                        >
                    : never
                  : Field[K] extends any[]
                    ? null extends T[K]
                      ? UnionToIntersection<
                          {
                            [FieldIndex in keyof Field[K]]: Field[K][FieldIndex] extends infer E
                              ? E extends TypedMapFields
                                ? E extends keyof NonNullable<T[K]>
                                  ? { [P in E]: NonNullable<T[K]>[P] }
                                  : never
                                : E extends Record<string, any>
                                  ? {
                                      [NestedKey in keyof E as E[NestedKey] extends undefined ? never : NestedKey]: NestedKey extends keyof NonNullable<T[K]>
                                          ? InferTypedMapMemberValue<NonNullable<T[K]>[NestedKey], E[NestedKey]>
                                        : never;
                                    }
                                  : E extends keyof NonNullable<T[K]>
                                    ? { [P in E]: NonNullable<T[K]>[P] }
                                    : never
                              : never;
                          }[number]
                        > | null
                      : UnionToIntersection<
                          {
                            [FieldIndex in keyof Field[K]]: Field[K][FieldIndex] extends infer E
                              ? E extends TypedMapFields
                                ? E extends keyof T[K]
                                  ? { [P in E]: T[K][P] }
                                  : never
                                : E extends Record<string, any>
                                  ? {
                                      [NestedKey in keyof E as E[NestedKey] extends undefined ? never : NestedKey]: NestedKey extends keyof NonNullable<T[K]>
                                          ? InferTypedMapMemberValue<NonNullable<T[K]>[NestedKey], E[NestedKey]>
                                        : never;
                                    }
                                  : E extends keyof NonNullable<T[K]>
                                    ? { [P in E]: NonNullable<T[K]>[P] }
                                    : never
                              : never;
                          }[number]
                        >
                    : never
                : T[K] extends { __type: "Union"; __primitiveFields: any }
                  ? T[K] extends { __array: true }
                    ? Field[K] extends any[]
                      ? null extends T[K]
                        ? Array<InferUnionFieldValue<T[K], Field[K]>> | null
                        : Array<InferUnionFieldValue<T[K], Field[K]>>
                      : never
                    : Field[K] extends any[]
                      ? null extends T[K]
                        ? InferUnionFieldValue<T[K], Field[K]> | null
                        : InferUnionFieldValue<T[K], Field[K]>
                      : never
                    : NonNullable<T[K]> extends TypedSchema
                      ? null extends T[K]
                        ? InferResult<NonNullable<T[K]>, Field[K]> | null
                        : InferResult<NonNullable<T[K]>, Field[K]>
                      : never
            : never;
        }
      : never;

  export type InferResult<
    T extends TypedSchema,
    SelectedFields extends UnifiedFieldSelection<T>[] | undefined,
  > = SelectedFields extends undefined
    ? {}
    : SelectedFields extends []
    ? {}
    : SelectedFields extends UnifiedFieldSelection<T>[]
    ? UnionToIntersection<
        {
          [K in keyof SelectedFields]: InferFieldValue<T, SelectedFields[K]>;
        }[number]
      >
    : {};

  // Pagination conditional types
  // Checks if a page configuration object has any pagination parameters.
  // A limit-only page (e.g. { limit: 20 } for the first page) also paginates.
  export type HasPaginationParams<Page> =
    Page extends { offset: any } ? true :
    Page extends { after: any } ? true :
    Page extends { before: any } ? true :
    Page extends { limit: any } ? true :
    false;

  // Infer which pagination type is being used from the page config.
  // A limit-only page resolves to keyset — when an action supports both
  // strategies, Ash paginates limit-only requests with keyset.
  export type InferPaginationType<Page> =
    Page extends { offset: any } ? "offset" :
    Page extends { after: any } | { before: any } ? "keyset" :
    Page extends { limit: any } ? "keyset" :
    never;

  // Returns either non-paginated (array) or paginated result based on page params
  // For single pagination type support (offset-only or keyset-only)
  // @ts-ignore
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  export type ConditionalPaginatedResult<
    Page,
    RecordType,
    PaginatedType
  > = Page extends undefined
    ? RecordType
    : HasPaginationParams<Page> extends true
      ? PaginatedType
      : RecordType;

  // For actions supporting both offset and keyset pagination
  // Infers the specific pagination type based on which params were passed
  export type ConditionalPaginatedResultMixed<
    Page,
    RecordType,
    OffsetType,
    KeysetType
  > = Page extends undefined
    ? RecordType
    : HasPaginationParams<Page> extends true
      ? InferPaginationType<Page> extends "offset"
        ? OffsetType
        : InferPaginationType<Page> extends "keyset"
          ? KeysetType
          : OffsetType | KeysetType  // Fallback to union if can't determine
      : RecordType;

  // Nested relationship pagination results — shaped identically to the
  // top-level page payloads, but generic over the destination schema.
  export type NestedOffsetPageResult<R extends TypedSchema, Fields> = {
    results: Fields extends UnifiedFieldSelection<R>[] ? Array<InferResult<R, Fields>> : never;
    hasMore: boolean;
    limit: number;
    offset: number;
    count?: number | null;
    type: "offset";
  };

  export type NestedKeysetPageResult<R extends TypedSchema, Fields> = {
    results: Fields extends UnifiedFieldSelection<R>[] ? Array<InferResult<R, Fields>> : never;
    hasMore: boolean;
    limit: number;
    after: string | null;
    before: string | null;
    previousPage: string | null;
    nextPage: string | null;
    count?: number | null;
    type: "keyset";
  };

  // P is the relationship's __pagination marker; Page is the page input the
  // caller actually passed (used to narrow "mixed" to a concrete side).
  export type NestedPageResult<R extends TypedSchema, Fields, P extends string, Page> =
    P extends "offset"
      ? NestedOffsetPageResult<R, Fields>
      : P extends "keyset"
        ? NestedKeysetPageResult<R, Fields>
        : InferPaginationType<Page> extends "offset"
          ? NestedOffsetPageResult<R, Fields>
          : InferPaginationType<Page> extends "keyset"
            ? NestedKeysetPageResult<R, Fields>
            : NestedOffsetPageResult<R, Fields> | NestedKeysetPageResult<R, Fields>;
  """

  @doc "The static utility-type block (byte-deterministic)."
  @spec utility_types() :: String.t()
  def utility_types, do: @utility

  @doc """
  Per-resource schema meta type. `fields` is a list of
  `%{name: String.t(), ts: String.t(), primitive?: boolean}`; non-primitive
  entries are emitted as complex members (`ts` is trusted TS type text from
  the compiler, e.g. a Relationship meta). Sorted by name.
  """
  @spec resource_meta(String.t(), [map()]) :: String.t()
  def resource_meta(resource, fields) do
    unless Regex.match?(~r/\A[A-Za-z_][A-Za-z0-9_]*\z/, resource),
      do: raise(ArgumentError, "invalid resource identifier: #{inspect(resource)}")

    fields = Enum.sort_by(fields, & &1.name)
    prim = for f <- fields, f.primitive?, do: Jason.encode!(f.name)
    prim = if prim == [], do: "never", else: Enum.join(prim, " | ")

    members =
      Enum.map_join(fields, "", fn f ->
        "  #{Jason.encode!(f.name)}: #{f.ts};\n"
      end)

    "export type #{resource}Schema = {\n  __type: \"Resource\";\n" <>
      "  __primitiveFields: #{prim};\n" <> members <> "};\n"
  end

  @ident ~r/\A[A-Za-z_][A-Za-z0-9_]*\z/

  @default_names %{
    fields: "fields",
    args: "args",
    filter: "filter",
    sort: "sort",
    page: "page",
    limit: "limit",
    offset: "offset",
    count: "count",
    results: "results",
    has_more: "hasMore",
    type: "type",
    after: "after",
    before: "before",
    previous_page: "previousPage",
    next_page: "nextPage"
  }

  @doc "Default wire field names interpolated into per-action types (overridable via `opts`)."
  @spec default_names() :: map()
  def default_names, do: @default_names

  @doc """
  Per-action type generators. `spec` keys:

    * `:name` (required) - PascalCase identifier, e.g. `"ListPosts"`
    * `:schema` (required) - resource schema type, e.g. `"PostSchema"`
    * `:kind` - `:read | :get | :create | :update | :destroy | :action` (default `:read`)
    * `:not_found_error?` - for `:get`; when false the result gains a `| null` suffix
    * `:pagination` - `nil | :offset | :keyset | :mixed`; `:pagination_optional?` makes it optional
    * `:metadata` - list of `%{name: String.t(), ts: String.t()}`
    * `:args_ts`, `:filter_ts` - trusted TS type text for `args` / `filter`
    * `:sort_fields` - list of sortable field names

  `opts` overrides any key of `default_names/0` (fields/args/filter/sort/page/limit/
  offset/count/...). Emits `<Name>Fields`, `<Name>Metadata` (if any), `<Name>Config`,
  and `Infer<Name>Result`. Page-generic narrowing is by `Page`, defaulting to `undefined`.
  """
  @spec action_types(map(), keyword()) :: String.t()
  def action_types(spec, opts \\ []) do
    names = Map.merge(@default_names, Map.new(opts))

    for {k, v} <- names do
      ident!(v, "name option #{k}")
    end

    name = ident!(Map.fetch!(spec, :name), "action name")
    schema = ident!(Map.fetch!(spec, :schema), "schema")
    kind = Map.get(spec, :kind, :read)
    meta = Map.get(spec, :metadata, [])
    pag = Map.get(spec, :pagination)
    pag_opt? = Map.get(spec, :pagination_optional?, false)

    unless kind in [:read, :get, :create, :update, :destroy, :action],
      do: raise(ArgumentError, "invalid action kind: #{inspect(kind)}")

    unless pag in [nil, :offset, :keyset, :mixed],
      do: raise(ArgumentError, "invalid pagination: #{inspect(pag)}")

    pag = if kind == :read, do: pag, else: nil

    fields_t = "export type #{name}Fields = UnifiedFieldSelection<#{schema}>[];\n"

    meta_t =
      if meta == [] do
        ""
      else
        body =
          meta
          |> Enum.sort_by(& &1.name)
          |> Enum.map_join("", fn m -> "  #{Jason.encode!(m.name)}: #{m.ts};\n" end)

        "export type #{name}Metadata = {\n#{body}};\n"
      end

    page_t = if pag, do: page_input(name, pag, names), else: ""
    cfg_t = config_type(name, spec, pag, names)

    elem_t =
      if meta == [],
        do: "InferResult<#{schema}, Fields>",
        else: "InferResult<#{schema}, Fields> & Pick<#{name}Metadata, MetadataFields[number]>"

    generics =
      [
        "Fields extends #{name}Fields"
        | if(meta == [],
            do: [],
            else: ["MetadataFields extends ReadonlyArray<keyof #{name}Metadata> = []"]
          )
      ] ++
        if(pag,
          do: [
            "Page extends #{name}PageInput#{if pag_opt?, do: " | undefined", else: ""} = #{if pag_opt?, do: "undefined", else: "never"}"
          ],
          else: []
        )

    result_body =
      case kind do
        :destroy ->
          "{}"

        :get ->
          if Map.get(spec, :not_found_error?, true), do: elem_t, else: "(#{elem_t}) | null"

        k when k in [:create, :update] ->
          elem_t

        :action ->
          elem_t

        :read ->
          read_result(name, elem_t, pag, pag_opt?, names)
      end

    result_t =
      if kind == :destroy do
        "export type Infer#{name}Result = {};\n"
      else
        "export type Infer#{name}Result<\n  #{Enum.join(generics, ",\n  ")}\n> = #{result_body};\n"
      end

    fields_t <> meta_t <> page_t <> cfg_t <> result_t
  end

  defp read_result(_name, elem_t, nil, _opt?, _n), do: "Array<#{elem_t}>"

  defp read_result(_name, elem_t, :offset, opt?, n) do
    off = offset_page(elem_t, n)
    if opt?, do: "ConditionalPaginatedResult<Page, Array<#{elem_t}>, #{off}>", else: off
  end

  defp read_result(_name, elem_t, :keyset, opt?, n) do
    key = keyset_page(elem_t, n)
    if opt?, do: "ConditionalPaginatedResult<Page, Array<#{elem_t}>, #{key}>", else: key
  end

  defp read_result(_name, elem_t, :mixed, opt?, n) do
    off = offset_page(elem_t, n)
    key = keyset_page(elem_t, n)

    if opt? do
      "ConditionalPaginatedResultMixed<Page, Array<#{elem_t}>, #{off}, #{key}>"
    else
      "[InferPaginationType<Page>] extends [never] ? #{off} | #{key} : InferPaginationType<Page> extends \"offset\" ? #{off} : #{key}"
    end
  end

  defp offset_page(elem_t, n) do
    "{ #{n.results}: Array<#{elem_t}>; #{n.has_more}: boolean; #{n.limit}: number; " <>
      "#{n.offset}: number; #{n.count}?: number | null; #{n.type}: \"offset\" }"
  end

  defp keyset_page(elem_t, n) do
    "{ #{n.results}: Array<#{elem_t}>; #{n.has_more}: boolean; #{n.limit}: number; " <>
      "#{n.after}: string | null; #{n.before}: string | null; " <>
      "#{n.previous_page}: string | null; #{n.next_page}: string | null; " <>
      "#{n.count}?: number | null; #{n.type}: \"keyset\" }"
  end

  defp page_input(name, pag, n) do
    off = "{ #{n.limit}?: number; #{n.offset}?: number; #{n.count}?: boolean }"

    key =
      "{ #{n.limit}?: number; #{n.after}?: string; #{n.before}?: string; #{n.count}?: boolean }"

    body =
      case pag do
        :offset -> off
        :keyset -> key
        :mixed -> "#{off} | #{key}"
      end

    "export type #{name}PageInput = #{body};\n"
  end

  defp config_type(name, spec, pag, n) do
    members =
      [
        "  #{n.fields}: #{name}Fields;",
        if(spec[:args_ts], do: "  #{n.args}: #{spec[:args_ts]};"),
        if(spec[:filter_ts], do: "  #{n.filter}?: #{spec[:filter_ts]};"),
        case spec[:sort_fields] do
          [_ | _] = fs ->
            u = Enum.map_join(Enum.sort(fs), " | ", &Jason.encode!/1)
            "  #{n.sort}?: SortString<#{u}> | SortString<#{u}>[];"

          _ ->
            nil
        end,
        if(pag, do: "  #{n.page}?: #{name}PageInput;")
      ]
      |> Enum.reject(&is_nil/1)

    "export type #{name}Config = {\n#{Enum.join(members, "\n")}\n};\n"
  end

  defp ident!(v, what) do
    if is_binary(v) and Regex.match?(@ident, v),
      do: v,
      else: raise(ArgumentError, "invalid #{what}: #{inspect(v)}")
  end

  @doc "Full artifact: header + utility types + one meta type per resource."
  @spec emit([{String.t(), [map()]}]) :: String.t()
  def emit(resources \\ []) do
    metas =
      resources
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map_join("\n", fn {n, f} -> resource_meta(n, f) end)

    "// Generated by AshSurface. Do not edit.\n\n" <> @utility <> "\n" <> metas
  end
end
