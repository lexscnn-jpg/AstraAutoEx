defmodule AstraAutoEx.AI.ProvidersTest do
  use ExUnit.Case

  alias AstraAutoEx.AI.Providers.{Fal, Ark, Google, Minimax, Apiyi, RunningHub}

  describe "Provider capabilities" do
    test "FAL supports image and video" do
      assert :image in Fal.capabilities()
      assert :video in Fal.capabilities()
    end

    test "ARK supports image, video, and LLM" do
      assert :image in Ark.capabilities()
      assert :video in Ark.capabilities()
      assert :llm in Ark.capabilities()
    end

    test "Google supports image, video, and LLM" do
      assert :image in Google.capabilities()
      assert :video in Google.capabilities()
      assert :llm in Google.capabilities()
    end

    test "MiniMax supports image, video, TTS, and music" do
      caps = Minimax.capabilities()
      assert :image in caps
      assert :video in caps
      assert :tts in caps
      assert :music in caps
    end

    test "RunningHub supports image, video, LLM, and audio" do
      caps = RunningHub.capabilities()
      assert :image in caps
      assert :video in caps
      assert :llm in caps
      assert :audio in caps
    end

    test "Apiyi supports image, video, and LLM" do
      caps = Apiyi.capabilities()
      assert :image in caps
      assert :video in caps
      assert :llm in caps
    end
  end

  describe "All 6 providers compile and load" do
    test "all provider modules are loaded" do
      for mod <- [Fal, Ark, Google, Minimax, Apiyi, RunningHub] do
        assert Code.ensure_loaded?(mod), "#{inspect(mod)} should be loaded"
      end
    end

    test "all providers define capabilities/0" do
      for mod <- [Fal, Ark, Google, Minimax, Apiyi, RunningHub] do
        Code.ensure_loaded!(mod)

        assert function_exported?(mod, :capabilities, 0),
               "#{inspect(mod)} should have capabilities/0"

        caps = mod.capabilities()
        assert is_list(caps)
        assert length(caps) > 0
      end
    end
  end
end
