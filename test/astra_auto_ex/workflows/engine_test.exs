defmodule AstraAutoEx.Workflows.EngineTest do
  use ExUnit.Case

  alias AstraAutoEx.Workflows.Engine

  describe "get_definition/1" do
    test "returns story_to_script workflow" do
      steps = Engine.get_definition("story_to_script")
      assert is_list(steps)
      assert length(steps) == 6
      assert Enum.any?(steps, fn s -> s.id == "analyze_characters" end)
      assert Enum.any?(steps, fn s -> s.id == "screenplay_convert" end)
    end

    test "returns script_to_storyboard workflow" do
      steps = Engine.get_definition("script_to_storyboard")
      assert is_list(steps)
      assert length(steps) == 4
      assert Enum.any?(steps, fn s -> s.id == "plan_panels" end)
    end

    test "returns nil for unknown workflow" do
      assert Engine.get_definition("nonexistent") == nil
    end
  end

  describe "list_workflow_types/0" do
    test "returns known workflow types" do
      types = Engine.list_workflow_types()
      assert "story_to_script" in types
      assert "script_to_storyboard" in types
    end
  end
end
