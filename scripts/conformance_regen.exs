# Regenerates the AshSurface conformance corpus (conformance/vectors/*.json and
# conformance/MANIFEST.json) from the REAL Elixir implementation.
#
#     MIX_ENV=test mix run scripts/conformance_regen.exs
#
# MIX_ENV=test is required only because the contract fixtures use the test-support
# Ash resource `AshSurface.Fixtures.VolunteerMilestone`.
#
# INPUTS are authored here; every EXPECTED value is produced by
# `AshSurface.Conformance.Runner` driving the public implementation — never
# typed by hand. Output is deterministic (no clocks, no randomness, canonical
# key-sorted JSON, one vector per line): re-running yields byte-identical files.

Code.require_file(Path.expand("../conformance/elixir/runner.exs", __DIR__))

defmodule ConformanceRegen do
  alias AshSurface.CanonicalJSON
  alias AshSurface.Conformance.Runner
  alias AshSurface.IR
  alias AshSurface.IR.Codec

  @root Path.expand("..", __DIR__)
  @out Path.join(@root, "conformance/vectors")

  @transports ["http", "phoenix_channel"]
  @abbr %{"http" => "h", "phoenix_channel" => "c"}

  def main do
    File.mkdir_p!(@out)
    Enum.each(Path.wildcard(Path.join(@out, "*.json")), &File.rm!/1)

    files = [
      {"transport_selection", transport_selection()},
      {"transport_facts_admission", transport_facts_admission()},
      {"canonical_json", canonical_json()},
      {"surface_contract_digest", surface_contract_digest()},
      {"surface_contract_refusal", surface_contract_refusal()},
      {"receipt_digest", receipt_digest()},
      {"receipt_binding", receipt_binding()},
      {"refusal_vocabulary", refusal_vocabulary()},
      {"reconcile_status", reconcile_status()},
      {"ir_codec", ir_codec()},
      {"transport_outcome", transport_outcome()}
    ]

    entries =
      for {kind, vectors} <- files do
        ids = Enum.map(vectors, & &1["id"])
        if ids != Enum.uniq(ids), do: raise("duplicate vector ids in #{kind}")
        vectors = Enum.map(vectors, &realize(kind, &1))
        write_file(kind, vectors)
      end

    manifest = %{
      "corpus" => "ash_surface-conformance",
      "corpusVersion" => Runner.corpus_version(),
      "hashAlgorithm" => "sha256",
      "lawVersion" => AshSurface.schema_version(),
      "vectorCount" => entries |> Enum.map(& &1["vectorCount"]) |> Enum.sum(),
      "files" => entries
    }

    File.write!(
      Path.join(@root, "conformance/MANIFEST.json"),
      CanonicalJSON.encode(manifest) <> "\n"
    )

    IO.puts("conformance: #{manifest["vectorCount"]} vectors in #{length(entries)} files")
  end

  # -- vector plumbing --------------------------------------------------------------

  defp v(id, description, input, notes \\ "", level \\ "MUST"),
    do: %{
      "id" => id,
      "description" => description,
      "input" => input,
      "notes" => notes,
      "level" => level
    }

  defp realize(kind, vector) do
    input = Runner.jsonify(vector["input"])
    Map.put(vector, "input", input) |> Map.put("expected", Runner.run(kind, input))
  end

  defp write_file(kind, vectors) do
    path = Path.join(@out, kind <> ".json")

    body =
      Enum.map_join(vectors, ",\n", fn vector -> "  " <> CanonicalJSON.encode(vector) end)

    header =
      ~s({"corpusVersion":#{Jason.encode!(Runner.corpus_version())},"kind":#{Jason.encode!(kind)},"vectors":[\n)

    bytes = header <> body <> "\n]}\n"
    File.write!(path, bytes)

    %{
      "path" => "vectors/" <> kind <> ".json",
      "kind" => kind,
      "levels" => vectors |> Enum.frequencies_by(& &1["level"]),
      "vectorCount" => length(vectors),
      "sha256" => :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
    }
  end

  # -- transport_selection -------------------------------------------------------------

  defp facts_scenarios do
    h = "http"
    c = "phoenix_channel"

    [
      {"none", nil},
      {"null", %{"transportFacts" => nil}},
      {"allnil", %{"transportFacts" => %{h => %{"cost" => nil}, c => %{}}}},
      {"cost-h-low", %{"transportFacts" => %{h => %{"cost" => "low"}, c => %{"cost" => "high"}}}},
      {"cost-c-low", %{"transportFacts" => %{h => %{"cost" => "high"}, c => %{"cost" => "low"}}}},
      {"cost-tie-medium",
       %{"transportFacts" => %{h => %{"cost" => "medium"}, c => %{"cost" => "medium"}}}},
      {"cost-medium-vs-low",
       %{"transportFacts" => %{h => %{"cost" => "medium"}, c => %{"cost" => "low"}}}},
      {"latency-only",
       %{"transportFacts" => %{h => %{"latency" => "high"}, c => %{"latency" => "low"}}}},
      {"conflict-cost-vs-latency",
       %{
         "transportFacts" => %{
           h => %{"cost" => "low", "latency" => "high"},
           c => %{"cost" => "high", "latency" => "low"}
         }
       }},
      {"privacy-higher-wins",
       %{"transportFacts" => %{h => %{"privacy" => "low"}, c => %{"privacy" => "high"}}}},
      {"partial-only-h", %{"transportFacts" => %{h => %{"cost" => "low"}}}},
      {"all-medium-tie",
       %{
         "transportFacts" => %{
           h => %{"cost" => "medium", "latency" => "medium", "privacy" => "medium"},
           c => %{"cost" => "medium", "latency" => "medium", "privacy" => "medium"}
         }
       }},
      {"dominance-via-privacy",
       %{
         "transportFacts" => %{
           h => %{"cost" => "medium", "latency" => "low", "privacy" => "low"},
           c => %{"cost" => "medium", "latency" => "low", "privacy" => "high"}
         }
       }}
    ]
  end

  defp ordered_sublists(declared) do
    subsets = for mask <- 0..(Integer.pow(2, length(declared)) - 1), do: subset(declared, mask)
    subsets |> Enum.flat_map(&permutations/1) |> Enum.uniq()
  end

  defp subset(list, mask),
    do:
      list
      |> Enum.with_index()
      |> Enum.filter(fn {_x, i} -> Bitwise.band(mask, Bitwise.bsl(1, i)) != 0 end)
      |> Enum.map(&elem(&1, 0))

  defp permutations([]), do: [[]]
  defp permutations(list), do: for(x <- list, rest <- permutations(list -- [x]), do: [x | rest])

  defp abbr(list), do: list |> Enum.map(&Map.fetch!(@abbr, &1)) |> Enum.join(",")

  defp transport_selection do
    declared_sets = [["http"], ["phoenix_channel"], @transports, Enum.reverse(@transports)]

    exhaustive =
      for declared <- declared_sets,
          available <- ordered_sublists(declared),
          preferred <- @transports,
          {facts_name, profile} <- facts_scenarios() do
        input =
          %{
            "actionId" => "Conformance.Resource#act",
            "declared" => declared,
            "available" => available,
            "preferred" => preferred
          }
          |> then(&if(profile, do: Map.put(&1, "profile", profile), else: &1))

        order_parametric? =
          declared == Enum.reverse(@transports) or
            Enum.filter(declared, &(&1 in available)) != available

        v(
          "ts/d=#{abbr(declared)}/a=#{abbr(available)}/p=#{@abbr[preferred]}/f=#{facts_name}",
          "exhaustive small space: declared [#{abbr(declared)}], available [#{abbr(available)}], preferred #{preferred}, facts #{facts_name}",
          input,
          "Exhaustive-table row." <>
            if(order_parametric?,
              do:
                " Order-parametric (declared order [phoenix_channel, http], or available order differing from declared): MAY, required only of projections that let a caller state those orders.",
              else: ""
            ),
          if(order_parametric?, do: "MAY", else: "MUST")
        )
      end

    both = @transports

    base = %{
      "actionId" => "Conformance.Resource#act",
      "declared" => both,
      "available" => both,
      "preferred" => "http"
    }

    edges = [
      v(
        "ts/edge/empty-available",
        "no available transport is a typed refusal",
        %{base | "available" => []},
        "kind unsupported_transport"
      ),
      v(
        "ts/edge/empty-declared-empty-available",
        "empty declared and available",
        %{base | "declared" => [], "available" => []},
        "kind unsupported_transport"
      ),
      v(
        "ts/edge/duplicate-declared",
        "duplicate declared transport is refused, never deduplicated",
        %{base | "declared" => ["http", "http"], "available" => ["http"]}
      ),
      v("ts/edge/duplicate-available", "duplicate available transport is refused", %{
        base
        | "available" => ["http", "http"]
      }),
      v("ts/edge/unknown-declared", "unknown declared transport", %{
        base
        | "declared" => ["http", "smoke_signal"],
          "available" => ["http"]
      }),
      v("ts/edge/unknown-declared-only", "single unknown declared transport", %{
        base
        | "declared" => ["smoke_signal"],
          "available" => []
      }),
      v("ts/edge/unknown-available", "unknown available transport", %{
        base
        | "available" => ["smoke_signal"]
      }),
      v("ts/edge/unadmitted-available", "available outside declared", %{
        base
        | "declared" => ["http"],
          "available" => ["http", "phoenix_channel"]
      }),
      v("ts/edge/unknown-preferred", "unknown preferred transport", %{
        base
        | "preferred" => "carrier_pigeon"
      }),
      v(
        "ts/edge/no-action-id",
        "action id is carried verbatim; absent stays null",
        Map.delete(base, "actionId"),
        "JS clients always have an action id"
      ),
      v(
        "ts/edge/unknown-dimension",
        "unknown dimension name is refused",
        Map.put(base, "profile", %{"transportFacts" => %{"http" => %{"bandwidth" => "low"}}})
      ),
      v(
        "ts/edge/unknown-class",
        "unknown dimension class is refused",
        Map.put(base, "profile", %{"transportFacts" => %{"http" => %{"cost" => "free"}}})
      ),
      v(
        "ts/edge/unknown-facts-transport",
        "facts for an unknown transport are refused",
        Map.put(base, "profile", %{"transportFacts" => %{"smoke_signal" => %{"cost" => "low"}}})
      ),
      v(
        "ts/edge/facts-not-a-map",
        "transportFacts must be a map",
        Map.put(base, "profile", %{"transportFacts" => ["http"]})
      ),
      v(
        "ts/edge/transport-facts-not-a-map",
        "per-transport facts must be a map",
        Map.put(base, "profile", %{"transportFacts" => %{"http" => "low"}})
      ),
      v(
        "ts/edge/preference-never-picks-dominated",
        "preferred phoenix_channel is dominated on cost: frontier best wins",
        Map.merge(base, %{
          "preferred" => "phoenix_channel",
          "profile" => %{
            "transportFacts" => %{
              "http" => %{"cost" => "low", "latency" => "low"},
              "phoenix_channel" => %{"cost" => "high", "latency" => "low"}
            }
          }
        })
      ),
      v(
        "ts/edge/facts-for-unavailable",
        "facts on an unavailable transport do not resurrect it",
        Map.merge(base, %{
          "declared" => both,
          "available" => ["http"],
          "profile" => %{
            "transportFacts" => %{
              "http" => %{"cost" => "high"},
              "phoenix_channel" => %{"cost" => "low"}
            }
          }
        })
      )
    ]

    exhaustive ++ edges
  end

  defp transport_facts_admission do
    [
      v("tf/absent", "absent transportFacts is not delegated (empty), never defaulted", %{
        "profile" => %{}
      }),
      v("tf/null", "null transportFacts is not delegated", %{
        "profile" => %{"transportFacts" => nil}
      }),
      v("tf/http-cost-privacy", "binary-key facts normalize", %{
        "profile" => %{"transportFacts" => %{"http" => %{"cost" => "low", "privacy" => "high"}}}
      }),
      v("tf/nil-dimension-dropped", "nil-valued dimension is dropped as not delegated", %{
        "profile" => %{"transportFacts" => %{"http" => %{"cost" => nil, "latency" => "medium"}}}
      }),
      v("tf/empty-transport", "transport with no facts", %{
        "profile" => %{"transportFacts" => %{"phoenix_channel" => %{}}}
      }),
      v("tf/unknown-class", "unknown class refused", %{
        "profile" => %{"transportFacts" => %{"http" => %{"cost" => "free"}}}
      }),
      v("tf/unknown-dimension", "unknown dimension refused", %{
        "profile" => %{"transportFacts" => %{"http" => %{"speed" => "low"}}}
      }),
      v("tf/unknown-transport", "unknown transport refused", %{
        "profile" => %{"transportFacts" => %{"smtp" => %{"cost" => "low"}}}
      }),
      v("tf/facts-not-map", "facts must be a map", %{"profile" => %{"transportFacts" => "http"}}),
      v("tf/dimensions-not-map", "dimensions must be a map", %{
        "profile" => %{"transportFacts" => %{"http" => ["cost"]}}
      }),
      v(
        "tf/profile-not-map",
        "profile must be a map",
        %{"profile" => "http"},
        "JS clients always hold a profile record; NOT_APPLICABLE there."
      ),
      v("tf/class-case-sensitive", "class names are case sensitive", %{
        "profile" => %{"transportFacts" => %{"http" => %{"cost" => "LOW"}}}
      })
    ]
  end

  # -- canonical_json ------------------------------------------------------------------

  defp canonical_json do
    cases = [
      {"key-order", "keys sort ascending", ~s({"b":1,"a":2,"c":{"z":1,"y":2}})},
      {"key-order-reversed-twin", "insertion-order twin of key-order encodes identically",
       ~s({"c":{"y":2,"z":1},"a":2,"b":1})},
      {"list-order-semantic", "list order is preserved", ~s({"l":[3,1,2,{"b":1,"a":2}]})},
      {"empty-containers", "empty map and list", ~s({"m":{},"l":[],"n":null})},
      {"scalars", "null/true/false", ~s([null,true,false])},
      {"unicode-bmp", "non-ASCII is emitted verbatim (not \\u escaped)",
       ~s({"é":"héllo ✓","σ":"Σ"})},
      {"unicode-astral", "astral characters verbatim", ~s({"k":"🜂 \u{1F702}"})},
      {"key-sort-utf8-bytes",
       "UTF-8 byte order == code point order: U+FF5E (BMP) sorts BEFORE U+1F702 (astral)",
       ~s({"\u{1F702}":1,"～":2,"z":3})},
      {"key-sort-uppercase-first",
       "byte order: uppercase before lowercase, digits before letters",
       ~s({"a":1,"B":2,"1":3,"_":4})},
      {"key-sort-prefix", "shorter key sorts before its extension", ~s({"ab":1,"a":2,"abc":3})},
      {"escapes-control", "control characters are escaped",
       ~s({"s":"a\\n\\t\\r\\b\\f\\u0001\\u001f"})},
      {"escapes-quote-backslash", "quote and backslash escape", ~s({"s":"q\\"b\\\\"})},
      {"slash-not-escaped", "solidus is not escaped", ~s({"s":"a/b</script>"})},
      {"del-and-line-separators", "DEL and U+2028/2029 emitted verbatim",
       ~s({"s":"\\u007f\\u2028\\u2029"})},
      {"ints", "integers", ~s([0,-1,1,255,256,-2147483649,2147483648])},
      {"safe-int-ceiling", "2^53-1 is portable",
       ~s({"n":9007199254740991,"m":-9007199254740991})},
      {"non-integral-floats", "floats with a fractional part and short repr",
       ~s([0.125,-0.5,1.5,3.14159])},
      {"deep-nesting", "deeply nested mixed structure", ~s({"a":[{"b":[{"c":[1,{"d":null}]}]}]})},
      {"string-numbers-not-numbers", "numeric strings stay strings", ~s({"n":"1","m":"1.0"})}
    ]

    lexical = [
      {"duplicate-keys",
       "duplicate object keys are parser-defined (RFC 8259 leaves them undefined)",
       ~s({"a":1,"a":2})},
      {"integral-float",
       "1.0 keeps its float spelling in Elixir; JSON has no int/float distinction",
       ~s({"n":1.0})},
      {"integral-float-large", "100000.0", ~s({"n":100000.0})},
      {"exponent-float", "1e21 spelling is runtime-specific", ~s({"n":1e21})},
      {"small-exponent-float", "1.0e-7 spelling is runtime-specific", ~s({"n":1.0e-7})},
      {"beyond-safe-int", "integers beyond 2^53 are exact in Elixir, lossy in IEEE-754 parsers",
       ~s({"n":9007199254740993})},
      {"negative-zero-float", "-0.0", ~s({"n":-0.0})}
    ]

    Enum.map(cases, fn {name, desc, json} -> v("cj/#{name}", desc, %{"json" => json}) end) ++
      Enum.map(lexical, fn {name, desc, json} ->
        v(
          "cj/lexical/#{name}",
          desc,
          %{"json" => json},
          "Parser- or number-model-dependent canonical bytes (int/float distinction, float spelling, integers beyond 2^53, duplicate keys). The Elixir result is recorded; a projection whose parser or number model differs must declare a known divergence rather than certify.",
          "PENDING_DECISION"
        )
      end)
  end

  # -- surface contracts -----------------------------------------------------------------

  @vm "AshSurface.Fixtures.VolunteerMilestone"
  defp read_ep, do: %{"resource" => @vm, "action" => "read", "type" => "read"}
  defp record_ep, do: %{"resource" => @vm, "action" => "record", "type" => "create"}

  defp gen_contract(name, description, generation, notes \\ "", level \\ "MUST") do
    {:ok, surface} = Runner.build_surface(generation)

    v(
      "sc/#{name}",
      description,
      %{"contract" => surface.contract, "generation" => generation},
      notes,
      level
    )
  end

  defp surface_contract_digest do
    kiosk = %{
      "consumer" => "kiosk",
      "nλ" => 1,
      "glyphs" => ["α", "ω", "✓"],
      "ratio" => 0.125,
      "ok" => true,
      "gap" => nil,
      "floor" => -2_147_483_649
    }

    delegated = %{
      "audience" => "operators",
      "actions" => %{
        "#{@vm}#record" => %{
          "consumer" => "kiosk",
          "possibleRefusals" => ["REFUSED_NO_AUTHORITY", "REFUSED_GENERATOR_OWNED"],
          "quota" => 9_007_199_254_740_991
        }
      }
    }

    facts_profile = %{
      "actions" => %{
        "#{@vm}#record" => %{
          "transport" => "auto",
          "transportFacts" => %{
            "http" => %{"cost" => "low", "latency" => "medium"},
            "phoenix_channel" => %{"cost" => "high", "privacy" => "high"}
          },
          "evidenceRequired" => true
        }
      }
    }

    {:ok, c2} =
      Runner.build_surface(%{"entrypoints" => [read_ep(), record_ep()], "profile" => delegated})

    tampered_action =
      update_in(c2.contract, ["surface", "actions"], fn [first | rest] ->
        [put_in(first, ["profile", "consumer"], "tampered") | rest]
      end)

    tampered_manifest = put_in(c2.contract, ["manifest", "extra"], "smuggled")
    reordered = update_in(c2.contract, ["surface", "actions"], &Enum.reverse/1)

    [
      gen_contract("empty-manifest-profile", "empty manifest with a profile", %{
        "entrypoints" => [],
        "profile" => %{"tier" => "gold"}
      }),
      gen_contract("empty-manifest-empty-profile", "empty manifest, empty profile", %{
        "entrypoints" => []
      }),
      gen_contract(
        "c1-read-utf8-profile",
        "read-only contract, UTF-8 profile keys and numeric boundaries",
        %{"entrypoints" => [read_ep()], "profile" => kiosk}
      ),
      gen_contract("c2-read-record-delegated", "read+record with per-action delegated profile", %{
        "entrypoints" => [read_ep(), record_ep()],
        "profile" => delegated
      }),
      gen_contract(
        "c2-entrypoint-order-twin",
        "entrypoints supplied in the other order",
        %{"entrypoints" => [record_ep(), read_ep()], "profile" => delegated},
        "Digest identity must not depend on manifest construction order."
      ),
      gen_contract("c3-transport-facts", "action profile carrying delegated transportFacts", %{
        "entrypoints" => [read_ep(), record_ep()],
        "profile" => facts_profile
      }),
      v(
        "sc/tamper-action-profile",
        "one profile field changed after minting: digest MUST change",
        %{"contract" => tampered_action},
        "No generation: digest = canonical digest of the given contract."
      ),
      v("sc/tamper-manifest-smuggle", "extra manifest key: digest MUST change", %{
        "contract" => tampered_manifest
      }),
      v(
        "sc/action-list-order-semantic",
        "action list order is semantic content: reversing it changes the digest",
        %{"contract" => reordered}
      ),
      gen_contract(
        "lexical-integral-float",
        "profile value 2.0 (float) vs 2 (integer) digest differently in Elixir",
        %{"entrypoints" => [], "profile" => %{"ratio" => 2.0}},
        "JavaScript cannot represent 2.0 distinctly from 2, so its ETF twin digests the integer.",
        "PENDING_DECISION"
      )
    ]
  end

  defp surface_contract_refusal do
    [
      v("scr/unknown-action-profile", "profile keyed by an unknown action id", %{
        "generation" => %{"entrypoints" => [], "profile" => %{"actions" => %{"Nope#x" => %{}}}}
      }),
      v("scr/bad-refusal-code", "possibleRefusals must be REFUSED_-prefixed", %{
        "generation" => %{
          "entrypoints" => [read_ep()],
          "profile" => %{"actions" => %{"#{@vm}#read" => %{"possibleRefusals" => ["NOPE"]}}}
        }
      }),
      v("scr/bare-refused", "bare REFUSED is not a refusal code", %{
        "generation" => %{
          "entrypoints" => [read_ep()],
          "profile" => %{"actions" => %{"#{@vm}#read" => %{"possibleRefusals" => ["REFUSED"]}}}
        }
      }),
      v("scr/empty-reason-refused", "REFUSED_ with an empty reason is not a refusal code", %{
        "generation" => %{
          "entrypoints" => [read_ep()],
          "profile" => %{"actions" => %{"#{@vm}#read" => %{"possibleRefusals" => ["REFUSED_"]}}}
        }
      }),
      v("scr/refusals-not-strings", "possibleRefusals must be strings", %{
        "generation" => %{
          "entrypoints" => [read_ep()],
          "profile" => %{"actions" => %{"#{@vm}#read" => %{"possibleRefusals" => [1]}}}
        }
      }),
      v("scr/evidence-not-boolean", "evidenceRequired must be boolean", %{
        "generation" => %{
          "entrypoints" => [read_ep()],
          "profile" => %{"actions" => %{"#{@vm}#read" => %{"evidenceRequired" => "yes"}}}
        }
      }),
      v(
        "scr/unknown-dispatch-outcome-is-not-refusal",
        "UNKNOWN_AFTER_DISPATCH is a dispatch outcome, not a possible refusal",
        %{
          "generation" => %{
            "entrypoints" => [read_ep()],
            "profile" => %{
              "actions" => %{"#{@vm}#read" => %{"possibleRefusals" => ["UNKNOWN_AFTER_DISPATCH"]}}
            }
          }
        }
      ),
      v("scr/profile-not-map", "profile must be a map", %{
        "generation" => %{"entrypoints" => [], "profile" => "gold"}
      })
    ]
  end

  # -- receipts ---------------------------------------------------------------------------

  @covered ~w(actionId input consequence dispatchState selectedTransport timestamp)

  defp base_receipt do
    %{
      "actionId" => "#{@vm}#record",
      "input" => %{
        "member_id" => "m-1",
        "milestone_id" => "ms-9",
        "cost_physical" => 5,
        "reward_spiritual" => 10
      },
      "consequence" => %{"status" => "completed", "score" => 1.5},
      "dispatchState" => "applied",
      "selectedTransport" => "http",
      "timestamp" => "2026-09-17T06:30:00.000Z",
      "sequence" => 3
    }
  end

  defp minted(receipt) do
    hash = receipt |> Map.take(@covered) |> CanonicalJSON.sha256_hex()
    Map.put(receipt, "receiptHash", hash)
  end

  defp receipt_digest do
    payload = base_receipt() |> Map.take(@covered)

    twin =
      payload
      |> Map.to_list()
      |> Enum.reverse()
      |> then(
        &("{" <>
            Enum.map_join(&1, ",", fn {k, val} ->
              Jason.encode!(k) <> ":" <> CanonicalJSON.encode(val)
            end) <> "}")
      )

    [
      v(
        "rd/r1-runtime-shaped",
        "receipt hash law: sha256 of canonical JSON of the covered sections",
        %{"payloadJson" => Jason.encode!(payload)}
      ),
      v(
        "rd/r2-insertion-order-twin",
        "same content, reversed key order in the text: same digest",
        %{"payloadJson" => twin}
      ),
      v("rd/r3-unicode-action", "unicode action id and glyph input", %{
        "payloadJson" =>
          ~s({"actionId":"Σ🜂#witness","input":{"glyph":"✓"},"consequence":{"seen":true},"dispatchState":"applied","selectedTransport":"phoenix_channel","timestamp":"2026-09-17T06:30:00.000Z"})
      }),
      v("rd/r4-null-sections", "absent covered sections hash as null", %{
        "payloadJson" =>
          ~s({"actionId":"A#b","input":null,"consequence":null,"dispatchState":null,"selectedTransport":null,"timestamp":null})
      }),
      v(
        "rd/lexical-float-consequence",
        "consequence value 2.0 hashes with its float spelling",
        %{
          "payloadJson" =>
            ~s({"actionId":"A#b","input":{},"consequence":{"score":2.0},"dispatchState":"applied","selectedTransport":"http","timestamp":"2026-09-17T06:30:00.000Z"})
        },
        "A JavaScript runtime that parses and re-serializes the receipt mints 2, not 2.0: the receipts disagree. Elixir refuses such a receipt (REFUSED_RECEIPT_DIGEST_MISMATCH).",
        "PENDING_DECISION"
      )
    ]
  end

  defp receipt_binding do
    base = minted(base_receipt())
    alt_hash = base["receiptHash"]

    tamper = fn key, value -> Map.put(base, key, value) end

    bad_ts =
      Map.put(base_receipt(), "timestamp", "2026-09-17T07:30:00.000Z")
      |> Map.put("receiptHash", alt_hash)

    [
      v("rb/ok-bound", "receiptHash binds the covered sections: event projected, OBSERVE only", %{
        "receipt" => base
      }),
      v(
        "rb/ok-noncovered-field-changes",
        "fields outside the covered set do not affect binding",
        %{"receipt" => Map.merge(base, %{"commandId" => "cmd_other", "extra" => %{"a" => 1}})}
      ),
      v("rb/ok-receiptref-slot", "digest carried in receiptRef is bound as well", %{
        "receipt" => base |> Map.delete("receiptHash") |> Map.put("receiptRef", alt_hash)
      }),
      v(
        "rb/ok-do-authority-still-observe",
        "DO-authority receipt back-projects to an OBSERVE event",
        %{"receipt" => Map.merge(base, %{"doAuthority" => true, "authorityBoundary" => "DO"})}
      ),
      v("rb/ok-ir-subject-iri", "IR semantic.subject_iri wins the subject", %{
        "receipt" => base,
        "irAction" => %{
          "resource" => "R",
          "action" => "a",
          "semantic" => %{"subject_iri" => "zoe:KingdomNeed#need_42"}
        }
      }),
      v("rb/ok-ir-resource-action-fallback", "ash:<resource>#<action> fallback", %{
        "receipt" => base,
        "irAction" => %{"resource" => "AshSurfaceTest.Post", "action" => "create"}
      }),
      v("rb/ok-unicode-action", "unicode action id", %{
        "receipt" => minted(%{base_receipt() | "actionId" => "Σ🜂#witness"})
      }),
      v(
        "rb/ok-opaque-git-sha",
        "40-char git sha in receiptHash is an opaque reference, carried verbatim",
        %{"receipt" => tamper.("receiptHash", String.duplicate("a", 40))}
      ),
      v("rb/ok-opaque-63", "63-byte value is not digest-shaped: carried verbatim", %{
        "receipt" => tamper.("receiptHash", String.duplicate("a", 63))
      }),
      v("rb/ok-opaque-65", "65-byte value is not digest-shaped: carried verbatim", %{
        "receipt" => tamper.("receiptHash", String.duplicate("a", 65))
      }),
      v("rb/ok-no-digest", "no digest at all: receipt_ref is null", %{
        "receipt" => Map.delete(base, "receiptHash")
      }),
      v("rb/tamper-consequence", "consequence changed after minting", %{
        "receipt" => tamper.("consequence", %{"status" => "completed", "score" => 99})
      }),
      v("rb/tamper-input", "input changed after minting", %{
        "receipt" => tamper.("input", %{"member_id" => "m-2"})
      }),
      v("rb/tamper-transport", "selectedTransport changed after minting", %{
        "receipt" => tamper.("selectedTransport", "phoenix_channel")
      }),
      v("rb/tamper-dispatch-state", "dispatchState changed after minting", %{
        "receipt" => tamper.("dispatchState", "unknown_after_dispatch")
      }),
      v("rb/tamper-action-id", "actionId changed after minting", %{
        "receipt" => tamper.("actionId", "Other#action")
      }),
      v("rb/tamper-timestamp", "timestamp changed (still parseable) after minting", %{
        "receipt" => bad_ts
      }),
      v("rb/tamper-uppercase-digest", "uppercase hex fails to bind (fail closed)", %{
        "receipt" => tamper.("receiptHash", String.upcase(alt_hash))
      }),
      v("rb/tamper-zero-digest", "digest-shaped but arbitrary", %{
        "receipt" => tamper.("receiptHash", String.duplicate("0", 64))
      }),
      v("rb/tamper-receiptref-slot", "tampered digest moved to receiptRef still refuses", %{
        "receipt" =>
          base
          |> Map.delete("receiptHash")
          |> Map.merge(%{"receiptRef" => String.duplicate("0", 64)})
      }),
      v(
        "rb/tamper-second-slot",
        "valid receiptHash plus digest-shaped wrong receiptRef refuses",
        %{"receipt" => Map.put(base, "receiptRef", String.duplicate("f", 64))}
      ),
      v("rb/refuse-missing-timestamp", "no timestamp: REFUSED_MISSING_TIMESTAMP", %{
        "receipt" => Map.delete(base_receipt(), "timestamp")
      }),
      v("rb/refuse-unparseable-timestamp", "unparseable timestamp", %{
        "receipt" => Map.put(base_receipt(), "timestamp", "yesterday")
      }),
      v("rb/refuse-no-subject", "no resolvable subject: REFUSED_INVALID_SUBJECT", %{
        "receipt" => Map.delete(base_receipt(), "actionId")
      }),
      v("rb/ok-blank-subject-iri-falls-back", "blank subject_iri falls back to the action id", %{
        "receipt" => base,
        "irAction" => %{"semantic" => %{"subject_iri" => "  "}}
      }),
      v("rb/refuse-malformed-ir-action", "non-map irAction", %{
        "receipt" => base,
        "irAction" => "AshSurfaceTest.Post#create"
      }),
      v("rb/refuse-malformed-ir-semantic", "non-map semantic section", %{
        "receipt" => base,
        "irAction" => %{"semantic" => "x"}
      }),
      v(
        "rb/order-subject-before-digest",
        "refusal order: subject refuses before digest binding",
        %{"receipt" => base |> Map.delete("actionId")}
      ),
      v(
        "rb/order-timestamp-before-digest",
        "refusal order: timestamp refuses before digest binding",
        %{"receipt" => Map.delete(base, "timestamp")}
      ),
      v("rb/order-subject-before-timestamp", "refusal order: subject refuses before timestamp", %{
        "receipt" => base_receipt() |> Map.delete("actionId") |> Map.delete("timestamp")
      }),
      v(
        "rb/lexical-float-consequence",
        "float-valued consequence binds under the Elixir float spelling",
        %{"receipt" => minted(%{base_receipt() | "consequence" => %{"score" => 2.0}})},
        "Elixir mints/binds over \"2.0\"; a JS-minted receipt of the same value hashes \"2\".",
        "PENDING_DECISION"
      )
    ]
  end

  # -- refusal vocabulary -------------------------------------------------------------------

  defp refusal_vocabulary do
    strings = [
      {"named", "REFUSED_NO_AUTHORITY", "canonical named refusal"},
      {"named-lower-reason", "REFUSED_x", "reason case is free"},
      {"named-unicode-reason", "REFUSED_ÉTAT", "non-ASCII reason"},
      {"named-double-underscore", "REFUSED__", "underscore-only reason is still a reason"},
      {"bare", "REFUSED", "bare REFUSED names no reason: not a standing"},
      {"prefix-only", "REFUSED_", "empty reason: not a refusal"},
      {"lowercase", "refused_x", "prefix is case sensitive"},
      {"leading-space", " REFUSED_X", "no trimming"},
      {"trailing-space-reason", "REFUSED_X ", "trailing space is part of the reason"},
      {"space-reason", "REFUSED_ ", "a space is a (non-empty) reason"},
      {"base-alive", "ALIVE", "base standing: valid, not refused"},
      {"base-partial", "PARTIAL_ALIVE", "base standing"},
      {"base-blocked", "BLOCKED", "base standing"},
      {"base-build-broken", "BUILD_BROKEN", "base standing"},
      {"base-unsupported", "UNSUPPORTED", "base standing"},
      {"unknown", "UNKNOWN", "UNKNOWN is not a standing"},
      {"unknown-after-dispatch", "UNKNOWN_AFTER_DISPATCH", "a dispatch outcome, not a standing"},
      {"success-outcome", "SUCCESS", "a dispatch outcome, not a standing"},
      {"alive-lowercase", "alive", "standings are case sensitive"},
      {"empty", "", "empty string"},
      {"bogus", "BOGUS", "not in the vocabulary"}
    ]

    multiline = [
      {"newline-reason", "REFUSED_\nX", "reason begins with a newline"},
      {"cr-reason", "REFUSED_\r", "reason is a carriage return"},
      {"ls-reason", "REFUSED_\u2028", "reason is U+2028"},
      {"newline-only-reason", "REFUSED_\n", "reason is only a newline"},
      {"trailing-newline-reason", "REFUSED_X\nY", "newline after a first reason char"}
    ]

    nonstrings = [
      {"null", nil, "null"},
      {"number", 42, "number"},
      {"true", true, "boolean"},
      {"list", ["REFUSED_X"], "list"}
    ]

    Enum.map(strings, fn {n, s, d} -> v("rv/#{n}", d, %{"value" => s}) end) ++
      Enum.map(multiline, fn {n, s, d} ->
        v(
          "rv/multiline/#{n}",
          d,
          %{"value" => s},
          "Reason characters include line terminators; regex `.` does not match them without a dotall flag."
        )
      end) ++ Enum.map(nonstrings, fn {n, s, d} -> v("rv/nonstring/#{n}", d, %{"value" => s}) end)
  end

  # -- reconcile status ----------------------------------------------------------------------

  defp reconcile_status do
    [
      {"completed", %{"status" => "COMPLETED"}},
      {"not-observed", %{"status" => "NOT_OBSERVED"}},
      {"still-unknown", %{"status" => "STILL_UNKNOWN"}},
      {"passthrough-keys",
       %{"status" => "COMPLETED", "receipt" => %{"a" => 1}, "commandId" => "cmd_1"}},
      {"lowercase", %{"status" => "completed"}},
      {"unknown-status", %{"status" => "PENDING"}},
      {"success-is-not-a-status", %{"status" => "SUCCESS"}},
      {"unknown-after-dispatch-is-not-a-status", %{"status" => "UNKNOWN_AFTER_DISPATCH"}},
      {"padded", %{"status" => " COMPLETED"}},
      {"null-status", %{"status" => nil}},
      {"number-status", %{"status" => 1}},
      {"missing-status", %{"receipt" => %{}}},
      {"empty-object", %{}},
      {"list-verdict", ["COMPLETED"]},
      {"string-verdict", "COMPLETED"},
      {"null-verdict", nil}
    ]
    |> Enum.map(fn {name, verdict} ->
      v("rs/#{name}", "reconcile reply admission: #{name}", %{"verdict" => verdict})
    end)
  end

  # -- IR codec -----------------------------------------------------------------------------

  defp full_ir do
    %IR{
      version: "26.9.17",
      ash: %IR.Ash{
        resource: "Conformance.Post",
        action: "read",
        action_type: "read",
        inputs: [%{"name" => "id", "required" => true, "type" => "uuid"}],
        outputs: %{"fields" => ["id", "body"]},
        policies: [%{"name" => "can_read", "type" => "allow"}]
      },
      semantic: %IR.Semantic{
        subject_iri: "https://ash.surface/i/user",
        capability_iri: "https://ash.surface/c/post#read",
        shape_id: "shape:post:read:v1",
        ontology: "dfcm",
        predicates: %{"describes" => "post", "grants" => "observe"}
      },
      capability: %IR.Capability{
        capability_id: "cap:post:read",
        consequence_class: "OBSERVE",
        authority_required: false,
        receipt_required: true
      },
      presentation: %IR.Presentation{
        format: "compact",
        group: "content",
        label: "Posts",
        order: 1,
        widget: "table"
      },
      schema: %IR.Schema{
        aria: %{"label" => "Posts", "role" => "table"},
        input: %{"type" => "object", "properties" => %{"id" => %{"type" => "string"}}},
        output: %{"type" => "object", "properties" => %{"body" => %{"type" => "string"}}},
        zod: "z.object({ id: z.string().uuid() })"
      }
    }
  end

  defp ir_codec do
    full = full_ir() |> Codec.to_map() |> Runner.jsonify()
    sparse = %IR{} |> Codec.to_map() |> Runner.jsonify()

    presentation_only =
      %IR{presentation: %IR.Presentation{label: "Dumb screen"}}
      |> Codec.to_map()
      |> Runner.jsonify()

    false_leaves =
      %IR{capability: %IR.Capability{authority_required: false, receipt_required: false}}
      |> Codec.to_map()
      |> Runner.jsonify()

    empty_sections =
      %IR{presentation: %IR.Presentation{}, ash: %IR.Ash{}} |> Codec.to_map() |> Runner.jsonify()

    [
      v(
        "ir/full",
        "fully populated five-section IR",
        %{"map" => full},
        "Input is the canonical map; digest is over the same map."
      ),
      v("ir/sparse-all-nil", "all sections nil: null, never a fabricated empty map", %{
        "map" => sparse
      }),
      v("ir/presentation-only", "single present section, nil fields as null", %{
        "map" => presentation_only
      }),
      v("ir/false-leaves", "false leaves survive the round trip (not dropped as nil)", %{
        "map" => false_leaves
      }),
      v("ir/empty-present-sections", "present-but-empty sections differ from nil sections", %{
        "map" => empty_sections
      }),
      v(
        "ir/nil-vs-empty-digest-differs",
        "sparse vs empty-present digests differ (see ir/sparse-all-nil, ir/empty-present-sections)",
        %{"map" => Map.put(sparse, "ash", empty_sections["ash"])}
      ),
      v("ir/unknown-top-level-key-ignored", "forward tolerance: unknown top-level key ignored", %{
        "map" => Map.put(full, "futureSection", %{"x" => 1})
      }),
      v(
        "ir/carried-digest-ignored",
        "a carried digest is ignored in favor of the recomputed one",
        %{"map" => Map.put(full, "digest", String.duplicate("0", 64))}
      ),
      v(
        "ir/unknown-section-field-ignored",
        "forward tolerance: unknown section-internal field ignored",
        %{"map" => put_in(full, ["ash", "futureField"], "x")}
      ),
      v("ir/unicode-and-list-order", "list order is semantic; unicode preserved", %{
        "map" =>
          full
          |> put_in(["ash", "inputs"], [%{"name" => "z"}, %{"name" => "a"}])
          |> put_in(["presentation", "label"], "Σ🜂✓")
      }),
      v("ir/version-nil", "version may be null", %{"map" => Map.put(full, "version", nil)}),
      v("ir/missing-sections", "missing section keys are typed-rejected", %{
        "map" => Map.drop(full, ["ash", "schema"])
      }),
      v("ir/version-not-string", "version must be string or null", %{
        "map" => Map.put(full, "version", 26)
      }),
      v("ir/section-not-map", "section must be map or null", %{
        "map" => Map.put(full, "ash", "read")
      }),
      v("ir/section-list", "section as a list is rejected", %{
        "map" => Map.put(full, "semantic", [1])
      }),
      v("ir/not-a-map", "IR input must be a map", %{"map" => ["ash"]}),
      v("ir/deep-nested-values", "deep nested JSON leaves inside a section field", %{
        "map" =>
          put_in(full, ["schema", "input"], %{
            "a" => [1, 2.5, "x", nil, true, false, %{"b" => []}]
          })
      }),
      v("ir/safe-int-boundary", "safe-integer boundary inside a section field", %{
        "map" => put_in(full, ["presentation", "order"], 9_007_199_254_740_991)
      }),
      v("ir/negative-and-int32-boundaries", "int32 boundaries in an ETF-sensitive field", %{
        "map" => put_in(full, ["presentation", "order"], -2_147_483_649)
      })
    ]
  end

  # -- transport outcome -----------------------------------------------------------------------

  defp transport_outcome do
    base = %{
      "actionId" => "Conformance.Resource#act",
      "declared" => @transports,
      "available" => @transports,
      "preferred" => "http"
    }

    pre = ~w(signal_aborted_before_dispatch invalid_command_id invalid_timeout)
    post = ~w(adapter_rejected deadline_exceeded abort_after_dispatch)

    Enum.map(pre, fn cause ->
      v(
        "to/pre/#{cause}",
        "failure before dispatch: nothing sent, fallback still open",
        Map.merge(base, %{"phase" => "pre_dispatch", "cause" => cause}),
        "Pre-dispatch refusal: no receipt of a dispatch, no dispatch outcome."
      )
    end) ++
      Enum.map(post, fn cause ->
        v(
          "to/post/#{cause}",
          "failure after dispatch: UNKNOWN_AFTER_DISPATCH, fallback closed, no replay over another transport",
          Map.merge(base, %{"phase" => "post_dispatch", "cause" => cause}),
          "The alternate admitted transport MUST NOT be invoked."
        )
      end) ++
      [
        v(
          "to/pre/no-available-transport",
          "no available transport is a typed pre-dispatch refusal",
          Map.merge(base, %{
            "phase" => "pre_dispatch",
            "cause" => "no_available_transport",
            "available" => []
          })
        ),
        v(
          "to/pre/fallback-to-declared-alternative",
          "preferred transport unavailable: pre-dispatch fallback to the other admitted one is lawful",
          Map.merge(base, %{
            "phase" => "pre_dispatch",
            "cause" => "adapter_unavailable",
            "available" => ["phoenix_channel"]
          })
        ),
        v(
          "to/post/after-fallback",
          "post-dispatch failure after a pre-dispatch fallback still closes fallback",
          Map.merge(base, %{
            "phase" => "post_dispatch",
            "cause" => "adapter_rejected",
            "available" => ["phoenix_channel"]
          })
        )
      ]
  end
end

ConformanceRegen.main()
