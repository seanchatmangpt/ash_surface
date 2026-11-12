defmodule AshSurface.Ported.Rpc.A.InputParsingStressSurfaceTest do
  @moduledoc """
  Non-actuating counterpart of `rpc/input_parsing_stress_test.exs`. Each test drives the real
  request through `Rpc.parse/1` (client names -> internal Elixir names, asserted on
  `request.input`) and then runs the action result - a hand-built real
  `AshSurface.Ported.InputParsing.Resource` record (no data layer) - through the result
  processor + formatter (internal names -> client names, asserted on the envelope).

  Divergences from the reference (ash_surface lawful behavior is asserted):
    * parsed input for tuple / keyword NewTypes is the cast-ready shape: tuple -> Elixir tuple,
      keyword NewType -> map keyed by internal atoms.
    * the union tag is injected for tagged members (`content_type: "data"` even when the client
      sent none); union input is unwrapped by the input formatter: the member key is dropped and the member
      value (with its tag) is passed to the Ash cast (`%{content_type: "text", ...}`); simple
      members are passed as the bare value.
    * `validate_action` has no in-process counterpart; validation is the parse stage, so the
      `input validation` tests assert `{:ok, request}` with the mapped input.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.InputParsing, as: IP
  alias AshSurface.Ported.Rpc

  @id "44444444-4444-4444-4444-444444444444"

  defp record(attrs), do: struct(IP.Resource, Keyword.merge([id: @id], attrs))
  defp union(type, value), do: %Ash.Union{type: type, value: value}

  defp parse!(action, input, fields) do
    assert {:ok, request} =
             Rpc.parse(%{"action" => action, "input" => input, "fields" => fields})

    request
  end

  defp run(action, input, fields, result) do
    Rpc.run(%{"action" => action, "input" => input, "fields" => fields}, result)
  end

  defp base_input(name),
    do: %{"userName" => name, "emailAddress" => "#{name}@example.com"}

  defp base_attrs(name), do: [user_name: name, email_address: "#{name}@example.com"]

  describe "standard snake_case field input parsing" do
    test "creates resource with snake_case fields formatted as camelCase" do
      input = %{"userName" => "test_user", "emailAddress" => "test@example.com"}
      fields = ["id", "userName", "emailAddress"]

      assert parse!("create_input_parsing", input, fields).input ==
               %{user_name: "test_user", email_address: "test@example.com"}

      result =
        run(
          "create_input_parsing",
          input,
          fields,
          record(user_name: "test_user", email_address: "test@example.com")
        )

      assert %{"success" => true, "data" => data} = result
      assert data["userName"] == "test_user"
      assert data["emailAddress"] == "test@example.com"
      refute Map.has_key?(data, "user_name")
    end

    test "updates resource with snake_case fields formatted as camelCase" do
      input = %{"userName" => "updated_user", "displayName" => "Updated Display"}
      fields = ["id", "userName", "displayName"]

      request =
        parse!("update_input_parsing", input, fields)

      assert request.input == %{user_name: "updated_user", display_name: "Updated Display"}

      result =
        Rpc.run(
          %{
            "action" => "update_input_parsing",
            "identity" => @id,
            "input" => input,
            "fields" => fields
          },
          record(user_name: "updated_user", display_name: "Updated Display")
        )

      assert %{"success" => true, "data" => data} = result
      assert data["id"] == @id
      assert data["userName"] == "updated_user"
      assert data["displayName"] == "Updated Display"
    end
  end

  describe "DSL field_names mapping input parsing" do
    test "creates resource with mapped field names (? suffix)" do
      input = Map.merge(base_input("test_user"), %{"isActive" => false, "hasData" => true})
      fields = ["id", "userName", "isActive", "hasData"]

      assert parse!("create_input_parsing", input, fields).input ==
               %{
                 user_name: "test_user",
                 email_address: "test_user@example.com",
                 is_active?: false,
                 has_data?: true
               }

      result =
        run(
          "create_input_parsing",
          input,
          fields,
          record(base_attrs("test_user") ++ [is_active?: false, has_data?: true])
        )

      assert %{"success" => true, "data" => data} = result
      assert data["isActive"] == false
      assert data["hasData"] == true
      refute Map.has_key?(data, "is_active?")
    end

    test "creates resource with mapped field names (numeric suffix)" do
      input = Map.put(base_input("test_user"), "version1", 42)
      fields = ["id", "userName", "version1"]

      assert parse!("create_input_parsing", input, fields).input.version_1 == 42

      result =
        run(
          "create_input_parsing",
          input,
          fields,
          record(base_attrs("test_user") ++ [version_1: 42])
        )

      assert %{"success" => true, "data" => data} = result
      assert data["version1"] == 42
      refute Map.has_key?(data, "version_1")
    end
  end

  describe "DSL argument_names mapping input parsing" do
    test "search action with mapped argument names" do
      input = %{"query" => "searchable", "includeDeleted" => false, "filterBy1" => true}
      fields = ["id", "userName"]

      assert parse!("search_input_parsing", input, fields).input ==
               %{query: "searchable", include_deleted?: false, filter_by_1?: true}

      result =
        run("search_input_parsing", input, fields, [
          record(user_name: "searchable_user", email_address: "search@example.com")
        ])

      assert %{"success" => true, "data" => data} = result
      assert is_list(data)
      assert [%{"id" => @id, "userName" => "searchable_user"}] = data
    end

    test "create_with_args action with mapped argument names" do
      input = Map.merge(base_input("args_test_user"), %{"isUrgent" => true, "priority1" => 5})
      fields = ["id", "userName"]

      assert parse!("create_input_parsing_with_args", input, fields).input ==
               %{
                 user_name: "args_test_user",
                 email_address: "args_test_user@example.com",
                 is_urgent?: true,
                 priority_1: 5
               }

      result =
        run("create_input_parsing_with_args", input, fields, record(base_attrs("args_test_user")))

      assert %{"success" => true, "data" => data} = result
      assert data["userName"] == "args_test_user"
    end
  end

  describe "typed map field constraint input parsing" do
    test "creates resource with typed map (snake_case constraint fields)" do
      settings = %{"notificationEnabled" => true, "themeName" => "dark", "retryCount" => 3}
      input = Map.put(base_input("settings_user"), "settings", settings)
      fields = ["id", %{"settings" => ["notificationEnabled", "themeName", "retryCount"]}]

      assert parse!("create_input_parsing", input, fields).input.settings ==
               %{notification_enabled: true, theme_name: "dark", retry_count: 3}

      result =
        run(
          "create_input_parsing",
          input,
          fields,
          record(settings: %{notification_enabled: true, theme_name: "dark", retry_count: 3})
        )

      assert %{"success" => true, "data" => data} = result
      assert data["settings"]["notificationEnabled"] == true
      assert data["settings"]["themeName"] == "dark"
      assert data["settings"]["retryCount"] == 3
    end
  end

  describe "NewType with typescript_field_names callback input parsing" do
    test "creates resource with NewType stats (mapped fields)" do
      stats = %{
        "totalCount1" => 100,
        "isComplete" => true,
        "lastUpdatedAt" => "2025-01-15T10:30:00Z"
      }

      input = Map.put(base_input("stats_user"), "stats", stats)
      fields = ["id", %{"stats" => ["totalCount1", "isComplete", "lastUpdatedAt"]}]

      assert parse!("create_input_parsing", input, fields).input.stats ==
               %{
                 total_count_1: 100,
                 is_complete?: true,
                 last_updated_at: "2025-01-15T10:30:00Z"
               }

      result =
        run(
          "create_input_parsing",
          input,
          fields,
          record(
            stats: %{
              total_count_1: 100,
              is_complete?: true,
              last_updated_at: ~U[2025-01-15 10:30:00Z]
            }
          )
        )

      assert %{"success" => true, "data" => data} = result
      assert data["stats"]["totalCount1"] == 100
      assert data["stats"]["isComplete"] == true
      assert Map.has_key?(data["stats"], "lastUpdatedAt")
    end

    test "generic action with NewType argument (InputDataMap)" do
      input = %{"inputData" => %{"itemName" => "Test Item", "isValid" => true}}
      fields = ["processed", "resultCount"]

      assert parse!("process_data_input_parsing", input, fields).input ==
               %{input_data: %{item_name: "Test Item", is_valid?: true}}

      result =
        run("process_data_input_parsing", input, fields, %{processed: true, result_count: 1})

      assert %{"success" => true, "data" => data} = result
      assert data["processed"] == true
      assert data["resultCount"] == 1
    end

    test "generic action with NewType options argument" do
      input = %{
        "inputData" => %{"itemName" => "Test Item"},
        "options" => %{"cacheEnabled1" => true, "retryLimit" => 5}
      }

      fields = ["processed", "resultCount"]

      assert parse!("process_data_input_parsing", input, fields).input ==
               %{
                 input_data: %{item_name: "Test Item"},
                 options: %{cache_enabled_1?: true, retry_limit: 5}
               }

      result =
        run("process_data_input_parsing", input, fields, %{processed: true, result_count: 1})

      assert %{"success" => true, "data" => data} = result
      assert data["processed"] == true
    end
  end

  describe "embedded resource input parsing" do
    test "creates resource with embedded resource (Profile)" do
      profile = %{
        "displayName" => "Test Profile",
        "bioText1" => "This is my bio",
        "isPublic" => false,
        "followerCount" => 42
      }

      input = Map.put(base_input("profile_user"), "profileData", profile)

      fields = [
        "id",
        %{"profileData" => ["displayName", "bioText1", "isPublic", "followerCount"]}
      ]

      assert parse!("create_input_parsing", input, fields).input.profile_data ==
               %{
                 display_name: "Test Profile",
                 bio_text_1: "This is my bio",
                 is_public?: false,
                 follower_count: 42
               }

      result =
        run(
          "create_input_parsing",
          input,
          fields,
          record(
            profile_data:
              struct(IP.Profile,
                display_name: "Test Profile",
                bio_text_1: "This is my bio",
                is_public?: false,
                follower_count: 42
              )
          )
        )

      assert %{"success" => true, "data" => data} = result
      assert data["profileData"]["displayName"] == "Test Profile"
      assert data["profileData"]["bioText1"] == "This is my bio"
      assert data["profileData"]["isPublic"] == false
      assert data["profileData"]["followerCount"] == 42
    end
  end

  describe "array of embedded resources input parsing" do
    test "creates resource with array of embedded resources (HistoryEntry)" do
      history = [
        %{
          "actionName" => "create",
          "timestamp" => "2025-01-15T10:30:00Z",
          "changeCount1" => 5,
          "wasReverted" => false
        },
        %{
          "actionName" => "update",
          "timestamp" => "2025-01-15T11:00:00Z",
          "changeCount1" => 2,
          "wasReverted" => true
        }
      ]

      input = Map.put(base_input("history_user"), "history", history)

      fields = [
        "id",
        %{"history" => ["actionName", "timestamp", "changeCount1", "wasReverted"]}
      ]

      assert [first_in, second_in] = parse!("create_input_parsing", input, fields).input.history
      assert first_in.action_name == "create"
      assert first_in.change_count_1 == 5
      assert first_in.was_reverted? == false
      assert second_in.change_count_1 == 2
      assert second_in.was_reverted? == true

      result =
        run(
          "create_input_parsing",
          input,
          fields,
          record(
            history: [
              struct(IP.HistoryEntry,
                action_name: "create",
                timestamp: ~U[2025-01-15 10:30:00Z],
                change_count_1: 5,
                was_reverted?: false
              ),
              struct(IP.HistoryEntry,
                action_name: "update",
                timestamp: ~U[2025-01-15 11:00:00Z],
                change_count_1: 2,
                was_reverted?: true
              )
            ]
          )
        )

      assert %{"success" => true, "data" => data} = result
      assert length(data["history"]) == 2

      [first, second] = data["history"]
      assert first["actionName"] == "create"
      assert first["changeCount1"] == 5
      assert first["wasReverted"] == false

      assert second["actionName"] == "update"
      assert second["wasReverted"] == true
    end
  end

  describe "union type input parsing" do
    test "creates resource with union type - embedded resource member (text)" do
      content = %{
        "text" => %{
          "contentType" => "text",
          "body" => "This is the content body",
          "wordCount1" => 5,
          "isFormatted" => true
        }
      }

      input = Map.put(base_input("union_text_user"), "content", content)

      fields = [
        "id",
        %{"content" => [%{"text" => ["contentType", "body", "wordCount1", "isFormatted"]}]}
      ]

      assert parse!("create_input_parsing", input, fields).input.content ==
               %{
                 content_type: "text",
                 body: "This is the content body",
                 word_count_1: 5,
                 is_formatted?: true
               }

      result =
        run(
          "create_input_parsing",
          input,
          fields,
          record(
            content:
              union(
                :text,
                struct(IP.TextContent,
                  content_type: "text",
                  body: "This is the content body",
                  word_count_1: 5,
                  is_formatted?: true
                )
              )
          )
        )

      assert %{"success" => true, "data" => data} = result
      assert data["content"]["text"]["body"] == "This is the content body"
      assert data["content"]["text"]["wordCount1"] == 5
      assert data["content"]["text"]["isFormatted"] == true
    end

    test "creates resource with union type - NewType map member (data)" do
      content = %{"data" => %{"itemCount" => 42, "isCached" => true}}
      input = Map.put(base_input("union_data_user"), "content", content)
      fields = ["id", %{"content" => [%{"data" => ["itemCount", "isCached"]}]}]

      assert parse!("create_input_parsing", input, fields).input.content ==
               %{content_type: "data", item_count: 42, is_cached?: true}

      result =
        run(
          "create_input_parsing",
          input,
          fields,
          record(content: union(:data, %{item_count: 42, is_cached?: true}))
        )

      assert %{"success" => true, "data" => data} = result
      assert data["content"]["data"]["itemCount"] == 42
      assert data["content"]["data"]["isCached"] == true
    end

    test "creates resource with union type - simple type member (simpleValue)" do
      content = %{"simpleValue" => "Just a simple string value"}
      input = Map.put(base_input("union_simple_user"), "content", content)
      fields = ["id", %{"content" => ["simpleValue"]}]

      assert parse!("create_input_parsing", input, fields).input.content ==
               "Just a simple string value"

      result =
        run(
          "create_input_parsing",
          input,
          fields,
          record(content: union(:simple_value, "Just a simple string value"))
        )

      assert %{"success" => true, "data" => data} = result
      assert data["content"]["simpleValue"] == "Just a simple string value"
    end
  end

  describe "comprehensive input parsing" do
    test "creates resource with all field types combined" do
      input =
        Map.merge(base_input("comprehensive_user"), %{
          "displayName" => "Comprehensive Test User",
          "isActive" => true,
          "hasData" => true,
          "version1" => 10,
          "settings" => %{"notificationEnabled" => true, "themeName" => "light"},
          "stats" => %{"totalCount1" => 500, "isComplete" => false},
          "profileData" => %{
            "displayName" => "Main Profile",
            "bioText1" => "Main bio",
            "isPublic" => true
          },
          "history" => [
            %{
              "actionName" => "init",
              "timestamp" => "2025-01-15T00:00:00Z",
              "changeCount1" => 1,
              "wasReverted" => false
            }
          ],
          "content" => %{
            "text" => %{
              "contentType" => "text",
              "body" => "Full content",
              "wordCount1" => 2,
              "isFormatted" => false
            }
          }
        })

      fields = [
        "id",
        "userName",
        "emailAddress",
        "displayName",
        "isActive",
        "hasData",
        "version1",
        %{"settings" => ["notificationEnabled", "themeName"]},
        %{"stats" => ["totalCount1", "isComplete"]},
        %{"profileData" => ["displayName", "bioText1", "isPublic"]},
        %{"history" => ["actionName", "changeCount1", "wasReverted"]},
        %{"content" => [%{"text" => ["body", "wordCount1", "isFormatted"]}]}
      ]

      parsed = parse!("create_input_parsing", input, fields).input
      assert parsed.display_name == "Comprehensive Test User"
      assert parsed.is_active? == true
      assert parsed.has_data? == true
      assert parsed.version_1 == 10
      assert parsed.settings == %{notification_enabled: true, theme_name: "light"}
      assert parsed.stats == %{total_count_1: 500, is_complete?: false}
      assert parsed.profile_data.bio_text_1 == "Main bio"
      assert [%{change_count_1: 1, was_reverted?: false}] = parsed.history
      assert parsed.content.word_count_1 == 2

      result =
        run(
          "create_input_parsing",
          input,
          fields,
          record(
            base_attrs("comprehensive_user") ++
              [
                display_name: "Comprehensive Test User",
                is_active?: true,
                has_data?: true,
                version_1: 10,
                settings: %{notification_enabled: true, theme_name: "light"},
                stats: %{total_count_1: 500, is_complete?: false},
                profile_data:
                  struct(IP.Profile,
                    display_name: "Main Profile",
                    bio_text_1: "Main bio",
                    is_public?: true
                  ),
                history: [
                  struct(IP.HistoryEntry,
                    action_name: "init",
                    change_count_1: 1,
                    was_reverted?: false
                  )
                ],
                content:
                  union(
                    :text,
                    struct(IP.TextContent,
                      content_type: "text",
                      body: "Full content",
                      word_count_1: 2,
                      is_formatted?: false
                    )
                  )
              ]
          )
        )

      assert %{"success" => true, "data" => data} = result
      assert data["userName"] == "comprehensive_user"
      assert data["emailAddress"] == "comprehensive_user@example.com"
      assert data["displayName"] == "Comprehensive Test User"
      assert data["isActive"] == true
      assert data["hasData"] == true
      assert data["version1"] == 10
      assert data["settings"]["notificationEnabled"] == true
      assert data["stats"]["totalCount1"] == 500
      assert data["profileData"]["displayName"] == "Main Profile"
      assert length(data["history"]) == 1
      assert data["content"]["text"]["body"] == "Full content"
    end
  end

  describe "input validation" do
    test "validates action with mapped argument names" do
      request =
        parse!(
          "search_input_parsing",
          %{"query" => "test", "includeDeleted" => true, "filterBy1" => false},
          ["id"]
        )

      assert request.input == %{query: "test", include_deleted?: true, filter_by_1?: false}
    end

    test "validates resource creation with all mapped fields" do
      input =
        Map.merge(base_input("valid_user"), %{
          "isActive" => true,
          "hasData" => false,
          "version1" => 1
        })

      request = parse!("create_input_parsing", input, ["id"])

      assert request.input ==
               %{
                 user_name: "valid_user",
                 email_address: "valid_user@example.com",
                 is_active?: true,
                 has_data?: false,
                 version_1: 1
               }
    end
  end

  describe "tuple type with typescript_field_names input parsing" do
    test "creates resource with tuple (LocationTuple) having mapped fields" do
      location = %{"lat1" => 37.7749, "lng1" => -122.4194, "isVerified" => true}
      input = Map.put(base_input("tuple_user"), "location", location)
      fields = ["id", %{"location" => ["lat1", "lng1", "isVerified"]}]

      assert parse!("create_input_parsing", input, fields).input.location ==
               {37.7749, -122.4194, true}

      result =
        run(
          "create_input_parsing",
          input,
          fields,
          record(location: {37.7749, -122.4194, true})
        )

      assert %{"success" => true, "data" => data} = result
      assert data["location"]["lat1"] == 37.7749
      assert data["location"]["lng1"] == -122.4194
      assert data["location"]["isVerified"] == true
    end
  end

  describe "keyword type with typescript_field_names input parsing" do
    test "creates resource with keyword (PreferencesKeyword) having mapped fields" do
      prefs = %{"theme1" => "ocean", "fontSize" => 14, "isDarkMode" => true}
      input = Map.put(base_input("keyword_user"), "preferences", prefs)
      fields = ["id", %{"preferences" => ["theme1", "fontSize", "isDarkMode"]}]

      assert parse!("create_input_parsing", input, fields).input.preferences ==
               %{theme_1: "ocean", font_size: 14, is_dark_mode?: true}

      result =
        run(
          "create_input_parsing",
          input,
          fields,
          record(preferences: [theme_1: "ocean", font_size: 14, is_dark_mode?: true])
        )

      assert %{"success" => true, "data" => data} = result
      assert data["preferences"]["theme1"] == "ocean"
      assert data["preferences"]["fontSize"] == 14
      assert data["preferences"]["isDarkMode"] == true
    end
  end

  describe "deeply nested typed maps input parsing" do
    test "creates resource with nested typed maps (DeepNestedSettings)" do
      deep = %{
        "displayName" => "Main Settings",
        "isEnabled1" => true,
        "innerConfig" => %{"maxRetries1" => 5, "isCached" => true, "timeoutMs" => 3000}
      }

      input = Map.put(base_input("nested_map_user"), "deepSettings", deep)

      fields = [
        "id",
        %{
          "deepSettings" => [
            "displayName",
            "isEnabled1",
            %{"innerConfig" => ["maxRetries1", "isCached", "timeoutMs"]}
          ]
        }
      ]

      assert parse!("create_input_parsing", input, fields).input.deep_settings ==
               %{
                 display_name: "Main Settings",
                 is_enabled_1?: true,
                 inner_config: %{max_retries_1: 5, is_cached?: true, timeout_ms: 3000}
               }

      result =
        run(
          "create_input_parsing",
          input,
          fields,
          record(
            deep_settings: %{
              display_name: "Main Settings",
              is_enabled_1?: true,
              inner_config: %{max_retries_1: 5, is_cached?: true, timeout_ms: 3000}
            }
          )
        )

      assert %{"success" => true, "data" => data} = result
      assert data["deepSettings"]["displayName"] == "Main Settings"
      assert data["deepSettings"]["isEnabled1"] == true
      assert data["deepSettings"]["innerConfig"]["maxRetries1"] == 5
      assert data["deepSettings"]["innerConfig"]["isCached"] == true
      assert data["deepSettings"]["innerConfig"]["timeoutMs"] == 3000
    end
  end

  describe "3-level embedded resource nesting input parsing" do
    test "creates resource with 3-level nesting (NestedProfile → Profile)" do
      nested = %{
        "sectionName" => "Main Section",
        "level1" => true,
        "hasDetails" => true,
        "detailProfile" => %{
          "displayName" => "Detail Profile Name",
          "bioText1" => "Detailed bio text",
          "isPublic" => false,
          "followerCount" => 100
        },
        "detailStats" => %{"totalCount1" => 250, "isComplete" => true}
      }

      input = Map.put(base_input("deep_nesting_user"), "nestedProfile", nested)

      fields = [
        "id",
        %{
          "nestedProfile" => [
            "sectionName",
            "level1",
            "hasDetails",
            %{"detailProfile" => ["displayName", "bioText1", "isPublic", "followerCount"]},
            %{"detailStats" => ["totalCount1", "isComplete"]}
          ]
        }
      ]

      assert parse!("create_input_parsing", input, fields).input.nested_profile ==
               %{
                 section_name: "Main Section",
                 level_1?: true,
                 has_details?: true,
                 detail_profile: %{
                   display_name: "Detail Profile Name",
                   bio_text_1: "Detailed bio text",
                   is_public?: false,
                   follower_count: 100
                 },
                 detail_stats: %{total_count_1: 250, is_complete?: true}
               }

      result =
        run(
          "create_input_parsing",
          input,
          fields,
          record(
            nested_profile:
              struct(IP.NestedProfile,
                section_name: "Main Section",
                level_1?: true,
                has_details?: true,
                detail_profile:
                  struct(IP.Profile,
                    display_name: "Detail Profile Name",
                    bio_text_1: "Detailed bio text",
                    is_public?: false,
                    follower_count: 100
                  ),
                detail_stats: %{total_count_1: 250, is_complete?: true}
              )
          )
        )

      assert %{"success" => true, "data" => data} = result

      nested_out = data["nestedProfile"]
      assert nested_out["sectionName"] == "Main Section"
      assert nested_out["level1"] == true
      assert nested_out["hasDetails"] == true

      detail = nested_out["detailProfile"]
      assert detail["displayName"] == "Detail Profile Name"
      assert detail["bioText1"] == "Detailed bio text"
      assert detail["isPublic"] == false
      assert detail["followerCount"] == 100

      stats = nested_out["detailStats"]
      assert stats["totalCount1"] == 250
      assert stats["isComplete"] == true
    end
  end

  describe "union with :map_with_tag storage input parsing" do
    test "creates resource with map_with_tag union - active member" do
      tagged = %{
        "active" => %{
          "statusType" => "active",
          "message" => "Currently active",
          "isFinal" => false,
          "priority1" => 5
        }
      }

      input = Map.put(base_input("tagged_union_user"), "taggedStatus", tagged)

      fields = [
        "id",
        %{"taggedStatus" => [%{"active" => ["statusType", "message", "isFinal", "priority1"]}]}
      ]

      assert parse!("create_input_parsing", input, fields).input.tagged_status ==
               %{
                 status_type: "active",
                 message: "Currently active",
                 is_final?: false,
                 priority_1: 5
               }

      result =
        run(
          "create_input_parsing",
          input,
          fields,
          record(
            tagged_status:
              union(
                :active,
                struct(IP.TaggedStatus,
                  status_type: "active",
                  message: "Currently active",
                  is_final?: false,
                  priority_1: 5
                )
              )
          )
        )

      assert %{"success" => true, "data" => data} = result
      assert data["taggedStatus"]["active"]["statusType"] == "active"
      assert data["taggedStatus"]["active"]["message"] == "Currently active"
      assert data["taggedStatus"]["active"]["isFinal"] == false
      assert data["taggedStatus"]["active"]["priority1"] == 5
    end

    test "creates resource with map_with_tag union - inactive member" do
      tagged = %{
        "inactive" => %{
          "statusType" => "inactive",
          "message" => "Currently disabled",
          "isFinal" => true,
          "priority1" => 0
        }
      }

      input = Map.put(base_input("tagged_inactive_user"), "taggedStatus", tagged)

      fields = [
        "id",
        %{
          "taggedStatus" => [%{"inactive" => ["statusType", "message", "isFinal", "priority1"]}]
        }
      ]

      assert parse!("create_input_parsing", input, fields).input.tagged_status ==
               %{
                 status_type: "inactive",
                 message: "Currently disabled",
                 is_final?: true,
                 priority_1: 0
               }

      result =
        run(
          "create_input_parsing",
          input,
          fields,
          record(
            tagged_status:
              union(
                :inactive,
                struct(IP.TaggedStatus,
                  status_type: "inactive",
                  message: "Currently disabled",
                  is_final?: true,
                  priority_1: 0
                )
              )
          )
        )

      assert %{"success" => true, "data" => data} = result
      assert data["taggedStatus"]["inactive"]["statusType"] == "inactive"
      assert data["taggedStatus"]["inactive"]["message"] == "Currently disabled"
      assert data["taggedStatus"]["inactive"]["isFinal"] == true
      assert data["taggedStatus"]["inactive"]["priority1"] == 0
    end
  end

  describe "array of unions input parsing" do
    test "creates resource with array of unions having field_names" do
      attachments = [
        %{
          "file" => %{
            "attachmentType" => "file",
            "filename" => "document.pdf",
            "mimeType" => "application/pdf",
            "isPublic1" => true,
            "sizeBytes1" => 1024
          }
        },
        %{
          "link" => %{
            "attachmentType" => "link",
            "url" => "https://example.com",
            "title" => "Example Link",
            "isExternal1" => true,
            "clickCount1" => 42
          }
        },
        %{"note" => "This is a simple note attachment"}
      ]

      input = Map.put(base_input("array_union_user"), "attachments", attachments)

      fields = [
        "id",
        %{
          "attachments" => [
            %{"file" => ["filename", "mimeType", "isPublic1", "sizeBytes1"]},
            %{"link" => ["url", "title", "isExternal1", "clickCount1"]},
            "note"
          ]
        }
      ]

      assert [file_in, link_in, note_in] =
               parse!("create_input_parsing", input, fields).input.attachments

      assert file_in == %{
               attachment_type: "file",
               filename: "document.pdf",
               mime_type: "application/pdf",
               is_public_1?: true,
               size_bytes_1: 1024
             }

      assert link_in == %{
               attachment_type: "link",
               url: "https://example.com",
               title: "Example Link",
               is_external_1?: true,
               click_count_1: 42
             }

      assert note_in == "This is a simple note attachment"

      result =
        run(
          "create_input_parsing",
          input,
          fields,
          record(
            attachments: [
              union(
                :file,
                struct(IP.AttachmentFile,
                  attachment_type: "file",
                  filename: "document.pdf",
                  mime_type: "application/pdf",
                  is_public_1?: true,
                  size_bytes_1: 1024
                )
              ),
              union(
                :link,
                struct(IP.AttachmentLink,
                  attachment_type: "link",
                  url: "https://example.com",
                  title: "Example Link",
                  is_external_1?: true,
                  click_count_1: 42
                )
              ),
              union(:note, "This is a simple note attachment")
            ]
          )
        )

      assert %{"success" => true, "data" => data} = result
      assert length(data["attachments"]) == 3

      file_attachment = Enum.find(data["attachments"], &Map.has_key?(&1, "file"))
      link_attachment = Enum.find(data["attachments"], &Map.has_key?(&1, "link"))
      note_attachment = Enum.find(data["attachments"], &Map.has_key?(&1, "note"))

      assert file_attachment["file"]["filename"] == "document.pdf"
      assert file_attachment["file"]["isPublic1"] == true
      assert file_attachment["file"]["sizeBytes1"] == 1024

      assert link_attachment["link"]["url"] == "https://example.com"
      assert link_attachment["link"]["isExternal1"] == true
      assert link_attachment["link"]["clickCount1"] == 42

      assert note_attachment["note"] == "This is a simple note attachment"
    end
  end

  describe "generic action with embedded resource argument input parsing" do
    @profile_result %{profile_name: "Test Profile", is_processed?: true}

    test "processes embedded resource argument (Profile)" do
      input = %{
        "profile" => %{
          "displayName" => "Test Profile",
          "bioText1" => "Test bio content",
          "isPublic" => true,
          "followerCount" => 500
        }
      }

      fields = ["profileName", "isProcessed"]

      assert parse!("process_profile_input_parsing", input, fields).input ==
               %{
                 profile: %{
                   display_name: "Test Profile",
                   bio_text_1: "Test bio content",
                   is_public?: true,
                   follower_count: 500
                 }
               }

      result = run("process_profile_input_parsing", input, fields, @profile_result)

      assert %{"success" => true, "data" => data} = result
      assert data["profileName"] == "Test Profile"
      assert data["isProcessed"] == true
    end

    test "processes nested embedded resource argument (NestedProfile)" do
      input = %{
        "profile" => %{
          "displayName" => "Main Profile",
          "bioText1" => "Main bio",
          "isPublic" => true,
          "followerCount" => 100
        },
        "nested" => %{
          "sectionName" => "Nested Section",
          "level1" => true,
          "hasDetails" => false,
          "detailProfile" => %{
            "displayName" => "Inner Detail",
            "bioText1" => "Inner bio",
            "isPublic" => false,
            "followerCount" => 10
          }
        }
      }

      fields = ["profileName", "isProcessed"]
      parsed = parse!("process_profile_input_parsing", input, fields).input

      assert parsed.profile.bio_text_1 == "Main bio"

      assert parsed.nested == %{
               section_name: "Nested Section",
               level_1?: true,
               has_details?: false,
               detail_profile: %{
                 display_name: "Inner Detail",
                 bio_text_1: "Inner bio",
                 is_public?: false,
                 follower_count: 10
               }
             }

      result =
        run(
          "process_profile_input_parsing",
          input,
          fields,
          %{profile_name: "Main Profile", is_processed?: true}
        )

      assert %{"success" => true, "data" => data} = result
      assert data["profileName"] == "Main Profile"
      assert data["isProcessed"] == true
    end
  end

  describe "comprehensive exhaustive input test" do
    test "creates resource with ALL new field types combined" do
      input =
        Map.merge(base_input("exhaustive_test_user"), %{
          "isActive" => true,
          "version1" => 99,
          "location" => %{"lat1" => 51.5074, "lng1" => -0.1278, "isVerified" => true},
          "preferences" => %{"theme1" => "midnight", "fontSize" => 18, "isDarkMode" => true},
          "deepSettings" => %{
            "displayName" => "Deep Config",
            "isEnabled1" => true,
            "innerConfig" => %{"maxRetries1" => 10, "isCached" => true, "timeoutMs" => 5000}
          },
          "nestedProfile" => %{
            "sectionName" => "Exhaustive Section",
            "level1" => true,
            "hasDetails" => true,
            "detailProfile" => %{
              "displayName" => "Deep Detail",
              "bioText1" => "Deep bio",
              "isPublic" => true,
              "followerCount" => 999
            }
          },
          "taggedStatus" => %{
            "inactive" => %{
              "statusType" => "inactive",
              "message" => "Test inactive",
              "isFinal" => true,
              "priority1" => 0
            }
          },
          "attachments" => [
            %{
              "file" => %{
                "attachmentType" => "file",
                "filename" => "test.txt",
                "isPublic1" => true,
                "sizeBytes1" => 256
              }
            }
          ]
        })

      fields = [
        "id",
        "userName",
        "isActive",
        "version1",
        %{"location" => ["lat1", "lng1", "isVerified"]},
        %{"preferences" => ["theme1", "isDarkMode"]},
        %{"deepSettings" => ["isEnabled1", %{"innerConfig" => ["maxRetries1", "isCached"]}]},
        %{"nestedProfile" => ["level1", %{"detailProfile" => ["bioText1", "isPublic"]}]},
        %{"taggedStatus" => [%{"inactive" => ["isFinal", "priority1"]}]},
        %{"attachments" => [%{"file" => ["filename", "isPublic1"]}]}
      ]

      parsed = parse!("create_input_parsing", input, fields).input
      assert parsed.version_1 == 99
      assert parsed.location == {51.5074, -0.1278, true}
      assert parsed.preferences == %{theme_1: "midnight", font_size: 18, is_dark_mode?: true}
      assert parsed.deep_settings.inner_config.max_retries_1 == 10
      assert parsed.nested_profile.detail_profile.bio_text_1 == "Deep bio"
      assert parsed.tagged_status.is_final? == true
      assert [%{is_public_1?: true, size_bytes_1: 256}] = parsed.attachments

      result =
        run(
          "create_input_parsing",
          input,
          fields,
          record(
            base_attrs("exhaustive_test_user") ++
              [
                is_active?: true,
                version_1: 99,
                location: {51.5074, -0.1278, true},
                preferences: [theme_1: "midnight", font_size: 18, is_dark_mode?: true],
                deep_settings: %{
                  display_name: "Deep Config",
                  is_enabled_1?: true,
                  inner_config: %{max_retries_1: 10, is_cached?: true, timeout_ms: 5000}
                },
                nested_profile:
                  struct(IP.NestedProfile,
                    section_name: "Exhaustive Section",
                    level_1?: true,
                    has_details?: true,
                    detail_profile:
                      struct(IP.Profile,
                        display_name: "Deep Detail",
                        bio_text_1: "Deep bio",
                        is_public?: true,
                        follower_count: 999
                      )
                  ),
                tagged_status:
                  union(
                    :inactive,
                    struct(IP.TaggedStatus,
                      status_type: "inactive",
                      message: "Test inactive",
                      is_final?: true,
                      priority_1: 0
                    )
                  ),
                attachments: [
                  union(
                    :file,
                    struct(IP.AttachmentFile,
                      attachment_type: "file",
                      filename: "test.txt",
                      is_public_1?: true,
                      size_bytes_1: 256
                    )
                  )
                ]
              ]
          )
        )

      assert %{"success" => true, "data" => data} = result

      assert data["userName"] == "exhaustive_test_user"
      assert data["isActive"] == true
      assert data["version1"] == 99
      assert data["location"]["lat1"] == 51.5074
      assert data["location"]["isVerified"] == true
      assert data["preferences"]["theme1"] == "midnight"
      assert data["preferences"]["isDarkMode"] == true
      assert data["deepSettings"]["isEnabled1"] == true
      assert data["deepSettings"]["innerConfig"]["maxRetries1"] == 10
      assert data["deepSettings"]["innerConfig"]["isCached"] == true
      assert data["nestedProfile"]["level1"] == true
      assert data["nestedProfile"]["detailProfile"]["bioText1"] == "Deep bio"
      assert data["nestedProfile"]["detailProfile"]["isPublic"] == true
      assert data["taggedStatus"]["inactive"]["isFinal"] == true
      assert data["taggedStatus"]["inactive"]["priority1"] == 0

      [file_att] = data["attachments"]
      assert file_att["file"]["filename"] == "test.txt"
      assert file_att["file"]["isPublic1"] == true
    end
  end
end
