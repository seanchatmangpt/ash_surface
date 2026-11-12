defmodule AshSurface.Adversarial.S2 do
  @moduledoc false
  # Shared harness for lane S2 courts: real node + real zod, seeded :rand.
  alias AshSurface.Projectors.JS.ZodGuard

  @nasty [
    "plain",
    "a\"b",
    "back\\slash",
    "line\nbreak",
    "cr\rret",
    "sep\u2028x",
    "para\u2029y",
    "__proto__",
    "constructor",
    "toString",
    "hasOwnProperty",
    "héllo",
    "名前",
    "emoji😀",
    "a-b",
    "1abc",
    "with space",
    "$",
    "a.b",
    "tab\tx",
    "nul\u0000x",
    "'single'",
    "</script>",
    "${x}",
    "`tick`"
  ]

  def nasty, do: @nasty

  @doc "Seeded RNG: returns the list of `n` distinct names drawn with `seed`."
  def names(seed, n) do
    :rand.seed(:exsss, {seed, seed, seed})
    pool = @nasty ++ for(_ <- 1..8, do: rand_name())
    pool |> Enum.uniq() |> Enum.reject(&(&1 == "__proto__")) |> Enum.shuffle() |> Enum.take(n)
  end

  def rand_name do
    alphabet = ~c"abcXYZ_$\"\\\n é名😀 -.0"
    len = :rand.uniform(6)
    for(_ <- 1..len, into: "", do: <<Enum.random(alphabet)::utf8>>)
  end

  def node!, do: System.find_executable("node") || raise("REQUIRED TOOL MISSING: node")

  @doc """
  Evaluates each `{id, expr, payloads}` under real zod in ONE node process.
  Returns `%{id => {:throw, msg} | [boolean]}`.
  """
  def eval(items) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "s2_#{System.unique_integer([:positive])}_#{System.pid()}_#{Base.url_encode64(:crypto.strong_rand_bytes(6), padding: false)}"
      )

    File.mkdir_p!(dir)
    File.ln_s!(Path.join(File.cwd!(), "node_modules"), Path.join(dir, "node_modules"))

    body =
      items
      |> Enum.with_index()
      |> Enum.map_join("\n", fn {{_id, expr, payloads}, i} ->
        """
        try {
          const S = #{expr};
          out[#{i}] = JSON.parse(#{Jason.encode!(Jason.encode!(payloads))}).map((p) => S.safeParse(p).success);
        } catch (e) { out[#{i}] = {throw: String(e && e.message || e)}; }
        """
      end)

    File.write!(Path.join(dir, "run.mjs"), """
    import { z } from "zod";
    const out = [];
    #{body}
    process.stdout.write(JSON.stringify(out));
    """)

    {raw, 0} = System.cmd(node!(), ["run.mjs"], cd: dir, stderr_to_stdout: true)
    File.rm_rf!(dir)
    res = Jason.decode!(raw)

    items
    |> Enum.zip(res)
    |> Map.new(fn {{id, _, _}, r} ->
      {id, if(is_map(r), do: {:throw, r["throw"]}, else: r)}
    end)
  end

  @doc """
  Classifies one rendered expression against `cases` (`[{payload, expect}]`).
  Returns :refused (renderer typed error), {:guard_refused, reason},
  {:node_throw, msg}, :agree, or {:disagree, [{payload, expect, got}]}.
  """
  def classify(rendered, cases) do
    case rendered do
      {:ok, expr} -> classify_expr(expr, cases)
      {:error, _} -> :refused
    end
  end

  def classify_expr(expr, cases) do
    case ZodGuard.admit(expr) do
      {:ok, _, _} ->
        [res] = eval([{0, expr, Enum.map(cases, &elem(&1, 0))}]) |> Map.values()

        case res do
          {:throw, msg} ->
            {:node_throw, msg}

          got ->
            bad =
              cases
              |> Enum.zip(got)
              |> Enum.reject(fn {{_, e}, g} -> e == g end)
              |> Enum.map(fn {{p, e}, g} -> {p, e, g} end)

            if bad == [], do: :agree, else: {:disagree, bad}
        end

      {:error, reason} ->
        {:guard_refused, reason}
    end
  end
end
