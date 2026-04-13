defmodule AstraAutoEx.AI.CapabilitiesTest do
  use ExUnit.Case

  alias AstraAutoEx.AI.Capabilities

  describe "get_model/1" do
    test "returns model info for known models" do
      assert %{provider: "minimax", type: :video} = Capabilities.get_model("hailuo-2.3")
      assert %{provider: "google", type: :llm} = Capabilities.get_model("gemini-2.5-flash")
      assert %{provider: "fal", type: :image} = Capabilities.get_model("flux-pro")
    end

    test "returns nil for unknown model" do
      assert Capabilities.get_model("nonexistent-model") == nil
    end
  end

  describe "provider_for/1" do
    test "returns correct provider" do
      assert Capabilities.provider_for("hailuo-2.3") == "minimax"
      assert Capabilities.provider_for("imagen-4") == "google"
      assert Capabilities.provider_for("seedream-3") == "ark"
    end
  end

  describe "type_for/1" do
    test "returns correct type" do
      assert Capabilities.type_for("flux-pro") == :image
      assert Capabilities.type_for("veo-3") == :video
      assert Capabilities.type_for("gemini-2.5-pro") == :llm
      assert Capabilities.type_for("speech-02-hd") == :tts
      assert Capabilities.type_for("music-01") == :music
    end
  end

  describe "list_models/1" do
    test "lists all models" do
      all = Capabilities.list_models()
      assert map_size(all) > 20
    end

    test "filters by provider" do
      google = Capabilities.list_models("google")
      assert map_size(google) > 0
      assert Enum.all?(google, fn {_, v} -> v.provider == "google" end)
    end
  end
end
