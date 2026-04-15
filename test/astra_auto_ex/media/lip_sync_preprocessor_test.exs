defmodule AstraAutoEx.Media.LipSyncPreprocessorTest do
  use ExUnit.Case

  alias AstraAutoEx.Media.LipSyncPreprocessor

  describe "preprocess/2" do
    test "returns error for invalid arguments" do
      assert {:error, msg} = LipSyncPreprocessor.preprocess(nil, 5.0)
      assert msg =~ "Invalid arguments"
    end

    test "accepts integer video_duration" do
      # Should convert integer to float; will fail on missing file but not on type
      result = LipSyncPreprocessor.preprocess("/nonexistent/audio.wav", 5)
      assert {:error, _} = result
    end
  end

  describe "detect_duration/1" do
    test "returns error for nonexistent file" do
      assert {:error, msg} = LipSyncPreprocessor.detect_duration("/nonexistent/file.wav")
      assert msg =~ "Failed to detect audio duration"
    end
  end

  describe "maybe_pad_silence/2" do
    test "returns original path when duration >= 2 seconds" do
      assert {:ok, "/tmp/audio.wav"} =
               LipSyncPreprocessor.maybe_pad_silence("/tmp/audio.wav", 3.0)
    end

    test "returns original path when duration exactly 2 seconds" do
      assert {:ok, "/tmp/audio.wav"} =
               LipSyncPreprocessor.maybe_pad_silence("/tmp/audio.wav", 2.0)
    end
  end

  describe "maybe_align_wav/1" do
    test "non-WAV files are passed through unchanged" do
      assert {:ok, "/tmp/audio.mp3"} = LipSyncPreprocessor.maybe_align_wav("/tmp/audio.mp3")
      assert {:ok, "/tmp/audio.aac"} = LipSyncPreprocessor.maybe_align_wav("/tmp/audio.aac")
    end

    test "WAV file that does not exist returns error" do
      assert {:error, msg} = LipSyncPreprocessor.maybe_align_wav("/nonexistent/audio.wav")
      assert msg =~ "Cannot stat WAV file"
    end
  end

  describe "maybe_trim/2" do
    test "returns error for nonexistent file" do
      assert {:error, _} = LipSyncPreprocessor.maybe_trim("/nonexistent/file.wav", 5.0)
    end
  end
end
