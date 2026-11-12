defmodule AshSurface.Projectors.JS.ZodGuard do
  @moduledoc """
  Admission guard for `IR.Schema.zod` source text before
  `AshSurface.Projectors.JS` embeds it as CODE in a generated `.mjs`.

  `IR.Schema.zod` is a string. When IR arrives through
  `AshSurface.IR.Codec.from_map/1` (decoded JSON) that string is untrusted
  input, and embedding it verbatim is a code-injection path. This guard admits
  exactly the grammar the admitted producers emit and refuses everything else.

  ## Admitted grammar

  A **zod expression**: a `z`-rooted member/call chain over literal data —

      expr   := "z" ("." name [call])+
      call   := "(" [value ("," value)* [","]] ")"
      value  := expr | string | number | "true" | "false" | "null"
              | "[" [value ("," value)* [","]] "]"
              | "{" [key ":" value ("," key ":" value)* [","]] "}"
      key    := name | string

  where `string` is a double-quoted JSON string literal, `number` a JSON
  number, `name` an ASCII identifier, and whitespace (space, tab, CR, LF) may
  separate tokens. There are no other identifiers (only `z` is ever
  referenced), no function literals, no operators, no computed member access,
  no template literals and no comments; `value` may additionally be a regex
  literal `/.../flags` (zod `.regex/1` argument; `/` cannot begin any other
  token); the member names
  `constructor`, `prototype`, `call`, `apply`, `bind` and any `__`-prefixed
  name are refused (as is the object key `__proto__`), so the `Function` constructor is unreachable. This covers
  every fragment `AshSurface.Compiler.Schema` produces (its `@zod_kinds`
  table plus `.optional().nullable()`, `z.object({...}).passthrough()`,
  `z.undefined()`, `z.unknown()`) and the authored fixtures in the JS
  projector suites (`z.enum([...])`, `.min(1)`, ...).

  A **compiled zod program**: exactly the text
  `AshSurface.Compiler.Schema.render_zod/3` emits —

      export const <S>_inputSchema = <expr>;

      export const <S>_outputSchema = <expr>;

  with both `<expr>` admitted by the expression grammar. The program is a
  module fragment, not an expression, so it cannot be embedded as
  `export const X = <zod>;`; its INPUT schema (the boundary `dispatchIntent`
  validates) is admitted as the action's schema expression. The output
  schema is validated and not embedded.

  Regex literals: flags must be drawn from `[dgimsuvy]` with no duplicate, and
  the body may not contain a raw line terminator; an unterminated literal is
  refused. The guard is LEXICAL ONLY: it cannot detect a regex body that is
  invalid JavaScript (e.g. `/(/`) or catastrophic. Regex safety is
  `AshSurface.Compiler.ZodType`'s job (`regex_safe_for_js?/1`).

  The guard confines the text syntactically; it does not (and cannot) prove
  what a given zod method does at runtime.
  """

  # Member ALLOW-list: every `z.<member>` / chained method the compiler
  # renderers emit (derived by grep of lib/ash_surface/compiler + projector
  # for `z\.` and chain calls). Anything else (`config`, `globalRegistry`,
  # `core`, `jitless`, ...) can mutate global zod state at module load.
  @allowed_members ~w(string number boolean object array union literal enum optional nullable
                      record partialRecord tuple unknown any never undefined int uuid email iso
                      date time datetime duration regex min max gt lt positive strict passthrough
                      default discriminatedUnion intersection lazy strictObject looseObject nullish guid coerce bigint date email url)

  @program ~r/\Aexport const ([A-Za-z0-9_]+)_inputSchema = (.+?);\n\nexport const \1_outputSchema = (.+?);\n\z/s

  @token_patterns [
    {:ws, ~r/\A[ \t\r\n]+/},
    {:string, ~r/\A"(?:[^"\\\x00-\x1f]|\\["\\\/bfnrt]|\\u[0-9a-fA-F]{4})*"/},
    {:number, ~r/\A-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?/},
    {:name, ~r/\A[A-Za-z_$][A-Za-z0-9_$]*/},
    # Regex literal: `/` appears nowhere else in the grammar (no operators),
    # so `/` unambiguously opens one. Body = escaped char, character class,
    # or ordinary char. No raw line terminator (LF, CR, U+2028/9 as UTF-8 bytes) in the body (JS regex literals cannot span lines);
    # flags are lexed as letters then checked against [dgimsuvy], no duplicates.
    {:regex,
     ~r{\A/(?!\*)(?:\\(?:(?!\xE2\x80[\xA8\xA9])[^\n\r])|\[(?:\\(?:(?!\xE2\x80[\xA8\xA9])[^\n\r])|(?!\xE2\x80[\xA8\xA9])[^\]\\\n\r])*\]|(?!\xE2\x80[\xA8\xA9])[^/\\\[\n\r])+/[a-zA-Z]*}},
    {:punct, ~r/\A[.(),\[\]{}:;]/}
  ]

  @doc """
  Admits `zod` source text. Returns `{:ok, :expression, zod}` for an admitted
  expression (embedded byte-verbatim), `{:ok, :program, input_expr}` for an
  admitted compiled program, and `{:error, reason}` otherwise.
  """
  @spec admit(String.t(), keyword()) ::
          {:ok, :expression | :program, String.t()} | {:error, term()}
  def admit(zod, opts \\ [])

  def admit(zod, opts) when is_binary(zod) do
    {decls, rest} = split_declarations(zod)
    names = Enum.map(decls, &elem(&1, 0))
    eopts = Keyword.update(opts, :identifiers, names, &(&1 ++ names))

    with :ok <- check_unique(names),
         :ok <- check_decls(decls, eopts) do
      case Regex.run(@program, rest, capture: :all_but_first) do
        [_name, input, output] ->
          with :ok <- expression(input, eopts), :ok <- expression(output, eopts) do
            {:ok, :program, input}
          end

        nil when decls == [] ->
          with :ok <- expression(zod, opts), do: {:ok, :expression, zod}

        nil ->
          {:error, {:zod_declarations_without_program, names}}
      end
    end
  end

  def admit(other, _opts), do: {:error, {:zod_not_a_string, other}}

  @decl ~r/\Aconst ([A-Za-z_$][A-Za-z0-9_$]*) = (.+?);\n(?=const |export const )/s

  @doc """
  The leading `const <Name> = <expr>;` declarations of a compiled program (named embedded
  resources, F1-refs/KD-02) as `[{name, expr}]`. Pure text split; admission is `admit/2`.
  """
  @spec declarations(String.t()) :: [{String.t(), String.t()}]
  def declarations(zod) when is_binary(zod), do: zod |> split_declarations() |> elem(0)

  defp split_declarations(text), do: split_declarations(text, [])

  defp split_declarations(text, acc) do
    case Regex.run(@decl, text) do
      [whole, name, expr] ->
        split_declarations(
          binary_part(text, byte_size(whole), byte_size(text) - byte_size(whole)),
          [{name, expr} | acc]
        )

      nil ->
        {Enum.reverse(acc), text}
    end
  end

  defp check_unique(names) do
    case names -- Enum.uniq(names) do
      [] -> :ok
      [dup | _] -> {:error, {:zod_duplicate_declaration, dup}}
    end
  end

  defp check_decls(decls, opts) do
    Enum.find_value(decls, :ok, fn {_name, expr} ->
      case expression(expr, opts) do
        :ok -> nil
        error -> error
      end
    end)
  end

  @doc """
  `:ok` when `text` is exactly one admitted zod expression.

  `identifiers: [name]` extends the grammar with a declared-identifier allowlist: each
  listed name (a plain ASCII identifier, never `z`) may appear as a value or as the root
  of a member chain (`Node.nullable()`), and an object property may be a zero-argument
  getter `get key() { return <expr> }` (zod 4 getter recursion). Identifiers not in the
  allowlist stay refused; with no allowlist the grammar is unchanged.
  """
  @spec expression(String.t(), keyword()) :: :ok | {:error, term()}
  def expression(text, opts \\ []) when is_binary(text) do
    ids = opts |> Keyword.get(:identifiers, []) |> MapSet.new()

    with :ok <- check_identifiers(ids),
         {:ok, tokens} <- tokenize(text, [], ids),
         {:ok, []} <- expr(tokens) do
      :ok
    else
      {:ok, [token | _]} -> {:error, {:zod_trailing_token, token}}
      {:error, _} = error -> error
    end
  end

  defp check_identifiers(ids) do
    case Enum.find(
           ids,
           &(not (is_binary(&1) and Regex.match?(~r/\A[A-Za-z_$][A-Za-z0-9_$]*\z/, &1) and
                    &1 != "z" and not dunder?(&1)))
         ) do
      nil -> :ok
      bad -> {:error, {:zod_bad_identifier, bad}}
    end
  end

  ## Tokenizer

  defp tokenize("", acc, _ids), do: {:ok, Enum.reverse(acc)}

  defp tokenize(text, acc, ids) do
    case Enum.find_value(@token_patterns, &match_token(&1, text)) do
      nil ->
        {:error, {:zod_unadmitted_text, String.slice(text, 0, 24)}}

      {:ws, lexeme} ->
        tokenize(
          binary_part(text, byte_size(lexeme), byte_size(text) - byte_size(lexeme)),
          acc,
          ids
        )

      {:regex, lexeme} ->
        case regex_flags(lexeme) do
          :ok ->
            rest = binary_part(text, byte_size(lexeme), byte_size(text) - byte_size(lexeme))
            tokenize(rest, [{:regex, lexeme} | acc], ids)

          {:error, _} = error ->
            error
        end

      {kind, lexeme} ->
        rest = binary_part(text, byte_size(lexeme), byte_size(text) - byte_size(lexeme))
        kind = if kind == :name and MapSet.member?(ids, lexeme), do: :ident, else: kind
        tokenize(rest, [{kind, lexeme} | acc], ids)
    end
  end

  @regex_flags ~c"dgimsuvy"

  defp regex_flags(lexeme) do
    flags = lexeme |> String.reverse() |> :binary.split("/") |> hd() |> String.reverse()
    chars = String.to_charlist(flags)

    cond do
      Enum.any?(chars, &(&1 not in @regex_flags)) -> {:error, {:zod_regex_flags, flags}}
      length(chars) != length(Enum.uniq(chars)) -> {:error, {:zod_regex_flags, flags}}
      true -> :ok
    end
  end

  defp match_token({kind, pattern}, text) do
    case Regex.run(pattern, text) do
      [lexeme | _] -> {kind, lexeme}
      nil -> nil
    end
  end

  ## Parser (recursive descent; returns the unconsumed tokens)

  defp expr([{:name, "z"} | rest]) do
    case rest do
      [{:punct, "."} | _] -> members(rest)
      _ -> {:error, :zod_bare_z}
    end
  end

  defp expr([{:ident, _} | rest]), do: ident_chain(rest)
  defp expr([token | _]), do: {:error, {:zod_expected_z, token}}
  defp expr([]), do: {:error, :zod_empty}

  # A declared identifier is a bare value or the root of a member chain.
  defp ident_chain([{:punct, "."} | _] = rest), do: members(rest)
  defp ident_chain(rest), do: {:ok, rest}

  defp members([{:punct, "."}, {:name, name} | rest]) do
    with :ok <- member_name(name),
         {:ok, rest} <- maybe_call(rest) do
      members(rest)
    end
  end

  defp members([{:punct, "."} | _]), do: {:error, :zod_expected_member_name}
  defp members(rest), do: {:ok, rest}

  defp member_name(name) do
    if name in @allowed_members and not dunder?(name),
      do: :ok,
      else: {:error, {:zod_denied_member, name}}
  end

  # Every `__`-prefixed member (`__proto__`, `__defineGetter__`,
  # `__lookupSetter__`, ...) is an engine/meta hook, never a zod method.
  defp dunder?(name), do: String.starts_with?(name, "__")

  defp maybe_call([{:punct, "("} | rest]), do: sequence(rest, ")", &value/1)
  defp maybe_call(rest), do: {:ok, rest}

  # Comma-separated items up to `close`, trailing comma admitted.
  defp sequence([{:punct, close} | rest], close, _item), do: {:ok, rest}

  defp sequence(tokens, close, item) do
    with {:ok, rest} <- item.(tokens) do
      case rest do
        [{:punct, ","}, {:punct, ^close} | rest] -> {:ok, rest}
        [{:punct, ","} | rest] -> sequence(rest, close, item)
        [{:punct, ^close} | rest] -> {:ok, rest}
        [token | _] -> {:error, {:zod_unexpected_token, token}}
        [] -> {:error, {:zod_unclosed, close}}
      end
    end
  end

  defp value([{:name, "z"} | _] = tokens), do: expr(tokens)
  defp value([{:ident, _} | rest]), do: ident_chain(rest)
  defp value([{:name, literal} | rest]) when literal in ~w(true false null), do: {:ok, rest}
  defp value([{:string, _} | rest]), do: {:ok, rest}
  defp value([{:number, _} | rest]), do: {:ok, rest}
  defp value([{:regex, _} | rest]), do: {:ok, rest}
  defp value([{:punct, "["} | rest]), do: sequence(rest, "]", &value/1)
  defp value([{:punct, "{"} | rest]), do: sequence(rest, "}", &property/1)
  defp value([token | _]), do: {:error, {:zod_unadmitted_value, token}}
  defp value([]), do: {:error, :zod_truncated}

  # `__proto__` as an object-literal key sets the prototype instead of a
  # property; a string key is compared by its decoded value so an escaped
  # spelling cannot slip past.
  # Getter property (zod 4 recursion): `get key() { return <expr>[;] }`.
  defp property([
         {:name, "get"},
         {kind, key},
         {:punct, "("},
         {:punct, ")"},
         {:punct, "{"},
         {:name, "return"} | rest
       ])
       when kind in [:name, :string] do
    name = key_value(kind, key)

    if dunder?(name) do
      {:error, {:zod_denied_key, key}}
    else
      with {:ok, rest} <- expr(rest) do
        case rest do
          [{:punct, ";"}, {:punct, "}"} | rest] -> {:ok, rest}
          [{:punct, "}"} | rest] -> {:ok, rest}
          [token | _] -> {:error, {:zod_unexpected_token, token}}
          [] -> {:error, :zod_truncated}
        end
      end
    end
  end

  defp property([{kind, key}, {:punct, ":"} | rest]) when kind in [:name, :string] do
    if key_value(kind, key) == "__proto__",
      do: {:error, {:zod_denied_key, key}},
      else: value(rest)
  end

  defp property([token | _]), do: {:error, {:zod_unadmitted_key, token}}
  defp property([]), do: {:error, :zod_truncated}

  defp key_value(:name, key), do: key
  # An undecodable string key (e.g. a lone surrogate escape) fails closed.
  defp key_value(:string, key) do
    case Jason.decode(key) do
      {:ok, decoded} -> decoded
      {:error, _} -> "__proto__"
    end
  end
end
