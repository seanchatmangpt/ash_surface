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
  no template literals, no regex literals and no comments; the member names
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

  The guard confines the text syntactically; it does not (and cannot) prove
  what a given zod method does at runtime.
  """

  @denied_members ~w(constructor prototype call apply bind)

  @program ~r/\Aexport const ([A-Za-z0-9_]+)_inputSchema = (.+?);\n\nexport const \1_outputSchema = (.+?);\n\z/s

  @token_patterns [
    {:ws, ~r/\A[ \t\r\n]+/},
    {:string, ~r/\A"(?:[^"\\\x00-\x1f]|\\["\\\/bfnrt]|\\u[0-9a-fA-F]{4})*"/},
    {:number, ~r/\A-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?/},
    {:name, ~r/\A[A-Za-z_$][A-Za-z0-9_$]*/},
    {:punct, ~r/\A[.(),\[\]{}:]/}
  ]

  @doc """
  Admits `zod` source text. Returns `{:ok, :expression, zod}` for an admitted
  expression (embedded byte-verbatim), `{:ok, :program, input_expr}` for an
  admitted compiled program, and `{:error, reason}` otherwise.
  """
  @spec admit(String.t()) ::
          {:ok, :expression | :program, String.t()} | {:error, term()}
  def admit(zod) when is_binary(zod) do
    case Regex.run(@program, zod, capture: :all_but_first) do
      [_name, input, output] ->
        with :ok <- expression(input), :ok <- expression(output) do
          {:ok, :program, input}
        end

      nil ->
        with :ok <- expression(zod), do: {:ok, :expression, zod}
    end
  end

  def admit(other), do: {:error, {:zod_not_a_string, other}}

  @doc "`:ok` when `text` is exactly one admitted zod expression."
  @spec expression(String.t()) :: :ok | {:error, term()}
  def expression(text) when is_binary(text) do
    with {:ok, tokens} <- tokenize(text, []),
         {:ok, []} <- expr(tokens) do
      :ok
    else
      {:ok, [token | _]} -> {:error, {:zod_trailing_token, token}}
      {:error, _} = error -> error
    end
  end

  ## Tokenizer

  defp tokenize("", acc), do: {:ok, Enum.reverse(acc)}

  defp tokenize(text, acc) do
    case Enum.find_value(@token_patterns, &match_token(&1, text)) do
      nil ->
        {:error, {:zod_unadmitted_text, String.slice(text, 0, 24)}}

      {:ws, lexeme} ->
        tokenize(binary_part(text, byte_size(lexeme), byte_size(text) - byte_size(lexeme)), acc)

      {kind, lexeme} ->
        rest = binary_part(text, byte_size(lexeme), byte_size(text) - byte_size(lexeme))
        tokenize(rest, [{kind, lexeme} | acc])
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

  defp expr([token | _]), do: {:error, {:zod_expected_z, token}}
  defp expr([]), do: {:error, :zod_empty}

  defp members([{:punct, "."}, {:name, name} | rest]) do
    with :ok <- member_name(name),
         {:ok, rest} <- maybe_call(rest) do
      members(rest)
    end
  end

  defp members([{:punct, "."} | _]), do: {:error, :zod_expected_member_name}
  defp members(rest), do: {:ok, rest}

  defp member_name(name) do
    if name in @denied_members or dunder?(name),
      do: {:error, {:zod_denied_member, name}},
      else: :ok
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
  defp value([{:name, literal} | rest]) when literal in ~w(true false null), do: {:ok, rest}
  defp value([{:string, _} | rest]), do: {:ok, rest}
  defp value([{:number, _} | rest]), do: {:ok, rest}
  defp value([{:punct, "["} | rest]), do: sequence(rest, "]", &value/1)
  defp value([{:punct, "{"} | rest]), do: sequence(rest, "}", &property/1)
  defp value([token | _]), do: {:error, {:zod_unadmitted_value, token}}
  defp value([]), do: {:error, :zod_truncated}

  # `__proto__` as an object-literal key sets the prototype instead of a
  # property; a string key is compared by its decoded value so an escaped
  # spelling cannot slip past.
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
