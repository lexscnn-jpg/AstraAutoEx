defmodule AstraAutoEx.Workers.HandlerRegistry do
  @moduledoc """
  Maps task types to their handler modules.
  Each handler implements execute/1 which receives the task struct.
  """

  @handlers %{
    # Image handlers (Phase 4)
    "image_panel" => AstraAutoEx.Workers.Handlers.ImagePanel,
    "image_character" => AstraAutoEx.Workers.Handlers.ImageCharacter,
    "image_location" => AstraAutoEx.Workers.Handlers.ImageLocation,
    "panel_variant" => AstraAutoEx.Workers.Handlers.ImagePanel,
    "modify_asset_image" => AstraAutoEx.Workers.Handlers.ImagePanel,
    "regenerate_group" => AstraAutoEx.Workers.Handlers.ImagePanel,
    "asset_hub_image" => AstraAutoEx.Workers.Handlers.ImagePanel,
    "asset_hub_modify" => AstraAutoEx.Workers.Handlers.ImagePanel,
    # Video handlers (Phase 6)
    "video_panel" => AstraAutoEx.Workers.Handlers.VideoPanel,
    "lip_sync" => AstraAutoEx.Workers.Handlers.LipSync,
    "video_compose" => AstraAutoEx.Workers.Handlers.VideoCompose,
    # Voice handlers (Phase 6)
    "voice_line" => AstraAutoEx.Workers.Handlers.VoiceLine,
    "voice_design" => AstraAutoEx.Workers.Handlers.VoiceDesignHandler,
    "asset_hub_voice_design" => AstraAutoEx.Workers.Handlers.VoiceDesignHandler,
    "music_generate" => AstraAutoEx.Workers.Handlers.MusicGenerateHandler,
    # Text handlers (Phase 5)
    "analyze_novel" => AstraAutoEx.Workers.Handlers.AnalyzeNovel,
    "story_to_script_run" => AstraAutoEx.Workers.Handlers.StoryToScript,
    "script_to_storyboard_run" => AstraAutoEx.Workers.Handlers.ScriptToStoryboard,
    "clips_build" => AstraAutoEx.Workers.Handlers.ClipsBuild,
    "screenplay_convert" => AstraAutoEx.Workers.Handlers.ScreenplayConvert,
    "import_script_run" => AstraAutoEx.Workers.Handlers.ImportScript,
    # AI asset handlers (Phase 5)
    "ai_create_character" => AstraAutoEx.Workers.Handlers.AICreateCharacter,
    "ai_create_location" => AstraAutoEx.Workers.Handlers.AICreateLocation,
    "ai_modify_appearance" => AstraAutoEx.Workers.Handlers.AIModifyAppearance,
    "ai_modify_shot_prompt" => AstraAutoEx.Workers.Handlers.AIModifyShotPrompt,
    # Storyboard advanced handlers
    "storyboard_insert" => AstraAutoEx.Workers.Handlers.StoryboardInsert,
    "shot_variant" => AstraAutoEx.Workers.Handlers.ShotVariant,
    # Watchdog
    "watchdog" => AstraAutoEx.Workers.Handlers.Watchdog,
    # Short drama handlers (Phase 8) — all dispatch through ShortDrama module
    "sd_topic_selection" => AstraAutoEx.Workers.Handlers.ShortDrama,
    "sd_story_outline" => AstraAutoEx.Workers.Handlers.ShortDrama,
    "sd_character_dev" => AstraAutoEx.Workers.Handlers.ShortDrama,
    "sd_episode_directory" => AstraAutoEx.Workers.Handlers.ShortDrama,
    "sd_episode_script" => AstraAutoEx.Workers.Handlers.ShortDrama,
    "sd_quality_review" => AstraAutoEx.Workers.Handlers.ShortDrama,
    "sd_compliance_check" => AstraAutoEx.Workers.Handlers.ShortDrama,
    "sd_overseas_adapt" => AstraAutoEx.Workers.Handlers.ShortDrama
  }

  @doc "Get the handler module for a task type, or nil if not registered."
  def get_handler(task_type) do
    Map.get(@handlers, task_type)
  end

  @doc "Check if a handler is registered for this task type."
  def handler_registered?(task_type) do
    Map.has_key?(@handlers, task_type)
  end

  @doc "List all registered task types."
  def registered_types, do: Map.keys(@handlers)
end
