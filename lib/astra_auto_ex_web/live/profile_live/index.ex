defmodule AstraAutoExWeb.ProfileLive.Index do
  use AstraAutoExWeb, :live_view

  alias AstraAutoEx.Accounts

  @providers [
    %{
      id: "ark",
      name: "ARK",
      desc: "Doubao, Seedream, Seedance",
      has_base_url: false,
      default_base_url: nil,
      models: %{
        "llm" => [
          %{id: "doubao-seed-1.6-pro", name: "Doubao Seed 1.6 Pro"},
          %{id: "doubao-seed-1.8", name: "Doubao Seed 1.8"},
          %{id: "doubao-seed-2.0-pro", name: "Doubao Seed 2.0 Pro"}
        ],
        "image" => [
          %{id: "doubao-seedream-4-0", name: "Seedream 4.0"},
          %{id: "doubao-seedream-4-5", name: "Seedream 4.5"},
          %{id: "doubao-seedream-5-0-lite", name: "Seedream 5.0 Lite"}
        ],
        "video" => [
          %{id: "doubao-seedance-1-0-pro-fast", name: "Seedance 1.0 Pro Fast"},
          %{id: "doubao-seedance-1-5-pro", name: "Seedance 1.5 Pro"},
          %{id: "doubao-seedance-2-0", name: "Seedance 2.0"}
        ]
      }
    },
    %{
      id: "google",
      name: "Google",
      desc: "Gemini, Imagen, VEO",
      has_base_url: false,
      default_base_url: nil,
      models: %{
        "llm" => [
          %{id: "gemini-2.5-flash", name: "Gemini 2.5 Flash"},
          %{id: "gemini-2.5-pro", name: "Gemini 2.5 Pro"},
          %{id: "gemini-3-flash", name: "Gemini 3 Flash"},
          %{id: "gemini-3.1-pro-preview", name: "Gemini 3.1 Pro"}
        ],
        "image" => [
          %{id: "imagen-4.0-generate-001", name: "Imagen 4"},
          %{id: "nano-banana-pro", name: "Nano Banana Pro"},
          %{id: "nano-banana-2", name: "Nano Banana 2"}
        ],
        "video" => [
          %{id: "veo-2.0-generate-001", name: "Veo 2.0"},
          %{id: "veo-3.0-generate-preview", name: "Veo 3.0"},
          %{id: "veo-3.1-generate-preview", name: "Veo 3.1"}
        ]
      }
    },
    %{
      id: "minimax",
      name: "MiniMax",
      desc: "Hailuo, TTS, Music",
      has_base_url: true,
      default_base_url: "https://api.minimaxi.com/v1",
      models: %{
        "llm" => [
          %{id: "MiniMax-M2.7-highspeed", name: "M2.7 Highspeed"},
          %{id: "MiniMax-M2.7", name: "M2.7"},
          %{id: "MiniMax-M2.5", name: "M2.5"}
        ],
        "image" => [%{id: "image-01", name: "Image-01"}],
        "video" => [
          %{id: "minimax-hailuo-2.3", name: "Hailuo 2.3"},
          %{id: "minimax-hailuo-2.3-fast", name: "Hailuo 2.3 Fast"}
        ],
        "audio" => [
          %{id: "speech-2.8-hd", name: "Speech 2.8 HD"},
          %{id: "speech-2.8-turbo", name: "Speech 2.8 Turbo"}
        ],
        "music" => [%{id: "music-2.6", name: "Music 2.6"}]
      }
    },
    %{
      id: "fal",
      name: "FAL",
      desc: "Flux, Kling, Wan",
      has_base_url: false,
      default_base_url: nil,
      models: %{
        "image" => [
          %{id: "banana-pro", name: "Banana Pro"},
          %{id: "banana-2", name: "Banana 2"}
        ],
        "video" => [
          %{id: "fal-wan25", name: "Wan 2.6"},
          %{id: "fal-veo31", name: "Veo 3.1"},
          %{id: "fal-sora2", name: "Sora 2"},
          %{id: "fal-kling25-turbo-pro", name: "Kling 2.5 Turbo Pro"},
          %{id: "fal-kling3", name: "Kling 3"}
        ],
        "audio" => [%{id: "indextts-2", name: "IndexTTS 2"}],
        "lipsync" => [%{id: "kling-lip-sync", name: "Kling Lip Sync"}]
      }
    },
    %{
      id: "apiyi",
      name: "API\u6613\uFF08\u805A\u5408\u5E73\u53F0\uFF09",
      desc: "Gemini, Claude, VEO",
      has_base_url: true,
      default_base_url: "https://api.apiyi.com/v1",
      models: %{
        "llm" => [
          %{id: "gemini-3.1-pro-preview", name: "Gemini 3.1 Pro"},
          %{id: "claude-opus-4-6", name: "Claude Opus 4.6"},
          %{id: "claude-sonnet-4.5", name: "Claude Sonnet 4.5"},
          %{id: "gpt-4o", name: "GPT-4o"}
        ],
        "image" => [
          %{id: "nano-banana-pro", name: "Nano Banana Pro"},
          %{id: "nano-banana-2", name: "Nano Banana 2"}
        ],
        "video" => [
          %{id: "veo-3.1", name: "VEO 3.1"},
          %{id: "veo-3.1-landscape", name: "VEO 3.1 Landscape"},
          %{id: "veo-3.1-fast", name: "VEO 3.1 Fast"},
          %{id: "veo-3.1-landscape-fast", name: "VEO 3.1 Landscape Fast"},
          %{id: "veo-3.1-fl", name: "VEO 3.1 FL"},
          %{id: "veo-3.1-landscape-fl", name: "VEO 3.1 Landscape FL"},
          %{id: "veo-3.1-fast-fl", name: "VEO 3.1 Fast FL"},
          %{id: "veo-3.1-landscape-fast-fl", name: "VEO 3.1 Landscape Fast FL"}
        ]
      }
    },
    %{
      id: "bailian",
      name: "\u767E\u70BC",
      desc: "Qwen, Wan, TTS",
      has_base_url: false,
      default_base_url: nil,
      models: %{
        "llm" => [
          %{id: "qwen-3.5-plus", name: "Qwen 3.5 Plus"},
          %{id: "qwen-3.5-flash", name: "Qwen 3.5 Flash"}
        ],
        "video" => [
          %{id: "wan2.7-i2v", name: "Wan 2.7 I2V"},
          %{id: "wan2.6-i2v-flash", name: "Wan 2.6 I2V Flash"}
        ],
        "audio" => [
          %{id: "qwen3-tts", name: "Qwen3 TTS"},
          %{id: "qwen-voice-design", name: "Qwen Voice Design"}
        ],
        "lipsync" => [%{id: "videoretalk-lip-sync", name: "VideoRetalk"}]
      }
    },
    %{
      id: "openrouter",
      name: "OpenRouter",
      desc: "Multi-model Gateway",
      has_base_url: true,
      default_base_url: "https://openrouter.ai/api/v1",
      models: %{
        "llm" => [
          %{id: "gemini-3.1-pro-preview", name: "Gemini 3.1 Pro"},
          %{id: "claude-sonnet-4.5", name: "Claude Sonnet 4.5"},
          %{id: "gpt-5.4", name: "GPT-5.4"}
        ]
      }
    },
    %{
      id: "vidu",
      name: "Vidu",
      desc: "Video Generation",
      has_base_url: false,
      default_base_url: nil,
      models: %{
        "video" => [
          %{id: "vidu-q3-pro", name: "Q3 Pro"},
          %{id: "vidu-q2-pro-fast", name: "Q2 Pro Fast"},
          %{id: "vidu-q2-pro", name: "Q2 Pro"},
          %{id: "vidu-2.0", name: "Vidu 2.0"}
        ],
        "lipsync" => [%{id: "vidu-lip-sync", name: "Vidu Lip Sync"}]
      }
    },
    %{
      id: "runninghub",
      name: "RunningHub",
      desc: "238+ Models",
      has_base_url: false,
      default_base_url: nil,
      models: %{}
    }
  ]

  @pipeline_steps [
    %{
      id: "analysis",
      label_en: "Story Analysis",
      label_zh: "\u6545\u4E8B\u5206\u6790",
      type: "llm"
    },
    %{
      id: "character",
      label_en: "Character Analysis",
      label_zh: "\u89D2\u8272\u5206\u6790",
      type: "llm"
    },
    %{
      id: "location",
      label_en: "Location Analysis",
      label_zh: "\u573A\u666F\u5206\u6790",
      type: "llm"
    },
    %{
      id: "storyboard",
      label_en: "Storyboard Generation",
      label_zh: "\u5206\u955C\u751F\u6210",
      type: "llm"
    },
    %{id: "edit", label_en: "Edit Assistant", label_zh: "\u7F16\u8F91\u52A9\u624B", type: "llm"},
    %{
      id: "image",
      label_en: "Image Generation",
      label_zh: "\u56FE\u50CF\u751F\u6210",
      type: "image"
    },
    %{
      id: "video",
      label_en: "Video Generation",
      label_zh: "\u89C6\u9891\u751F\u6210",
      type: "video"
    },
    %{id: "audio", label_en: "Voice / TTS", label_zh: "\u8BED\u97F3\u5408\u6210", type: "audio"},
    %{id: "lipsync", label_en: "Lip Sync", label_zh: "\u53E3\u578B\u540C\u6B65", type: "lipsync"},
    %{id: "music", label_en: "Music", label_zh: "\u97F3\u4E50", type: "music"}
  ]

  @model_type_labels %{
    "llm" => "LLM",
    "image" => "Image",
    "video" => "Video",
    "audio" => "Audio",
    "music" => "Music",
    "lipsync" => "Lipsync"
  }

  @prompt_groups [
    %{
      id: "story_creation",
      label_en: "Story Creation",
      label_zh: "\u521B\u4F5C\u8D77\u6B65",
      icon: "edit",
      prompts: [
        %{
          id: "NP_AI_STORY_OUTLINE",
          label_en: "AI Story Outline",
          label_zh: "AI \u6545\u4E8B\u5927\u7EB2"
        },
        %{
          id: "NP_AI_STORY_EXPAND",
          label_en: "AI Story Expand",
          label_zh: "AI \u6545\u4E8B\u6269\u5199"
        }
      ]
    },
    %{
      id: "story_to_script",
      label_en: "Story to Script",
      label_zh: "\u6545\u4E8B\u8F6C\u5267\u672C",
      icon: "file",
      prompts: [
        %{
          id: "NP_AGENT_CHARACTER_PROFILE",
          label_en: "Character Analysis",
          label_zh: "\u89D2\u8272\u5206\u6790"
        },
        %{
          id: "NP_SELECT_LOCATION",
          label_en: "Location Selection",
          label_zh: "\u573A\u666F\u8BC6\u522B"
        },
        %{id: "NP_SELECT_PROP", label_en: "Prop Selection", label_zh: "\u9053\u5177\u8BC6\u522B"},
        %{id: "NP_AGENT_CLIP", label_en: "Clip Detection", label_zh: "\u7247\u6BB5\u5207\u5272"},
        %{
          id: "NP_SCREENPLAY_CONVERSION",
          label_en: "Screenplay Conversion",
          label_zh: "\u5267\u672C\u8F6C\u6362"
        }
      ]
    },
    %{
      id: "script_to_storyboard",
      label_en: "Script to Storyboard",
      label_zh: "\u5267\u672C\u8F6C\u5206\u955C",
      icon: "film",
      prompts: [
        %{
          id: "NP_AGENT_STORYBOARD_PLAN",
          label_en: "Storyboard Plan Phase 1",
          label_zh: "\u5206\u955C\u89C4\u5212 Phase 1"
        },
        %{
          id: "NP_AGENT_CINEMATOGRAPHER",
          label_en: "Cinematographer Phase 2",
          label_zh: "\u6444\u5F71\u6307\u5BFC Phase 2"
        },
        %{
          id: "NP_AGENT_ACTING_DIRECTION",
          label_en: "Acting Direction Phase 2",
          label_zh: "\u8868\u6F14\u6307\u5BFC Phase 2"
        },
        %{
          id: "NP_AGENT_STORYBOARD_DETAIL",
          label_en: "Storyboard Detail Phase 3",
          label_zh: "\u5206\u955C\u7EC6\u8282 Phase 3"
        },
        %{
          id: "NP_VOICE_ANALYSIS",
          label_en: "Voice Analysis",
          label_zh: "\u53F0\u8BCD\u5206\u6790"
        },
        %{
          id: "NP_AGENT_CHARACTER_VISUAL",
          label_en: "Character Visual",
          label_zh: "\u89D2\u8272\u89C6\u89C9\u63CF\u8FF0"
        },
        %{
          id: "NP_FL_REWRITE",
          label_en: "FL Transition Rewrite",
          label_zh: "FL \u8FC7\u6E21\u63D0\u793A\u8BCD\u91CD\u5199"
        }
      ]
    },
    %{
      id: "editing_helpers",
      label_en: "Editing Helpers",
      label_zh: "\u8F85\u52A9\u7F16\u8F91",
      icon: "settings",
      prompts: [
        %{
          id: "NP_EPISODE_SPLIT",
          label_en: "Episode Split",
          label_zh: "\u7AE0\u8282\u62C6\u5206"
        },
        %{
          id: "NP_CHARACTER_CREATE",
          label_en: "Character Create",
          label_zh: "\u89D2\u8272\u521B\u5EFA"
        },
        %{
          id: "NP_CHARACTER_MODIFY",
          label_en: "Character Modify",
          label_zh: "\u89D2\u8272\u4FEE\u6539"
        },
        %{
          id: "NP_CHARACTER_REGENERATE",
          label_en: "Character Regenerate",
          label_zh: "\u89D2\u8272\u91CD\u751F\u6210"
        },
        %{
          id: "NP_CHARACTER_DESCRIPTION_UPDATE",
          label_en: "Character Desc Update",
          label_zh: "\u89D2\u8272\u63CF\u8FF0\u66F4\u65B0"
        },
        %{
          id: "NP_LOCATION_CREATE",
          label_en: "Location Create",
          label_zh: "\u573A\u666F\u521B\u5EFA"
        },
        %{
          id: "NP_LOCATION_MODIFY",
          label_en: "Location Modify",
          label_zh: "\u573A\u666F\u4FEE\u6539"
        },
        %{
          id: "NP_LOCATION_REGENERATE",
          label_en: "Location Regenerate",
          label_zh: "\u573A\u666F\u91CD\u751F\u6210"
        },
        %{
          id: "NP_LOCATION_DESCRIPTION_UPDATE",
          label_en: "Location Desc Update",
          label_zh: "\u573A\u666F\u63CF\u8FF0\u66F4\u65B0"
        },
        %{
          id: "NP_PROP_DESCRIPTION_UPDATE",
          label_en: "Prop Desc Update",
          label_zh: "\u9053\u5177\u63CF\u8FF0\u66F4\u65B0"
        },
        %{
          id: "NP_IMAGE_PROMPT_MODIFY",
          label_en: "Image Prompt Modify",
          label_zh: "\u56FE\u50CF\u63D0\u793A\u4FEE\u6539"
        },
        %{
          id: "NP_STORYBOARD_EDIT",
          label_en: "Storyboard Edit",
          label_zh: "\u5206\u955C\u7F16\u8F91"
        },
        %{
          id: "NP_AGENT_STORYBOARD_INSERT",
          label_en: "Storyboard Insert",
          label_zh: "\u5206\u955C\u63D2\u5165"
        },
        %{
          id: "NP_AGENT_SHOT_VARIANT_ANALYSIS",
          label_en: "Shot Variant Analysis",
          label_zh: "\u955C\u5934\u53D8\u4F53\u5206\u6790"
        },
        %{
          id: "NP_AGENT_SHOT_VARIANT_GENERATE",
          label_en: "Shot Variant Generate",
          label_zh: "\u955C\u5934\u53D8\u4F53\u751F\u6210"
        },
        %{
          id: "NP_SINGLE_PANEL_IMAGE",
          label_en: "Single Panel Image",
          label_zh: "\u5355\u9762\u677F\u56FE\u50CF\u63D0\u793A"
        },
        %{
          id: "CHARACTER_IMAGE_TO_DESCRIPTION",
          label_en: "Image to Description",
          label_zh: "\u56FE\u7247\u8F6C\u63CF\u8FF0"
        },
        %{
          id: "CHARACTER_REFERENCE_TO_SHEET",
          label_en: "Reference to Character",
          label_zh: "\u53C2\u8003\u56FE\u8F6C\u89D2\u8272"
        },
        %{
          id: "NP_CHARACTER_ASSET_SUFFIX",
          label_en: "Character Asset Suffix",
          label_zh: "\u89D2\u8272\u8BBE\u5B9A\u56FE\u540E\u7F00"
        },
        %{
          id: "NP_PROP_ASSET_SUFFIX",
          label_en: "Prop Asset Suffix",
          label_zh: "\u9053\u5177\u8BBE\u5B9A\u56FE\u540E\u7F00"
        },
        %{
          id: "NP_IMAGE_MODIFY_CHARACTER",
          label_en: "Character Image Modify",
          label_zh: "\u89D2\u8272\u56FE\u7247\u4FEE\u6539\u6307\u4EE4"
        },
        %{
          id: "NP_IMAGE_MODIFY_PANEL",
          label_en: "Panel Image Modify",
          label_zh: "\u5206\u955C\u56FE\u7247\u4FEE\u6539\u6307\u4EE4"
        }
      ]
    },
    %{
      id: "short_drama",
      label_en: "Short Drama",
      label_zh: "\u5FAE\u77ED\u5267",
      icon: "clapperboard",
      prompts: [
        %{
          id: "SD_TOPIC_SELECTION",
          label_en: "Topic Selection",
          label_zh: "\u9009\u9898\u7ACB\u9879"
        },
        %{
          id: "SD_STORY_OUTLINE",
          label_en: "Story Outline",
          label_zh: "\u6545\u4E8B\u5927\u7EB2"
        },
        %{
          id: "SD_CHARACTER_DEV",
          label_en: "Character Dev",
          label_zh: "\u89D2\u8272\u5F00\u53D1"
        },
        %{
          id: "SD_EPISODE_DIRECTORY",
          label_en: "Episode Directory",
          label_zh: "\u5206\u96C6\u76EE\u5F55"
        },
        %{
          id: "SD_EPISODE_SCRIPT",
          label_en: "Episode Script",
          label_zh: "\u5206\u96C6\u5267\u672C"
        },
        %{
          id: "SD_QUALITY_REVIEW",
          label_en: "Quality Review",
          label_zh: "\u8D28\u91CF\u5BA1\u6838"
        },
        %{
          id: "SD_COMPLIANCE_CHECK",
          label_en: "Compliance Check",
          label_zh: "\u5408\u89C4\u5BA1\u67E5"
        },
        %{
          id: "SD_OVERSEAS_ADAPT",
          label_en: "Overseas Adapt",
          label_zh: "\u51FA\u6D77\u9002\u914D"
        }
      ]
    }
  ]

  @prompt_path_map %{
    "NP_AI_STORY_OUTLINE" => "novel-promotion/ai_story_outline",
    "NP_AI_STORY_EXPAND" => "novel-promotion/ai_story_expand",
    "NP_AGENT_CHARACTER_PROFILE" => "novel-promotion/agent_character_profile",
    "NP_SELECT_LOCATION" => "novel-promotion/select_location",
    "NP_SELECT_PROP" => "novel-promotion/select_prop",
    "NP_AGENT_CLIP" => "novel-promotion/agent_clip",
    "NP_SCREENPLAY_CONVERSION" => "novel-promotion/screenplay_conversion",
    "NP_AGENT_STORYBOARD_PLAN" => "novel-promotion/agent_storyboard_plan",
    "NP_AGENT_CINEMATOGRAPHER" => "novel-promotion/agent_cinematographer",
    "NP_AGENT_ACTING_DIRECTION" => "novel-promotion/agent_acting_direction",
    "NP_AGENT_STORYBOARD_DETAIL" => "novel-promotion/agent_storyboard_detail",
    "NP_VOICE_ANALYSIS" => "novel-promotion/voice_analysis",
    "NP_AGENT_CHARACTER_VISUAL" => "novel-promotion/agent_character_visual",
    "NP_FL_REWRITE" => "novel-promotion/fl_rewrite",
    "NP_EPISODE_SPLIT" => "novel-promotion/episode_split",
    "NP_CHARACTER_CREATE" => "novel-promotion/character_create",
    "NP_CHARACTER_MODIFY" => "novel-promotion/character_modify",
    "NP_CHARACTER_REGENERATE" => "novel-promotion/character_regenerate",
    "NP_CHARACTER_DESCRIPTION_UPDATE" => "novel-promotion/character_description_update",
    "NP_LOCATION_CREATE" => "novel-promotion/location_create",
    "NP_LOCATION_MODIFY" => "novel-promotion/location_modify",
    "NP_LOCATION_REGENERATE" => "novel-promotion/location_regenerate",
    "NP_LOCATION_DESCRIPTION_UPDATE" => "novel-promotion/location_description_update",
    "NP_PROP_DESCRIPTION_UPDATE" => "novel-promotion/prop_description_update",
    "NP_IMAGE_PROMPT_MODIFY" => "novel-promotion/image_prompt_modify",
    "NP_STORYBOARD_EDIT" => "novel-promotion/storyboard_edit",
    "NP_AGENT_STORYBOARD_INSERT" => "novel-promotion/agent_storyboard_insert",
    "NP_AGENT_SHOT_VARIANT_ANALYSIS" => "novel-promotion/agent_shot_variant_analysis",
    "NP_AGENT_SHOT_VARIANT_GENERATE" => "novel-promotion/agent_shot_variant_generate",
    "NP_SINGLE_PANEL_IMAGE" => "novel-promotion/single_panel_image",
    "CHARACTER_IMAGE_TO_DESCRIPTION" => "character-reference/character_image_to_description",
    "CHARACTER_REFERENCE_TO_SHEET" => "character-reference/character_reference_to_sheet",
    "NP_CHARACTER_ASSET_SUFFIX" => "novel-promotion/character_asset_suffix",
    "NP_PROP_ASSET_SUFFIX" => "novel-promotion/prop_asset_suffix",
    "NP_IMAGE_MODIFY_CHARACTER" => "novel-promotion/image_modify_character",
    "NP_IMAGE_MODIFY_PANEL" => "novel-promotion/image_modify_panel",
    "SD_TOPIC_SELECTION" => "short-drama/sd_topic_selection",
    "SD_STORY_OUTLINE" => "short-drama/sd_story_outline",
    "SD_CHARACTER_DEV" => "short-drama/sd_character_dev",
    "SD_EPISODE_DIRECTORY" => "short-drama/sd_episode_directory",
    "SD_EPISODE_SCRIPT" => "short-drama/sd_episode_script",
    "SD_QUALITY_REVIEW" => "short-drama/sd_quality_review",
    "SD_COMPLIANCE_CHECK" => "short-drama/sd_compliance_check",
    "SD_OVERSEAS_ADAPT" => "short-drama/sd_overseas_adapt"
  }

  # ── Mount ──

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    preference = Accounts.get_user_preference(user.id)
    provider_configs = if preference, do: preference.provider_configs || %{}, else: %{}

    provider_order =
      case get_in(provider_configs, ["_provider_order"]) do
        order when is_list(order) -> order
        _ -> Enum.map(@providers, & &1.id)
      end

    {:ok,
     socket
     |> assign(:tab, "providers")
     |> assign(:providers, @providers)
     |> assign(:provider_configs, provider_configs)
     |> assign(:provider_order, provider_order)
     |> assign(:editing, nil)
     |> assign(:edit_key, "")
     |> assign(:edit_base_url, "")
     |> assign(:edit_model_tab, "llm")
     |> assign(:testing_provider, nil)
     |> assign(:test_result, nil)
     |> assign(:preference, preference)
     |> assign(
       :model_selections,
       if(preference, do: preference.model_selections || %{}, else: %{})
     )
     |> assign(:user, user)
     |> assign(
       :prompt_overrides,
       if(preference, do: preference.prompt_overrides || %{}, else: %{})
     )
     |> assign(:expanded_group, nil)
     |> assign(:editing_prompt, nil)
     |> assign(:testing_model_step, nil)
     |> assign(:model_test_result, nil)
     |> assign(:billing_summary, AstraAutoEx.Billing.Statistics.summary(user.id))
     |> assign(:page_title, dgettext("default", "Settings"))}
  end

  # ── Render ──

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-4xl mx-auto px-6 py-8">
        <h1 class="text-2xl font-bold mb-6">{dgettext("default", "Settings")}</h1>
        <%!-- Tabs --%>
        <div class="flex gap-1 mb-8 p-1 rounded-2xl bg-[var(--glass-bg-muted)] w-fit">
          <button
            :for={
              tab <-
                [
                  {"providers", dgettext("default", "AI Providers")},
                  {"models", dgettext("default", "Models")},
                  {"prompts", dgettext("default", "Prompt Tuning")},
                  {"billing", dgettext("default", "Billing")}
                ]
            }
            phx-click="switch_tab"
            phx-value-tab={elem(tab, 0)}
            class={[
              "px-5 py-2 rounded-xl text-sm font-semibold transition-all cursor-pointer",
              (@tab == elem(tab, 0) &&
                 "bg-gradient-to-r from-[var(--glass-accent-from)] to-[var(--glass-accent-to)] text-[var(--glass-text-on-accent)] shadow-md") ||
                "text-[var(--glass-text-tertiary)] hover:text-[var(--glass-text-primary)]"
            ]}
          >
            {elem(tab, 1)}
          </button>
        </div>
        <%!-- Tab content --%>
        <%= case @tab do %>
          <% "providers" -> %>
            <.providers_tab
              providers={@providers}
              provider_configs={@provider_configs}
              provider_order={@provider_order}
              editing={@editing}
              edit_key={@edit_key}
              edit_base_url={@edit_base_url}
              edit_model_tab={@edit_model_tab}
              testing_provider={@testing_provider}
              test_result={@test_result}
            />
          <% "models" -> %>
            <.models_tab
              model_selections={@model_selections}
              provider_configs={@provider_configs}
              providers={@providers}
              testing_model_step={@testing_model_step}
              model_test_result={@model_test_result}
            />
          <% "prompts" -> %>
            <.prompts_tab
              prompt_overrides={@prompt_overrides}
              expanded_group={@expanded_group}
              editing_prompt={@editing_prompt}
            />
          <% "billing" -> %>
            <.billing_tab
              current_scope={@current_scope}
              billing_summary={@billing_summary}
            />
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  # ══════════════════════════════════════════
  #  Provider Tab
  # ══════════════════════════════════════════

  defp providers_tab(assigns) do
    ordered =
      assigns.provider_order
      |> Enum.map(fn id -> Enum.find(assigns.providers, fn p -> p.id == id end) end)
      |> Enum.reject(&is_nil/1)

    # Append any providers not in the saved order
    known_ids = MapSet.new(assigns.provider_order)

    extras =
      Enum.reject(assigns.providers, fn p -> MapSet.member?(known_ids, p.id) end)

    assigns = assign(assigns, :ordered_providers, ordered ++ extras)

    ~H"""
    <div
      id="provider-list"
      phx-hook="DragSort"
      data-sort-event="reorder_providers"
      class="grid grid-cols-1 md:grid-cols-2 gap-3"
    >
      <div
        :for={provider <- @ordered_providers}
        id={"provider-#{provider.id}"}
        data-panel-id={provider.id}
        draggable="true"
        class="glass-surface p-5"
      >
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-3">
            <%!-- Drag grip --%>
            <div class="cursor-grab active:cursor-grabbing text-[var(--glass-text-tertiary)] hover:text-[var(--glass-text-secondary)]">
              <svg class="w-4 h-4" viewBox="0 0 24 24" fill="currentColor">
                <circle cx="9" cy="5" r="1.5" /><circle cx="15" cy="5" r="1.5" />
                <circle cx="9" cy="10" r="1.5" /><circle cx="15" cy="10" r="1.5" />
                <circle cx="9" cy="15" r="1.5" /><circle cx="15" cy="15" r="1.5" />
                <circle cx="9" cy="20" r="1.5" /><circle cx="15" cy="20" r="1.5" />
              </svg>
            </div>

            <div class={[
              "w-10 h-10 rounded-xl flex items-center justify-center font-bold text-sm",
              (provider_configured?(@provider_configs, provider.id) &&
                 "bg-gradient-to-br from-[var(--glass-accent-from)] to-[var(--glass-accent-to)] text-[var(--glass-text-on-accent)]") ||
                "bg-[var(--glass-stroke-strong)] text-[var(--glass-text-tertiary)]"
            ]}>
              {String.first(provider.name)}
            </div>

            <div>
              <div class="flex items-center gap-2">
                <span class="font-semibold text-[var(--glass-text-primary)]">{provider.name}</span>
                <span
                  :if={provider_configured?(@provider_configs, provider.id)}
                  class="glass-chip glass-chip-success text-[10px] py-0.5"
                >
                  {dgettext("default", "Connected")}
                </span>
              </div>
              <span class="text-xs text-[var(--glass-text-tertiary)]">{provider.desc}</span>
            </div>
          </div>

          <div class="flex items-center gap-2">
            <%= if @editing == provider.id do %>
              <button phx-click="cancel_edit" class="glass-btn glass-btn-ghost text-sm py-1.5 px-3">
                {dgettext("default", "Cancel")}
              </button>
              <button
                phx-click="save_provider"
                phx-value-id={provider.id}
                class="glass-btn glass-btn-primary text-sm py-1.5 px-3"
              >
                {dgettext("default", "Save")}
              </button>
            <% else %>
              <button
                phx-click="edit_provider"
                phx-value-id={provider.id}
                class="glass-btn glass-btn-secondary text-sm py-1.5 px-3"
              >
                {if provider_configured?(@provider_configs, provider.id),
                  do: dgettext("default", "Edit"),
                  else: dgettext("default", "Configure")}
              </button>
              <button
                :if={provider_configured?(@provider_configs, provider.id)}
                phx-click="remove_provider"
                phx-value-id={provider.id}
                data-confirm={dgettext("default", "Remove this provider?")}
                class="glass-btn glass-btn-ghost text-sm py-1.5 px-2 text-[var(--glass-tone-danger-fg)]"
              >
                <.icon name="hero-trash" class="size-4" />
              </button>
            <% end %>
          </div>
        </div>
        <%!-- Expanded edit form --%>
        <div
          :if={@editing == provider.id}
          class="mt-4 pt-4 border-t border-[var(--glass-stroke-base)]"
        >
          <div class="space-y-3">
            <%!-- API Key --%>
            <div>
              <label class="glass-label">{dgettext("default", "API Key")}</label>
              <input
                type="password"
                value={@edit_key}
                phx-keyup="update_edit_key"
                class="glass-input"
                placeholder={dgettext("default", "Enter API Key...")}
                autocomplete="off"
              />
            </div>
            <%!-- Base URL (conditional) --%>
            <div :if={provider.has_base_url}>
              <label class="glass-label">{dgettext("default", "Base URL")}</label>
              <input
                type="text"
                value={@edit_base_url}
                phx-keyup="update_edit_base_url"
                class="glass-input"
                placeholder={provider.default_base_url || "https://api.example.com"}
              />
            </div>
            <%!-- Current key mask --%>
            <p
              :if={provider_configured?(@provider_configs, provider.id)}
              class="text-xs text-[var(--glass-text-tertiary)]"
            >
              {dgettext("default", "Current key:")} {mask_key(
                get_in(@provider_configs, [provider.id, "api_key"])
              )}
            </p>
            <%!-- Test Connection --%>
            <div class="flex items-center gap-3">
              <button
                phx-click="test_connection"
                phx-value-id={provider.id}
                disabled={@testing_provider == provider.id}
                class={[
                  "glass-btn glass-btn-secondary text-sm py-1.5 px-4",
                  @testing_provider == provider.id && "opacity-60 cursor-not-allowed"
                ]}
              >
                <%= if @testing_provider == provider.id do %>
                  <svg
                    class="animate-spin -ml-0.5 mr-2 h-4 w-4 inline-block"
                    xmlns="http://www.w3.org/2000/svg"
                    fill="none"
                    viewBox="0 0 24 24"
                  >
                    <circle
                      class="opacity-25"
                      cx="12"
                      cy="12"
                      r="10"
                      stroke="currentColor"
                      stroke-width="4"
                    >
                    </circle>

                    <path
                      class="opacity-75"
                      fill="currentColor"
                      d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
                    >
                    </path>
                  </svg>
                  {dgettext("default", "Testing...")}
                <% else %>
                  {dgettext("default", "Test Connection")}
                <% end %>
              </button>
              <span
                :if={@test_result && @testing_provider == nil && @editing == provider.id}
                class={[
                  "text-xs font-medium",
                  (@test_result == :ok && "text-[var(--glass-tone-success-fg)]") ||
                    "text-[var(--glass-tone-danger-fg)]"
                ]}
              >
                <%= if @test_result == :ok do %>
                  {dgettext("default", "Connection successful")}
                <% else %>
                  {dgettext("default", "Connection failed")}
                <% end %>
              </span>
            </div>
          </div>
          <%!-- Model tabs (enable/disable models) --%>
          <%= if map_size(provider.models) > 0 do %>
            <div class="mt-5 pt-4 border-t border-[var(--glass-stroke-base)]">
              <h4 class="text-sm font-semibold text-[var(--glass-text-primary)] mb-3">
                {dgettext("default", "Models")}
              </h4>
              <%!-- Type tabs --%>
              <div class="flex gap-1 mb-3 p-0.5 rounded-xl bg-[var(--glass-bg-muted)] w-fit">
                <button
                  :for={type <- Map.keys(provider.models) |> Enum.sort()}
                  phx-click="switch_model_tab"
                  phx-value-type={type}
                  class={[
                    "px-3 py-1 rounded-lg text-xs font-medium transition-all cursor-pointer",
                    (@edit_model_tab == type &&
                       "bg-gradient-to-r from-[var(--glass-accent-from)] to-[var(--glass-accent-to)] text-[var(--glass-text-on-accent)] shadow-sm") ||
                      "text-[var(--glass-text-tertiary)] hover:text-[var(--glass-text-primary)]"
                  ]}
                >
                  {model_type_label(type)}
                </button>
              </div>
              <%!-- Model list for current type tab --%>
              <div class="space-y-2">
                <%= for model <- Map.get(provider.models, @edit_model_tab, []) do %>
                  <div class="flex items-center justify-between py-1.5 px-3 rounded-lg hover:bg-[var(--glass-bg-muted)] transition-colors">
                    <div>
                      <span class="text-sm text-[var(--glass-text-primary)]">{model.name}</span>
                      <code class="ml-2 text-[10px] text-[var(--glass-text-tertiary)] opacity-60">
                        {model.id}
                      </code>
                    </div>

                    <label class="relative inline-flex items-center cursor-pointer">
                      <input
                        type="checkbox"
                        class="sr-only peer"
                        checked={model_enabled?(@provider_configs, provider.id, model.id)}
                        phx-click="toggle_model"
                        phx-value-provider={provider.id}
                        phx-value-model={model.id}
                      />
                      <div class="w-9 h-5 bg-[var(--glass-stroke-strong)] peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full rtl:peer-checked:after:-translate-x-full peer-checked:after:border-[var(--glass-bg-base)] after:content-[''] after:absolute after:top-[2px] after:start-[2px] after:bg-[var(--glass-bg-base)] after:border-[var(--glass-stroke-base)] after:border after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-[var(--glass-accent-from)]">
                      </div>
                    </label>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # ══════════════════════════════════════════
  #  Models Tab (10 pipeline steps)
  # ══════════════════════════════════════════

  defp models_tab(assigns) do
    assigns =
      assigns
      |> assign(:steps, @pipeline_steps)
      |> assign(
        :available_models,
        build_available_models(assigns.providers, assigns.provider_configs)
      )

    ~H"""
    <div class="space-y-3">
      <p class="text-sm text-[var(--glass-text-tertiary)] mb-2">
        {dgettext(
          "default",
          "Select default models for each pipeline step. Only enabled models from configured providers are shown."
        )}
      </p>

      <div :for={step <- @steps} class="glass-surface px-4 py-3 rounded-xl">
        <div class="flex items-center gap-3">
          <div class="flex items-center gap-2 w-36 flex-shrink-0">
            <span class="glass-chip text-[10px] py-0.5">{step.type}</span>
            <div>
              <span class="text-sm font-medium text-[var(--glass-text-primary)]">
                {step.label_zh}
              </span>
              <span class="text-xs text-[var(--glass-text-tertiary)] ml-1 hidden lg:inline">
                {step.label_en}
              </span>
            </div>
          </div>

          <form phx-change="set_pipeline_model" class="flex-1">
            <input type="hidden" name="step" value={step.id} />
            <select
              name="model"
              class="glass-input w-full text-sm py-1.5"
            >
              <option value="">-- {dgettext("default", "Select")} --</option>

              <%= for {provider_name, model_id, model_name, provider_id} <- Map.get(@available_models, step.type, []) do %>
                <option
                  value={"#{provider_id}/#{model_id}"}
                  selected={
                    pipeline_model_selected?(@model_selections, step.id, provider_id, model_id)
                  }
                >
                  {provider_name} / {model_name}
                </option>
              <% end %>
            </select>
          </form>

          <button
            phx-click="test_pipeline_model"
            phx-value-step={step.id}
            class="glass-btn glass-btn-ghost text-xs py-1.5 px-3 flex-shrink-0 whitespace-nowrap"
            disabled={!Map.has_key?(@model_selections, step.id)}
          >
            <%= if @testing_model_step == step.id do %>
              <svg class="w-3.5 h-3.5 animate-spin inline mr-1" fill="none" viewBox="0 0 24 24">
                <circle
                  class="opacity-25"
                  cx="12"
                  cy="12"
                  r="10"
                  stroke="currentColor"
                  stroke-width="4"
                />
                <path
                  class="opacity-75"
                  fill="currentColor"
                  d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
                />
              </svg>
              测试中...
            <% else %>
              {dgettext("default", "Test")}
            <% end %>
          </button>
        </div>
      </div>
      <%!-- Model test result modal --%>
      <div
        :if={@model_test_result}
        class="fixed inset-0 z-[100] flex items-center justify-center animate-fade-in"
      >
        <div class="absolute inset-0 bg-black/60 backdrop-blur-sm" phx-click="clear_test_result">
        </div>

        <div
          class={[
            "relative bg-[var(--glass-bg-surface)] border rounded-2xl shadow-2xl max-w-lg w-full mx-4 overflow-hidden animate-scale-in",
            if(@model_test_result.success,
              do: "border-green-500/30",
              else: "border-red-500/30"
            )
          ]}
          style="backdrop-filter: blur(20px)"
        >
          <%!-- Header --%>
          <div class="flex items-center justify-between px-5 py-3 border-b border-[var(--glass-stroke-soft)]">
            <div class="flex items-center gap-2">
              <span class={[
                "text-sm font-bold",
                if(@model_test_result.success, do: "text-green-400", else: "text-red-400")
              ]}>
                {if @model_test_result.success, do: "测试成功", else: "测试失败"}
              </span>
              <span class="px-2 py-0.5 rounded-full text-[10px] font-medium bg-[var(--glass-bg-muted)] text-[var(--glass-text-secondary)]">
                {@model_test_result.provider}/{@model_test_result.model}
              </span>
            </div>
            <button
              phx-click="clear_test_result"
              class="text-[var(--glass-text-tertiary)] hover:text-[var(--glass-text-primary)] text-xl leading-none"
            >
              &times;
            </button>
          </div>
          <%!-- Body --%>
          <div class="px-5 py-4 space-y-4 max-h-[60vh] overflow-y-auto">
            <%!-- Duration badge --%>
            <div class="flex items-center gap-3">
              <div class="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-[var(--glass-bg-muted)]">
                <svg
                  class="w-3.5 h-3.5 text-[var(--glass-text-tertiary)]"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  viewBox="0 0 24 24"
                >
                  <circle cx="12" cy="12" r="10" /><path d="M12 6v6l4 2" />
                </svg>
                <span class="text-xs font-mono text-[var(--glass-text-primary)]">
                  {@model_test_result.duration}ms
                </span>
              </div>
              <span class="text-[10px] text-[var(--glass-text-tertiary)]">返回时间</span>
            </div>
            <%!-- Input --%>
            <div>
              <label class="flex items-center gap-1.5 text-[10px] text-[var(--glass-text-tertiary)] uppercase tracking-wider mb-1.5">
                <svg
                  class="w-3 h-3"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  viewBox="0 0 24 24"
                >
                  <path d="M12 19V5m-7 7l7-7 7 7" />
                </svg>
                输入 (Request)
              </label>
              <div class="text-xs text-[var(--glass-text-secondary)] bg-[var(--glass-bg-muted)] rounded-lg p-3 font-mono border border-[var(--glass-stroke-soft)]">
                你好，请回复一句话确认连接正常。
              </div>
            </div>
            <%!-- Output --%>
            <%= if @model_test_result.success do %>
              <div>
                <label class="flex items-center gap-1.5 text-[10px] text-[var(--glass-text-tertiary)] uppercase tracking-wider mb-1.5">
                  <svg
                    class="w-3 h-3"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    viewBox="0 0 24 24"
                  >
                    <path d="M12 5v14m7-7l-7 7-7-7" />
                  </svg>
                  输出 (Response)
                </label>
                <div class="text-xs text-[var(--glass-text-primary)] bg-[var(--glass-bg-muted)] rounded-lg p-3 border border-[var(--glass-stroke-soft)] leading-relaxed">
                  {@model_test_result.response}
                </div>
              </div>
            <% else %>
              <div>
                <label class="flex items-center gap-1.5 text-[10px] text-red-400 uppercase tracking-wider mb-1.5">
                  <svg
                    class="w-3 h-3"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    viewBox="0 0 24 24"
                  >
                    <circle cx="12" cy="12" r="10" /><line x1="15" y1="9" x2="9" y2="15" /><line
                      x1="9"
                      y1="9"
                      x2="15"
                      y2="15"
                    />
                  </svg>
                  错误详情
                </label>
                <pre class="text-xs text-red-400 bg-[var(--glass-bg-muted)] rounded-lg p-3 font-mono whitespace-pre-wrap border border-red-500/20"><%= @model_test_result[:error] %></pre>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ══════════════════════════════════════════
  #  Billing Tab
  # ══════════════════════════════════════════

  defp billing_tab(assigns) do
    ~H"""
    <div class="space-y-4">
      <.live_component
        module={AstraAutoExWeb.ProfileLive.BillingStats}
        id="billing-stats"
        user_id={@current_scope.user.id}
        billing_summary={@billing_summary}
      />
    </div>
    """
  end

  # ══════════════════════════════════════════
  #  Prompt Tuning Tab
  # ══════════════════════════════════════════

  defp prompts_tab(assigns) do
    assigns = assign(assigns, :groups, @prompt_groups)

    ~H"""
    <div class="space-y-4">
      <div class="flex items-center justify-between mb-2">
        <div>
          <h2 class="text-lg font-semibold text-[var(--glass-text-primary)]">
            {dgettext("default", "Prompt Tuning")}
          </h2>

          <p class="text-xs text-[var(--glass-text-tertiary)] mt-1">
            {dgettext(
              "default",
              "View and customize system prompts for each pipeline step. Defaults are read-only \u2014 use Save As to create your own version."
            )}
          </p>
        </div>

        <div :if={map_size(@prompt_overrides) > 0} class="glass-chip glass-chip-warning text-xs">
          {map_size(@prompt_overrides)} {dgettext("default", "customized")}
        </div>
      </div>

      <div :for={group <- @groups} class="glass-surface rounded-xl overflow-hidden">
        <button
          phx-click="toggle_prompt_group"
          phx-value-group={group.id}
          class="w-full flex items-center justify-between px-5 py-3 hover:bg-[var(--glass-bg-muted)] transition-colors cursor-pointer"
        >
          <div class="flex items-center gap-3">
            <span class="text-sm font-semibold text-[var(--glass-text-primary)]">
              {group.label_zh} — {group.label_en}
            </span>
            <span class="glass-chip text-[10px]">{length(group.prompts)}</span>
          </div>

          <svg
            class={"w-4 h-4 text-[var(--glass-text-tertiary)] transition-transform #{if @expanded_group == group.id, do: "rotate-180"}"}
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            viewBox="0 0 24 24"
          >
            <path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7" />
          </svg>
        </button>
        <div :if={@expanded_group == group.id} class="border-t border-[var(--glass-stroke-base)]">
          <div
            :for={prompt <- group.prompts}
            class="px-5 py-3 border-b border-[var(--glass-stroke-soft)] last:border-b-0"
          >
            <div class="flex items-center justify-between">
              <div>
                <span class="text-sm font-medium text-[var(--glass-text-primary)]">
                  {prompt.label_zh}
                </span>
                <span class="text-xs text-[var(--glass-text-tertiary)] ml-2">{prompt.label_en}</span>
                <span
                  :if={Map.has_key?(@prompt_overrides, prompt.id)}
                  class="ml-2 glass-chip glass-chip-success text-[10px]"
                >
                  {dgettext("default", "Custom")}
                </span>
              </div>

              <div class="flex items-center gap-1">
                <button
                  phx-click="view_prompt"
                  phx-value-id={prompt.id}
                  class="glass-btn glass-btn-ghost text-xs py-1 px-2"
                >
                  {dgettext("default", "View")}
                </button>
                <button
                  phx-click="save_prompt_as"
                  phx-value-id={prompt.id}
                  class="glass-btn glass-btn-ghost text-xs py-1 px-2"
                >
                  {dgettext("default", "Save As")}
                </button>
                <button
                  :if={Map.has_key?(@prompt_overrides, prompt.id)}
                  phx-click="delete_prompt_override"
                  phx-value-id={prompt.id}
                  data-confirm={dgettext("default", "Delete this custom prompt?")}
                  class="glass-btn glass-btn-ghost text-xs py-1 px-2 text-[var(--glass-tone-danger-fg)]"
                >
                  {dgettext("default", "Delete")}
                </button>
              </div>
            </div>

            <code class="text-[10px] text-[var(--glass-text-tertiary)] opacity-60 mt-0.5 block">
              {prompt.id}
            </code>
          </div>
        </div>
      </div>
      <%!-- Prompt View/Edit Modal --%>
      <%= if @editing_prompt do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center">
          <div class="absolute inset-0 bg-black/60" phx-click="close_prompt_modal" />
          <div class="glass-card p-6 w-full max-w-2xl relative z-10 max-h-[80vh] overflow-hidden flex flex-col">
            <div class="flex items-center justify-between mb-4">
              <div>
                <h3 class="text-lg font-bold text-[var(--glass-text-primary)]">
                  {@editing_prompt.label}
                </h3>
                <code class="text-xs text-[var(--glass-text-tertiary)]">{@editing_prompt.id}</code>
              </div>

              <button
                phx-click="close_prompt_modal"
                class="text-[var(--glass-text-tertiary)] hover:text-[var(--glass-text-primary)] text-xl"
              >
                &times;
              </button>
            </div>

            <div class="flex-1 overflow-y-auto space-y-4">
              <%!-- Default (read-only) --%>
              <div>
                <label class="text-xs text-[var(--glass-text-tertiary)] mb-1 block">
                  {dgettext("default", "Default Template (read-only)")}
                </label>
                <textarea
                  class="glass-input w-full h-48 resize-none text-xs font-mono"
                  readonly
                ><%= @editing_prompt.default_text %></textarea>
              </div>
              <%!-- Custom override --%>
              <div :if={@editing_prompt.mode == :edit}>
                <label class="text-xs text-[var(--glass-text-tertiary)] mb-1 block">
                  {dgettext("default", "Custom Prompt")}
                </label>
                <textarea
                  id="prompt-override-textarea"
                  phx-hook="AutoResize"
                  name="custom_text"
                  phx-keyup="update_prompt_text"
                  class="glass-input w-full h-48 resize-y text-xs font-mono"
                ><%= @editing_prompt.custom_text %></textarea>
              </div>
            </div>

            <div class="flex justify-end gap-2 mt-4 pt-3 border-t border-[var(--glass-stroke-base)]">
              <button
                phx-click="close_prompt_modal"
                class="px-4 py-2 text-sm text-[var(--glass-text-tertiary)] hover:text-[var(--glass-text-primary)]"
              >
                {dgettext("default", "Cancel")}
              </button>
              <button
                :if={@editing_prompt.mode == :edit}
                phx-click="confirm_save_prompt"
                class="glass-btn glass-btn-primary px-6 py-2 text-sm"
              >
                {dgettext("default", "Save")}
              </button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # ══════════════════════════════════════════
  #  Events
  # ══════════════════════════════════════════

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :tab, tab)}
  end

  # ── Provider events ──

  def handle_event("edit_provider", %{"id" => id}, socket) do
    existing = get_in(socket.assigns.provider_configs, [id]) || %{}
    provider = Enum.find(@providers, fn p -> p.id == id end)

    first_type =
      if provider && map_size(provider.models) > 0,
        do: provider.models |> Map.keys() |> Enum.sort() |> hd(),
        else: "llm"

    {:noreply,
     socket
     |> assign(:editing, id)
     |> assign(:edit_key, Map.get(existing, "api_key", ""))
     |> assign(:edit_base_url, Map.get(existing, "base_url", ""))
     |> assign(:edit_model_tab, first_type)
     |> assign(:test_result, nil)}
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply,
     assign(socket,
       editing: nil,
       edit_key: "",
       edit_base_url: "",
       test_result: nil,
       testing_provider: nil
     )}
  end

  def handle_event("update_edit_key", %{"value" => value}, socket) do
    {:noreply, assign(socket, :edit_key, value)}
  end

  def handle_event("update_edit_base_url", %{"value" => value}, socket) do
    {:noreply, assign(socket, :edit_base_url, value)}
  end

  def handle_event("switch_model_tab", %{"type" => type}, socket) do
    {:noreply, assign(socket, :edit_model_tab, type)}
  end

  def handle_event("toggle_model", %{"provider" => provider_id, "model" => model_id}, socket) do
    configs = socket.assigns.provider_configs
    provider_cfg = Map.get(configs, provider_id, %{})
    enabled = Map.get(provider_cfg, "enabled_models", [])

    new_enabled =
      if model_id in enabled,
        do: List.delete(enabled, model_id),
        else: enabled ++ [model_id]

    new_cfg = Map.put(provider_cfg, "enabled_models", new_enabled)
    new_configs = Map.put(configs, provider_id, new_cfg)

    save_provider_configs(socket, new_configs, keep_editing: true)
  end

  def handle_event("save_provider", %{"id" => id}, socket) do
    key = String.trim(socket.assigns.edit_key)
    base_url = String.trim(socket.assigns.edit_base_url)

    if key == "" do
      {:noreply, put_flash(socket, :error, dgettext("default", "API Key cannot be empty."))}
    else
      existing = Map.get(socket.assigns.provider_configs, id, %{})
      config = Map.merge(existing, %{"api_key" => key})
      config = if base_url != "", do: Map.put(config, "base_url", base_url), else: config

      # If no enabled_models yet, enable all by default
      provider = Enum.find(@providers, fn p -> p.id == id end)

      config =
        if not Map.has_key?(config, "enabled_models") && provider do
          all_model_ids =
            provider.models
            |> Map.values()
            |> List.flatten()
            |> Enum.map(& &1.id)

          Map.put(config, "enabled_models", all_model_ids)
        else
          config
        end

      new_configs = Map.put(socket.assigns.provider_configs, id, config)
      save_provider_configs(socket, new_configs)
    end
  end

  def handle_event("remove_provider", %{"id" => id}, socket) do
    new_configs = Map.delete(socket.assigns.provider_configs, id)
    save_provider_configs(socket, new_configs)
  end

  def handle_event("test_connection", %{"id" => id}, socket) do
    key = String.trim(socket.assigns.edit_key)

    if key == "" do
      {:noreply, put_flash(socket, :error, dgettext("default", "Enter an API key first."))}
    else
      provider = Enum.find(@providers, fn p -> p.id == id end)
      base_url = String.trim(socket.assigns.edit_base_url)

      base_url =
        cond do
          base_url != "" -> base_url
          provider && provider.default_base_url -> provider.default_base_url
          true -> nil
        end

      lv = self()

      Task.start(fn ->
        result = do_health_check(id, key, base_url)
        send(lv, {:test_connection_result, id, result})
      end)

      {:noreply, assign(socket, testing_provider: id, test_result: nil)}
    end
  end

  def handle_event("reorder_providers", %{"order" => order}, socket) when is_list(order) do
    configs = Map.put(socket.assigns.provider_configs, "_provider_order", order)
    save_provider_configs(socket, configs, keep_editing: true, update_order: order)
  end

  def handle_event("reorder_providers", _params, socket) do
    {:noreply, socket}
  end

  # ── Model selection events (pipeline steps) ──

  def handle_event("set_pipeline_model", %{"model" => "", "step" => step_id}, socket) do
    user = socket.assigns.user
    pref = socket.assigns.preference
    current = if pref, do: pref.model_selections || %{}, else: %{}
    new_selections = Map.delete(current, step_id)

    result =
      case pref do
        nil ->
          Accounts.create_user_preference(%{user_id: user.id, model_selections: new_selections})

        p ->
          Accounts.update_user_preference(p, %{model_selections: new_selections})
      end

    case result do
      {:ok, preference} ->
        {:noreply,
         socket
         |> assign(:preference, preference)
         |> assign(:model_selections, new_selections)
         |> put_flash(:info, dgettext("default", "Model cleared"))}

      {:error, _} ->
        {:noreply,
         put_flash(socket, :error, dgettext("default", "Failed to save model selection"))}
    end
  end

  def handle_event("set_pipeline_model", %{"model" => value, "step" => step_id}, socket) do
    user = socket.assigns.user
    [provider, model] = String.split(value, "/", parts: 2)

    pref = socket.assigns.preference
    current = if pref, do: pref.model_selections || %{}, else: %{}

    new_selections =
      Map.put(current, step_id, %{"provider" => provider, "model" => model})

    result =
      case pref do
        nil ->
          Accounts.create_user_preference(%{user_id: user.id, model_selections: new_selections})

        p ->
          Accounts.update_user_preference(p, %{model_selections: new_selections})
      end

    case result do
      {:ok, preference} ->
        {:noreply,
         socket
         |> assign(:preference, preference)
         |> assign(:model_selections, new_selections)
         |> put_flash(:info, dgettext("default", "Model updated"))}

      {:error, _} ->
        {:noreply,
         put_flash(socket, :error, dgettext("default", "Failed to save model selection"))}
    end
  end

  def handle_event("clear_test_result", _, socket) do
    {:noreply, assign(socket, :model_test_result, nil)}
  end

  def handle_event("test_pipeline_model", %{"step" => step_id}, socket) do
    case Map.get(socket.assigns.model_selections, step_id) do
      %{"provider" => provider, "model" => model} ->
        user_id = socket.assigns.user.id
        lv = self()

        Task.start(fn ->
          test_req = %{
            "messages" => [
              %{"role" => "system", "content" => "Reply briefly in Chinese."},
              %{"role" => "user", "content" => "你好，请回复一句话确认连接正常。"}
            ],
            "model" => model,
            "max_tokens" => 100,
            "action" => "model_test"
          }

          start_time = System.monotonic_time(:millisecond)
          result = AstraAutoEx.Workers.Handlers.Helpers.chat(user_id, provider, test_req)
          duration = System.monotonic_time(:millisecond) - start_time
          send(lv, {:test_model_result, step_id, provider, model, result, duration})
        end)

        {:noreply,
         socket
         |> assign(:testing_model_step, step_id)
         |> put_flash(:info, "正在测试 #{provider}/#{model}...")}

      _ ->
        {:noreply, put_flash(socket, :error, "请先选择模型")}
    end
  end

  # Keep legacy set_model for backward compat
  def handle_event("set_model", %{"model" => value, "category" => category}, socket) do
    user = socket.assigns.user
    [provider, model] = String.split(value, "/", parts: 2)

    pref = socket.assigns.preference
    current_selections = if pref, do: pref.model_selections || %{}, else: %{}

    new_selections =
      Map.put(current_selections, category, %{"provider" => provider, "model" => model})

    result =
      case pref do
        nil ->
          Accounts.create_user_preference(%{user_id: user.id, model_selections: new_selections})

        p ->
          Accounts.update_user_preference(p, %{model_selections: new_selections})
      end

    case result do
      {:ok, preference} ->
        {:noreply,
         socket
         |> assign(:preference, preference)
         |> assign(:model_selections, new_selections)
         |> put_flash(:info, dgettext("default", "Model updated"))}

      {:error, _} ->
        {:noreply,
         put_flash(socket, :error, dgettext("default", "Failed to save model selection"))}
    end
  end

  # ── Prompt events ──

  def handle_event("toggle_prompt_group", %{"group" => group}, socket) do
    current = socket.assigns.expanded_group
    {:noreply, assign(socket, :expanded_group, if(current == group, do: nil, else: group))}
  end

  def handle_event("view_prompt", %{"id" => prompt_id}, socket) do
    prompt_meta = find_prompt_meta(prompt_id)
    locale = socket.assigns.user.locale || "zh"
    default_text = load_default_prompt(prompt_id, locale)

    {:noreply,
     assign(socket, :editing_prompt, %{
       id: prompt_id,
       label: prompt_meta.label_zh <> " \u2014 " <> prompt_meta.label_en,
       default_text: default_text,
       custom_text: "",
       mode: :view
     })}
  end

  def handle_event("save_prompt_as", %{"id" => prompt_id}, socket) do
    prompt_meta = find_prompt_meta(prompt_id)
    locale = socket.assigns.user.locale || "zh"
    default_text = load_default_prompt(prompt_id, locale)
    existing = Map.get(socket.assigns.prompt_overrides, prompt_id, "")

    {:noreply,
     assign(socket, :editing_prompt, %{
       id: prompt_id,
       label: prompt_meta.label_zh <> " \u2014 " <> prompt_meta.label_en,
       default_text: default_text,
       custom_text: if(existing != "", do: existing, else: default_text),
       mode: :edit
     })}
  end

  def handle_event("update_prompt_text", %{"value" => value}, socket) do
    editing = socket.assigns.editing_prompt
    {:noreply, assign(socket, :editing_prompt, %{editing | custom_text: value})}
  end

  def handle_event("confirm_save_prompt", _, socket) do
    editing = socket.assigns.editing_prompt
    text = String.trim(editing.custom_text)
    prompt_id = editing.id

    new_overrides =
      if text == "" do
        Map.delete(socket.assigns.prompt_overrides, prompt_id)
      else
        Map.put(socket.assigns.prompt_overrides, prompt_id, text)
      end

    save_prompt_overrides(socket, new_overrides)
  end

  def handle_event("delete_prompt_override", %{"id" => prompt_id}, socket) do
    new_overrides = Map.delete(socket.assigns.prompt_overrides, prompt_id)
    save_prompt_overrides(socket, new_overrides)
  end

  def handle_event("close_prompt_modal", _, socket) do
    {:noreply, assign(socket, :editing_prompt, nil)}
  end

  # ── handle_info ──

  @impl true
  def handle_info({:test_model_result, _step_id, provider, model, result, duration}, socket) do
    test_result =
      case result do
        {:ok, %{content: content} = resp} ->
          %{
            success: true,
            provider: provider,
            model: model,
            duration: duration,
            response: String.slice(to_string(content), 0..500),
            input_tokens: Map.get(resp, :input_tokens, 0),
            output_tokens: Map.get(resp, :output_tokens, 0)
          }

        {:ok, text} when is_binary(text) ->
          %{
            success: true,
            provider: provider,
            model: model,
            duration: duration,
            response: String.slice(text, 0..500)
          }

        {:error, reason} ->
          %{
            success: false,
            provider: provider,
            model: model,
            duration: duration,
            error: inspect(reason)
          }
      end

    flash_msg =
      if test_result.success,
        do: "✅ #{provider}/#{model} 测试成功（#{duration}ms）",
        else: "❌ #{provider}/#{model} 测试失败（#{duration}ms）"

    {:noreply,
     socket
     |> assign(:testing_model_step, nil)
     |> assign(:model_test_result, test_result)
     |> put_flash(if(test_result.success, do: :info, else: :error), flash_msg)}
  end

  def handle_info({:test_connection_result, provider_id, result}, socket) do
    if socket.assigns.testing_provider == provider_id do
      {:noreply, assign(socket, testing_provider: nil, test_result: result)}
    else
      {:noreply, socket}
    end
  end

  # ══════════════════════════════════════════
  #  Private helpers
  # ══════════════════════════════════════════

  defp save_provider_configs(socket, new_configs, opts \\ []) do
    user = socket.assigns.user

    result =
      case socket.assigns.preference do
        nil ->
          Accounts.create_user_preference(%{user_id: user.id, provider_configs: new_configs})

        pref ->
          Accounts.update_user_preference(pref, %{provider_configs: new_configs})
      end

    case result do
      {:ok, preference} ->
        new_socket =
          socket
          |> assign(:provider_configs, new_configs)
          |> assign(:preference, preference)

        new_socket =
          if Keyword.get(opts, :keep_editing, false),
            do: new_socket,
            else:
              new_socket
              |> assign(:editing, nil)
              |> assign(:edit_key, "")
              |> assign(:edit_base_url, "")

        new_socket =
          case Keyword.get(opts, :update_order) do
            order when is_list(order) -> assign(new_socket, :provider_order, order)
            _ -> new_socket
          end

        {:noreply, put_flash(new_socket, :info, dgettext("default", "Save") <> " OK")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, dgettext("default", "Error"))}
    end
  end

  defp save_prompt_overrides(socket, new_overrides) do
    user = socket.assigns.user

    result =
      case socket.assigns.preference do
        nil ->
          Accounts.create_user_preference(%{
            user_id: user.id,
            prompt_overrides: new_overrides
          })

        pref ->
          Accounts.update_user_preference(pref, %{prompt_overrides: new_overrides})
      end

    case result do
      {:ok, preference} ->
        {:noreply,
         socket
         |> assign(:prompt_overrides, new_overrides)
         |> assign(:preference, preference)
         |> assign(:editing_prompt, nil)
         |> put_flash(:info, dgettext("default", "Save") <> " OK")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, dgettext("default", "Error"))}
    end
  end

  # ── Provider helpers ──

  defp provider_configured?(configs, id) do
    case Map.get(configs, id) do
      %{"api_key" => key} when is_binary(key) and key != "" -> true
      _ -> false
    end
  end

  defp mask_key(nil), do: ""
  defp mask_key(""), do: ""
  defp mask_key(key) when byte_size(key) <= 8, do: "****"

  defp mask_key(key) do
    String.slice(key, 0..2) <> "****" <> String.slice(key, -4..-1)
  end

  defp model_enabled?(configs, provider_id, model_id) do
    case get_in(configs, [provider_id, "enabled_models"]) do
      list when is_list(list) -> model_id in list
      # If no enabled_models key exists yet, treat all as enabled by default
      nil -> provider_configured?(configs, provider_id) || true
    end
  end

  defp model_type_label(type), do: Map.get(@model_type_labels, type, String.upcase(type))

  # ── Pipeline model helpers ──

  defp build_available_models(providers, configs) do
    # For each model type, collect all enabled models across configured providers
    providers
    |> Enum.filter(fn p -> provider_configured?(configs, p.id) end)
    |> Enum.flat_map(fn provider ->
      enabled_list = get_in(configs, [provider.id, "enabled_models"])

      provider.models
      |> Enum.flat_map(fn {type, models} ->
        models
        |> Enum.filter(fn model ->
          case enabled_list do
            list when is_list(list) -> model.id in list
            nil -> true
          end
        end)
        |> Enum.map(fn model ->
          {type, {provider.name, model.id, model.name, provider.id}}
        end)
      end)
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end

  defp pipeline_model_selected?(selections, step_id, provider_id, model_id) do
    case Map.get(selections, step_id) do
      %{"provider" => p, "model" => m} -> p == provider_id && m == model_id
      _ -> false
    end
  end

  # ── Prompt helpers ──

  defp find_prompt_meta(prompt_id) do
    @prompt_groups
    |> Enum.flat_map(& &1.prompts)
    |> Enum.find(%{label_en: prompt_id, label_zh: prompt_id}, fn p -> p.id == prompt_id end)
  end

  defp load_default_prompt(prompt_id, locale) do
    path_stem = prompt_id_to_path(prompt_id)
    file = Application.app_dir(:astra_auto_ex, "priv/prompts/#{path_stem}.#{locale}.txt")

    case File.read(file) do
      {:ok, content} -> content
      {:error, _} -> "(template file not found: #{path_stem}.#{locale}.txt)"
    end
  end

  defp prompt_id_to_path(id), do: Map.get(@prompt_path_map, id, "unknown/#{id}")

  # ── Health check ──

  defp do_health_check(provider_id, api_key, base_url) do
    url = build_health_url(provider_id, base_url)

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"}
    ]

    case :httpc.request(
           :get,
           {String.to_charlist(url),
            Enum.map(headers, fn {k, v} -> {String.to_charlist(k), String.to_charlist(v)} end)},
           [{:timeout, 10_000}, {:connect_timeout, 5_000}],
           []
         ) do
      {:ok, {{_, status, _}, _, _}} when status in 200..299 -> :ok
      {:ok, {{_, 401, _}, _, _}} -> :error
      {:ok, {{_, 403, _}, _, _}} -> :error
      {:ok, _} -> :ok
      {:error, _} -> :error
    end
  rescue
    _ -> :error
  end

  defp build_health_url("fal", _base_url), do: "https://queue.fal.run"
  defp build_health_url("ark", _base_url), do: "https://ark.cn-beijing.volces.com/api/v3/models"

  defp build_health_url("google", _base_url),
    do: "https://generativelanguage.googleapis.com/v1beta/models"

  defp build_health_url("bailian", _base_url),
    do: "https://dashscope.aliyuncs.com/compatible-mode/v1/models"

  defp build_health_url("vidu", _base_url), do: "https://api.vidu.com/v1/tasks"
  defp build_health_url("runninghub", _base_url), do: "https://www.runninghub.cn/api/v1/task"

  defp build_health_url(_provider_id, base_url) when is_binary(base_url) and base_url != "" do
    String.trim_trailing(base_url, "/") <> "/models"
  end

  defp build_health_url(_provider_id, _base_url), do: "https://api.openai.com/v1/models"
end
