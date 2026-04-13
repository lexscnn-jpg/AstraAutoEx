defmodule AstraAutoEx.Workers.HandlerRegistryTest do
  use ExUnit.Case

  alias AstraAutoEx.Workers.HandlerRegistry

  describe "handler_registered?/1" do
    test "returns true for known task types" do
      for type <- ~w(image_panel image_character image_location video_panel voice_line
                     story_to_script_run script_to_storyboard_run analyze_novel
                     video_compose lip_sync voice_design music_generate
                     sd_topic_selection sd_story_outline sd_episode_script) do
        assert HandlerRegistry.handler_registered?(type), "Expected #{type} to be registered"
      end
    end

    test "returns false for unknown types" do
      refute HandlerRegistry.handler_registered?("unknown_task_type")
      refute HandlerRegistry.handler_registered?("nonexistent")
    end
  end

  describe "get_handler/1" do
    test "returns correct module for image_panel" do
      assert HandlerRegistry.get_handler("image_panel") == AstraAutoEx.Workers.Handlers.ImagePanel
    end

    test "returns correct module for voice_line" do
      assert HandlerRegistry.get_handler("voice_line") == AstraAutoEx.Workers.Handlers.VoiceLine
    end

    test "returns nil for unknown type" do
      assert HandlerRegistry.get_handler("unknown") == nil
    end
  end

  describe "registered_types/0" do
    test "returns a list of all registered types" do
      types = HandlerRegistry.registered_types()
      assert is_list(types)
      assert length(types) > 20
      assert "image_panel" in types
      assert "video_compose" in types
      assert "sd_topic_selection" in types
    end
  end
end
