defmodule AstraAutoEx.AI.PromptCatalog do
  @moduledoc """
  Manages the 44 prompt templates used across the AstraAuto pipeline.

  Each prompt has a unique ID, bilingual labels (en/zh), a file path stem
  under `priv/prompts/`, and a list of variable keys for substitution.

  Templates are read from `priv/prompts/{path_stem}.{locale}.txt` and
  cached in `:persistent_term` so subsequent reads are free.

  Variable substitution uses single-brace `{var_name}` syntax.
  """

  # ---------------------------------------------------------------------------
  # Asset prompt suffixes — appended to image generation prompts by type
  # ---------------------------------------------------------------------------

  @character_prompt_suffix "角色设定图，画面分为左右两个区域：【左侧】正面特写(1/3)；【右侧】三视图横排(正面/侧面/背面, 2/3)。纯白背景"
  @prop_prompt_suffix "道具设定图，画面分为左右两个区域：【左侧】主视图特写(1/3)；【右侧】三视图横排(正面/侧面/背面, 2/3)。纯白背景，无人物/手部/桌面/环境"
  @location_prompt_suffix ""

  @doc "Suffix appended to character image generation prompts."
  @spec character_prompt_suffix() :: String.t()
  def character_prompt_suffix, do: @character_prompt_suffix

  @doc "Suffix appended to prop image generation prompts."
  @spec prop_prompt_suffix() :: String.t()
  def prop_prompt_suffix, do: @prop_prompt_suffix

  @doc "Suffix appended to location image generation prompts (currently empty)."
  @spec location_prompt_suffix() :: String.t()
  def location_prompt_suffix, do: @location_prompt_suffix

  # ---------------------------------------------------------------------------
  # Prompt IDs (module attributes for compile-time checks)
  # ---------------------------------------------------------------------------

  # Group 1 — Story Creation
  @np_ai_story_outline :NP_AI_STORY_OUTLINE
  @np_ai_story_expand :NP_AI_STORY_EXPAND

  # Group 2 — Story to Script
  @np_agent_character_profile :NP_AGENT_CHARACTER_PROFILE
  @np_select_location :NP_SELECT_LOCATION
  @np_select_prop :NP_SELECT_PROP
  @np_agent_clip :NP_AGENT_CLIP
  @np_screenplay_conversion :NP_SCREENPLAY_CONVERSION

  # Group 3 — Script to Storyboard
  @np_agent_storyboard_plan :NP_AGENT_STORYBOARD_PLAN
  @np_agent_cinematographer :NP_AGENT_CINEMATOGRAPHER
  @np_agent_acting_direction :NP_AGENT_ACTING_DIRECTION
  @np_agent_storyboard_detail :NP_AGENT_STORYBOARD_DETAIL
  @np_voice_analysis :NP_VOICE_ANALYSIS
  @np_agent_character_visual :NP_AGENT_CHARACTER_VISUAL
  @np_fl_rewrite :NP_FL_REWRITE

  # Group 4 — Editing Helpers
  @np_episode_split :NP_EPISODE_SPLIT
  @np_character_create :NP_CHARACTER_CREATE
  @np_character_modify :NP_CHARACTER_MODIFY
  @np_character_regenerate :NP_CHARACTER_REGENERATE
  @np_character_description_update :NP_CHARACTER_DESCRIPTION_UPDATE
  @np_location_create :NP_LOCATION_CREATE
  @np_location_modify :NP_LOCATION_MODIFY
  @np_location_regenerate :NP_LOCATION_REGENERATE
  @np_location_description_update :NP_LOCATION_DESCRIPTION_UPDATE
  @np_prop_description_update :NP_PROP_DESCRIPTION_UPDATE
  @np_image_prompt_modify :NP_IMAGE_PROMPT_MODIFY
  @np_storyboard_edit :NP_STORYBOARD_EDIT
  @np_agent_storyboard_insert :NP_AGENT_STORYBOARD_INSERT
  @np_agent_shot_variant_analysis :NP_AGENT_SHOT_VARIANT_ANALYSIS
  @np_agent_shot_variant_generate :NP_AGENT_SHOT_VARIANT_GENERATE
  @np_single_panel_image :NP_SINGLE_PANEL_IMAGE
  @character_image_to_description :CHARACTER_IMAGE_TO_DESCRIPTION
  @character_reference_to_sheet :CHARACTER_REFERENCE_TO_SHEET
  @np_character_asset_suffix :NP_CHARACTER_ASSET_SUFFIX
  @np_prop_asset_suffix :NP_PROP_ASSET_SUFFIX
  @np_image_modify_character :NP_IMAGE_MODIFY_CHARACTER
  @np_image_modify_panel :NP_IMAGE_MODIFY_PANEL

  # Group 5 — Short Drama
  @sd_topic_selection :SD_TOPIC_SELECTION
  @sd_story_outline :SD_STORY_OUTLINE
  @sd_character_dev :SD_CHARACTER_DEV
  @sd_episode_directory :SD_EPISODE_DIRECTORY
  @sd_episode_script :SD_EPISODE_SCRIPT
  @sd_quality_review :SD_QUALITY_REVIEW
  @sd_compliance_check :SD_COMPLIANCE_CHECK
  @sd_overseas_adapt :SD_OVERSEAS_ADAPT

  # ---------------------------------------------------------------------------
  # Catalog — the single source of truth for every prompt entry
  # ---------------------------------------------------------------------------

  @type prompt_id :: atom()
  @type locale :: String.t()

  @type entry :: %{
          id: prompt_id(),
          label_zh: String.t(),
          label_en: String.t(),
          path: String.t(),
          vars: [atom()]
        }

  @type group :: %{
          key: String.t(),
          label_zh: String.t(),
          label_en: String.t(),
          prompts: [entry()]
        }

  @catalog [
    # ── Group 1: Story Creation ──────────────────────────────────────────
    %{
      key: "story_creation",
      label_zh: "创作起步",
      label_en: "Story Creation",
      prompts: [
        %{
          id: @np_ai_story_outline,
          label_zh: "AI 故事大纲",
          label_en: "AI Story Outline",
          path: "novel-promotion/ai_story_outline",
          vars: [:input]
        },
        %{
          id: @np_ai_story_expand,
          label_zh: "AI 故事扩写",
          label_en: "AI Story Expand",
          path: "novel-promotion/ai_story_expand",
          vars: [:input]
        }
      ]
    },

    # ── Group 2: Story to Script ─────────────────────────────────────────
    %{
      key: "story_to_script",
      label_zh: "故事转剧本",
      label_en: "Story to Script",
      prompts: [
        %{
          id: @np_agent_character_profile,
          label_zh: "角色分析",
          label_en: "Character Analysis",
          path: "novel-promotion/agent_character_profile",
          vars: [:input, :characters_lib_info]
        },
        %{
          id: @np_select_location,
          label_zh: "场景识别",
          label_en: "Location Selection",
          path: "novel-promotion/select_location",
          vars: [:input, :locations_lib_name]
        },
        %{
          id: @np_select_prop,
          label_zh: "道具识别",
          label_en: "Prop Selection",
          path: "novel-promotion/select_prop",
          vars: [:input, :props_lib_name]
        },
        %{
          id: @np_agent_clip,
          label_zh: "片段切割",
          label_en: "Clip Detection",
          path: "novel-promotion/agent_clip",
          vars: [
            :input,
            :locations_lib_name,
            :characters_lib_name,
            :props_lib_name,
            :characters_introduction
          ]
        },
        %{
          id: @np_screenplay_conversion,
          label_zh: "剧本转换",
          label_en: "Screenplay Conversion",
          path: "novel-promotion/screenplay_conversion",
          vars: [
            :clip_content,
            :locations_lib_name,
            :characters_lib_name,
            :props_lib_name,
            :characters_introduction,
            :clip_id
          ]
        }
      ]
    },

    # ── Group 3: Script to Storyboard ────────────────────────────────────
    %{
      key: "script_to_storyboard",
      label_zh: "剧本转分镜",
      label_en: "Script to Storyboard",
      prompts: [
        %{
          id: @np_agent_storyboard_plan,
          label_zh: "分镜规划 Phase 1",
          label_en: "Storyboard Plan Phase 1",
          path: "novel-promotion/agent_storyboard_plan",
          vars: [
            :characters_lib_name,
            :locations_lib_name,
            :characters_introduction,
            :characters_appearance_list,
            :characters_full_description,
            :props_description,
            :clip_json,
            :clip_content
          ]
        },
        %{
          id: @np_agent_cinematographer,
          label_zh: "摄影指导 Phase 2",
          label_en: "Cinematographer Phase 2",
          path: "novel-promotion/agent_cinematographer",
          vars: [
            :panels_json,
            :panel_count,
            :locations_description,
            :characters_info,
            :props_description
          ]
        },
        %{
          id: @np_agent_acting_direction,
          label_zh: "表演指导 Phase 2",
          label_en: "Acting Direction Phase 2",
          path: "novel-promotion/agent_acting_direction",
          vars: [:panels_json, :panel_count, :characters_info]
        },
        %{
          id: @np_agent_storyboard_detail,
          label_zh: "分镜细节 Phase 3",
          label_en: "Storyboard Detail Phase 3",
          path: "novel-promotion/agent_storyboard_detail",
          vars: [
            :panels_json,
            :characters_age_gender,
            :locations_description,
            :props_description
          ]
        },
        %{
          id: @np_voice_analysis,
          label_zh: "台词分析",
          label_en: "Voice Analysis",
          path: "novel-promotion/voice_analysis",
          vars: [:input, :characters_lib_name, :characters_introduction, :storyboard_json]
        },
        %{
          id: @np_agent_character_visual,
          label_zh: "角色视觉描述",
          label_en: "Character Visual",
          path: "novel-promotion/agent_character_visual",
          vars: [:character_profiles]
        },
        %{
          id: @np_fl_rewrite,
          label_zh: "FL 过渡提示词重写",
          label_en: "FL Transition Rewrite",
          path: "novel-promotion/fl_rewrite",
          vars: [
            :first_description,
            :last_description,
            :first_dialogue,
            :last_dialogue,
            :style
          ]
        }
      ]
    },

    # ── Group 4: Editing Helpers ─────────────────────────────────────────
    %{
      key: "editing_helpers",
      label_zh: "辅助编辑",
      label_en: "Editing Helpers",
      prompts: [
        %{
          id: @np_episode_split,
          label_zh: "章节拆分",
          label_en: "Episode Split",
          path: "novel-promotion/episode_split",
          vars: [:CONTENT]
        },
        %{
          id: @np_character_create,
          label_zh: "角色创建",
          label_en: "Character Create",
          path: "novel-promotion/character_create",
          vars: [:user_input]
        },
        %{
          id: @np_character_modify,
          label_zh: "角色修改",
          label_en: "Character Modify",
          path: "novel-promotion/character_modify",
          vars: [:character_input, :user_input]
        },
        %{
          id: @np_character_regenerate,
          label_zh: "角色重生成",
          label_en: "Character Regenerate",
          path: "novel-promotion/character_regenerate",
          vars: [:character_name, :current_descriptions, :change_reason, :novel_text]
        },
        %{
          id: @np_character_description_update,
          label_zh: "角色描述更新",
          label_en: "Character Desc Update",
          path: "novel-promotion/character_description_update",
          vars: [:original_description, :modify_instruction, :image_context]
        },
        %{
          id: @np_location_create,
          label_zh: "场景创建",
          label_en: "Location Create",
          path: "novel-promotion/location_create",
          vars: [:user_input]
        },
        %{
          id: @np_location_modify,
          label_zh: "场景修改",
          label_en: "Location Modify",
          path: "novel-promotion/location_modify",
          vars: [:location_name, :location_input, :user_input]
        },
        %{
          id: @np_location_regenerate,
          label_zh: "场景重生成",
          label_en: "Location Regenerate",
          path: "novel-promotion/location_regenerate",
          vars: [:location_name, :current_descriptions]
        },
        %{
          id: @np_location_description_update,
          label_zh: "场景描述更新",
          label_en: "Location Desc Update",
          path: "novel-promotion/location_description_update",
          vars: [:location_name, :original_description, :modify_instruction, :image_context]
        },
        %{
          id: @np_prop_description_update,
          label_zh: "道具描述更新",
          label_en: "Prop Desc Update",
          path: "novel-promotion/prop_description_update",
          vars: [:prop_name, :original_description, :modify_instruction, :image_context]
        },
        %{
          id: @np_image_prompt_modify,
          label_zh: "图像提示修改",
          label_en: "Image Prompt Modify",
          path: "novel-promotion/image_prompt_modify",
          vars: [:prompt_input, :user_input, :video_prompt_input]
        },
        %{
          id: @np_storyboard_edit,
          label_zh: "分镜编辑",
          label_en: "Storyboard Edit",
          path: "novel-promotion/storyboard_edit",
          vars: [:user_input]
        },
        %{
          id: @np_agent_storyboard_insert,
          label_zh: "分镜插入",
          label_en: "Storyboard Insert",
          path: "novel-promotion/agent_storyboard_insert",
          vars: [
            :prev_panel_json,
            :next_panel_json,
            :characters_full_description,
            :locations_description,
            :props_description,
            :user_input
          ]
        },
        %{
          id: @np_agent_shot_variant_analysis,
          label_zh: "镜头变体分析",
          label_en: "Shot Variant Analysis",
          path: "novel-promotion/agent_shot_variant_analysis",
          vars: [
            :panel_description,
            :shot_type,
            :camera_move,
            :location,
            :characters_info
          ]
        },
        %{
          id: @np_agent_shot_variant_generate,
          label_zh: "镜头变体生成",
          label_en: "Shot Variant Generate",
          path: "novel-promotion/agent_shot_variant_generate",
          vars: [
            :original_description,
            :original_shot_type,
            :original_camera_move,
            :location,
            :characters_info,
            :variant_title,
            :variant_description,
            :target_shot_type,
            :target_camera_move,
            :video_prompt,
            :character_assets,
            :location_asset,
            :aspect_ratio,
            :style
          ]
        },
        %{
          id: @np_single_panel_image,
          label_zh: "单面板图像提示",
          label_en: "Single Panel Image",
          path: "novel-promotion/single_panel_image",
          vars: [:storyboard_text_json_input, :source_text, :aspect_ratio, :style]
        },
        %{
          id: @character_image_to_description,
          label_zh: "图片转描述",
          label_en: "Image to Description",
          path: "character-reference/character_image_to_description",
          vars: []
        },
        %{
          id: @character_reference_to_sheet,
          label_zh: "参考图转角色",
          label_en: "Reference to Character",
          path: "character-reference/character_reference_to_sheet",
          vars: []
        },
        %{
          id: @np_character_asset_suffix,
          label_zh: "角色设定图后缀",
          label_en: "Character Asset Suffix",
          path: "novel-promotion/character_asset_suffix",
          vars: []
        },
        %{
          id: @np_prop_asset_suffix,
          label_zh: "道具设定图后缀",
          label_en: "Prop Asset Suffix",
          path: "novel-promotion/prop_asset_suffix",
          vars: []
        },
        %{
          id: @np_image_modify_character,
          label_zh: "角色图片修改指令",
          label_en: "Character Image Modify",
          path: "novel-promotion/image_modify_character",
          vars: [:modify_instruction]
        },
        %{
          id: @np_image_modify_panel,
          label_zh: "分镜图片修改指令",
          label_en: "Panel Image Modify",
          path: "novel-promotion/image_modify_panel",
          vars: [:modify_instruction]
        }
      ]
    },

    # ── Group 5: Short Drama ─────────────────────────────────────────────
    %{
      key: "short_drama",
      label_zh: "微短剧",
      label_en: "Short Drama",
      prompts: [
        %{
          id: @sd_topic_selection,
          label_zh: "选题立项",
          label_en: "Topic Selection",
          path: "short-drama/sd_topic_selection",
          vars: [:genre_preferences, :target_audience, :platform]
        },
        %{
          id: @sd_story_outline,
          label_zh: "故事大纲",
          label_en: "Story Outline",
          path: "short-drama/sd_story_outline",
          vars: [:topic_report, :episode_count, :tone]
        },
        %{
          id: @sd_character_dev,
          label_zh: "角色开发",
          label_en: "Character Dev",
          path: "short-drama/sd_character_dev",
          vars: [:story_outline, :genre]
        },
        %{
          id: @sd_episode_directory,
          label_zh: "分集目录",
          label_en: "Episode Directory",
          path: "short-drama/sd_episode_directory",
          vars: [:story_outline, :characters, :episode_count]
        },
        %{
          id: @sd_episode_script,
          label_zh: "分集剧本",
          label_en: "Episode Script",
          path: "short-drama/sd_episode_script",
          vars: [
            :episode_number,
            :episode_title,
            :episode_conflict,
            :story_outline,
            :characters,
            :previous_episode_summary
          ]
        },
        %{
          id: @sd_quality_review,
          label_zh: "质量审核",
          label_en: "Quality Review",
          path: "short-drama/sd_quality_review",
          vars: [:episode_script, :episode_number]
        },
        %{
          id: @sd_compliance_check,
          label_zh: "合规审查",
          label_en: "Compliance Check",
          path: "short-drama/sd_compliance_check",
          vars: [:script_content, :target_market]
        },
        %{
          id: @sd_overseas_adapt,
          label_zh: "出海适配",
          label_en: "Overseas Adapt",
          path: "short-drama/sd_overseas_adapt",
          vars: [:original_script, :target_platform, :target_language]
        }
      ]
    }
  ]

  # Build a flat lookup map at compile time: %{prompt_id => entry}
  @entry_index @catalog
               |> Enum.flat_map(fn group -> group.prompts end)
               |> Map.new(fn entry -> {entry.id, entry} end)

  # Persistent-term key namespace
  @pt_ns :astra_prompt_catalog

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Returns the five prompt groups with their metadata and nested prompt entries.
  """
  @spec list_groups() :: [group()]
  def list_groups, do: @catalog

  @doc """
  Returns the catalog entry for the given prompt ID, or `nil` if not found.

  ## Examples

      iex> AstraAutoEx.AI.PromptCatalog.get_entry(:NP_AI_STORY_OUTLINE)
      %{id: :NP_AI_STORY_OUTLINE, label_zh: "AI 故事大纲", ...}

  """
  @spec get_entry(prompt_id()) :: entry() | nil
  def get_entry(prompt_id) when is_atom(prompt_id) do
    Map.get(@entry_index, prompt_id)
  end

  @doc """
  Reads the template text for `prompt_id` in the given `locale` (default `"zh"`).

  Template files are resolved at `priv/prompts/{path_stem}.{locale}.txt`.
  The result is cached in `:persistent_term` so subsequent calls for the same
  prompt/locale pair are essentially zero-cost.

  Returns `{:ok, text}` or `{:error, reason}`.
  """
  @spec get_template(prompt_id(), locale()) :: {:ok, String.t()} | {:error, term()}
  def get_template(prompt_id, locale \\ "zh") do
    pt_key = {__MODULE__, @pt_ns, prompt_id, locale}

    case safe_persistent_get(pt_key) do
      {:ok, text} ->
        {:ok, text}

      :miss ->
        case get_entry(prompt_id) do
          nil ->
            {:error, :unknown_prompt}

          entry ->
            file = template_path(entry.path, locale)

            case File.read(file) do
              {:ok, text} ->
                :persistent_term.put(pt_key, text)
                {:ok, text}

              {:error, reason} ->
                {:error, {:file_read, file, reason}}
            end
        end
    end
  end

  @doc """
  Substitutes `{variable_name}` placeholders in `text` with values from `bindings`.

  `bindings` is a map or keyword list of `%{variable_name => value}`.
  Keys can be atoms or strings; both `{foo}` and `{:foo}` patterns are matched
  by the atom key `:foo`.

  Returns the rendered string.

  ## Examples

      iex> AstraAutoEx.AI.PromptCatalog.render("Hello {name}!", %{name: "World"})
      "Hello World!"

  """
  @spec render(String.t(), map() | keyword()) :: String.t()
  def render(text, bindings) when is_binary(text) do
    bindings = normalize_bindings(bindings)

    Regex.replace(~r/\{(\w+)\}/, text, fn full_match, var_name ->
      case Map.fetch(bindings, var_name) do
        {:ok, value} -> to_string(value)
        :error -> full_match
      end
    end)
  end

  @doc """
  Reads a template with user-override support.

  Checks `priv/prompts/overrides/{path_stem}.{locale}.txt` first.
  If not found, falls back to the default template at
  `priv/prompts/{path_stem}.{locale}.txt`.

  Returns `{:ok, text}` or `{:error, reason}`.
  """
  @spec get_template_with_override(prompt_id(), locale(), map() | nil) ::
          {:ok, String.t()} | {:error, term()}
  def get_template_with_override(prompt_id, locale \\ "zh", _opts \\ nil) do
    case get_entry(prompt_id) do
      nil ->
        {:error, :unknown_prompt}

      entry ->
        override_file = override_path(entry.path, locale)

        case File.read(override_file) do
          {:ok, text} -> {:ok, text}
          {:error, _} -> get_template(prompt_id, locale)
        end
    end
  end

  @doc """
  Convenience: load a template (with override support), then render it.

  Returns `{:ok, rendered}` or `{:error, reason}`.
  """
  @spec load_and_render(prompt_id(), map() | keyword(), locale()) ::
          {:ok, String.t()} | {:error, term()}
  def load_and_render(prompt_id, bindings, locale \\ "zh") do
    with {:ok, text} <- get_template_with_override(prompt_id, locale) do
      {:ok, render(text, bindings)}
    end
  end

  @doc """
  Returns all 44 prompt IDs as a flat list.
  """
  @spec list_ids() :: [prompt_id()]
  def list_ids do
    Map.keys(@entry_index)
  end

  @doc """
  Invalidates the cached template for the given prompt/locale pair so the next
  `get_template/2` call re-reads from disk. Useful after editing template files.
  """
  @spec invalidate_cache(prompt_id(), locale()) :: :ok
  def invalidate_cache(prompt_id, locale \\ "zh") do
    pt_key = {__MODULE__, @pt_ns, prompt_id, locale}

    try do
      :persistent_term.erase(pt_key)
    rescue
      ArgumentError -> :ok
    end

    :ok
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp priv_dir do
    case :code.priv_dir(:astra_auto_ex) do
      {:error, _} ->
        # Fallback for dev/test when the app isn't fully loaded
        Path.join([File.cwd!(), "priv"])

      dir ->
        List.to_string(dir)
    end
  end

  defp template_path(path_stem, locale) do
    Path.join([priv_dir(), "prompts", "#{path_stem}.#{locale}.txt"])
  end

  defp override_path(path_stem, locale) do
    Path.join([priv_dir(), "prompts", "overrides", "#{path_stem}.#{locale}.txt"])
  end

  defp safe_persistent_get(key) do
    try do
      {:ok, :persistent_term.get(key)}
    rescue
      ArgumentError -> :miss
    end
  end

  defp normalize_bindings(bindings) when is_list(bindings) do
    bindings |> Enum.into(%{}) |> normalize_bindings()
  end

  defp normalize_bindings(bindings) when is_map(bindings) do
    Map.new(bindings, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} when is_binary(k) -> {k, v}
    end)
  end
end
