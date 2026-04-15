defmodule AstraAutoEx.Media.FFmpegTest do
  use ExUnit.Case

  alias AstraAutoEx.Media.FFmpeg

  describe "generate_srt/2" do
    test "generates valid SRT content" do
      lines = [
        %{content: "Hello world", start_time: 0.0, end_time: 2.5, duration: 2.5},
        %{content: "Second line", start_time: 3.0, end_time: 5.0, duration: 2.0}
      ]

      output = System.tmp_dir!() |> Path.join("test.srt")

      assert :ok = FFmpeg.generate_srt(lines, output)
      assert {:ok, content} = File.read(output)
      assert content =~ "1\n00:00:00,000 --> 00:00:02,500\nHello world"
      assert content =~ "2\n00:00:03,000 --> 00:00:05,000\nSecond line"

      File.rm(output)
    end

    test "handles nil start_time gracefully" do
      lines = [%{content: "No timing", start_time: nil, end_time: nil, duration: 3.0}]
      output = System.tmp_dir!() |> Path.join("test_nil.srt")

      assert :ok = FFmpeg.generate_srt(lines, output)
      assert {:ok, content} = File.read(output)
      assert content =~ "No timing"

      File.rm(output)
    end
  end

  describe "build_filter_graph/7" do
    test "single video produces no xfade filters" do
      {filters, video_out, audio_out} =
        FFmpeg.build_filter_graph(1, [5.0], [], nil, 5.0, [], nil)

      # Should have original audio concat only
      assert Enum.any?(filters, &String.contains?(&1, "concat=n=1:v=0:a=1[orig_audio]"))

      # Video output is just the first input
      assert video_out == "[0:v]"

      # Audio output is orig_audio (single input, no mixing)
      assert audio_out == "[orig_audio]"
    end

    test "two videos produce xfade transition with correct offset" do
      # 2 videos of 5s each, 0.5s transition
      opts = [transition_type: "fade", transition_duration: 0.5]

      {filters, video_out, _audio_out} =
        FFmpeg.build_filter_graph(2, [5.0, 4.0], [], nil, 9.0, opts, nil)

      # Should have xfade filter
      xfade_filter = Enum.find(filters, &String.contains?(&1, "xfade"))
      assert xfade_filter

      # offset = 5.0 - 0.5 = 4.5
      assert xfade_filter =~ "offset=4.500"
      assert xfade_filter =~ "duration=0.500"
      assert xfade_filter =~ "transition=fade"

      # Final label should be [vmerged]
      assert video_out == "[vmerged]"
    end

    test "three videos produce chained xfade with correct labels" do
      opts = [transition_type: "dissolve", transition_duration: 0.5]

      {filters, video_out, _} =
        FFmpeg.build_filter_graph(3, [3.0, 4.0, 5.0], [], nil, 12.0, opts, nil)

      xfade_filters = Enum.filter(filters, &String.contains?(&1, "xfade"))
      assert length(xfade_filters) == 2

      # First xfade: [0:v][1:v] -> [v1], offset = 3.0 - 0.5 = 2.5
      assert Enum.at(xfade_filters, 0) =~ "[v1]"
      assert Enum.at(xfade_filters, 0) =~ "offset=2.500"

      # Second xfade: [v1][2:v] -> [vmerged], offset = 2.5 + 4.0 - 0.5 = 6.0
      assert Enum.at(xfade_filters, 1) =~ "[vmerged]"
      assert Enum.at(xfade_filters, 1) =~ "offset=6.000"

      assert video_out == "[vmerged]"
    end

    test "zero transition duration uses concat instead of xfade" do
      opts = [transition_type: "fade", transition_duration: 0.0]

      {filters, _, _} =
        FFmpeg.build_filter_graph(2, [3.0, 4.0], [], nil, 7.0, opts, nil)

      assert Enum.any?(filters, &String.contains?(&1, "concat=n=2:v=1:a=0"))
      refute Enum.any?(filters, &String.contains?(&1, "xfade"))
    end

    test "speed factor adds setpts and atempo filters" do
      {filters, video_out, _} =
        FFmpeg.build_filter_graph(2, [5.0, 5.0], [], nil, 10.0, [], 1.1)

      # Speed filters for each input
      assert Enum.any?(filters, &String.contains?(&1, "[0:v]setpts=PTS/1.1000[sv0]"))
      assert Enum.any?(filters, &String.contains?(&1, "[0:a]atempo=1.1000[sa0]"))
      assert Enum.any?(filters, &String.contains?(&1, "[1:v]setpts=PTS/1.1000[sv1]"))

      # xfade should use speed-adjusted labels [sv0], [sv1]
      xfade = Enum.find(filters, &String.contains?(&1, "xfade"))
      assert xfade =~ "[sv0]"
      assert xfade =~ "[sv1]"
    end

    test "negligible speed factor (< 1% deviation) is ignored" do
      {filters, video_out, _} =
        FFmpeg.build_filter_graph(1, [5.0], [], nil, 5.0, [], 1.005)

      # No speed filters
      refute Enum.any?(filters, &String.contains?(&1, "setpts"))
      refute Enum.any?(filters, &String.contains?(&1, "atempo"))

      # Uses raw input label
      assert video_out == "[0:v]"
    end

    test "voice segments produce adelay and voice_mix filters" do
      voice_segs = [
        %{audio_path: "/tmp/v1.mp3", start_time: 2.0},
        %{audio_path: "/tmp/v2.mp3", start_time: 5.5}
      ]

      {filters, _, audio_out} =
        FFmpeg.build_filter_graph(2, [5.0, 5.0], voice_segs, nil, 10.0, [], nil)

      # adelay filters: voice input indices start at n=2
      assert Enum.any?(filters, &String.contains?(&1, "[2:a]adelay=2000|2000[vd0]"))
      assert Enum.any?(filters, &String.contains?(&1, "[3:a]adelay=5500|5500[vd1]"))

      # voice_mix amix
      assert Enum.any?(filters, &String.contains?(&1, "[voice_mix]"))

      # Final mix includes voice
      assert audio_out == "[aout]"

      # Check weights
      final_mix = Enum.find(filters, &String.contains?(&1, "[aout]"))
      assert final_mix =~ "weights=0.3 1.0"
    end

    test "single voice segment uses acopy instead of amix" do
      voice_segs = [%{audio_path: "/tmp/v1.mp3", start_time: 0.0}]

      {filters, _, _} =
        FFmpeg.build_filter_graph(1, [5.0], voice_segs, nil, 5.0, [], nil)

      assert Enum.any?(filters, &String.contains?(&1, "[vd0]acopy[voice_mix]"))
    end

    test "BGM produces volume and fade filters" do
      opts = [bgm_volume: 0.2, bgm_fade_in: 1.5, bgm_fade_out: 2.0]

      {filters, _, audio_out} =
        FFmpeg.build_filter_graph(2, [5.0, 5.0], [], "/tmp/bgm.mp3", 10.0, opts, nil)

      # BGM input index = 2 (after 2 videos, 0 voice)
      bgm_filter = Enum.find(filters, &String.contains?(&1, "[bgm_audio]"))
      assert bgm_filter
      assert bgm_filter =~ "[2:a]"
      assert bgm_filter =~ "volume=0.20"
      assert bgm_filter =~ "afade=t=in:d=1.5"
      assert bgm_filter =~ "afade=t=out:st=8.000:d=2.0"

      assert audio_out == "[aout]"

      final_mix = Enum.find(filters, &String.contains?(&1, "[aout]"))
      assert final_mix =~ "weights=0.3 1.0"
    end

    test "subtitle path adds burn-in filter" do
      opts = [subtitle_path: "/tmp/subs.srt"]

      {filters, video_out, _} =
        FFmpeg.build_filter_graph(1, [5.0], [], nil, 5.0, opts, nil)

      sub_filter = Enum.find(filters, &String.contains?(&1, "subtitles="))
      assert sub_filter
      assert sub_filter =~ "FontName=Noto Sans SC"
      assert sub_filter =~ "FontSize=24"
      assert sub_filter =~ "[vfinal]"

      assert video_out == "[vfinal]"
    end

    test "subtitle path with backslashes is escaped" do
      opts = [subtitle_path: "C:\\Users\\test\\subs.srt"]

      {filters, _, _} =
        FFmpeg.build_filter_graph(1, [5.0], [], nil, 5.0, opts, nil)

      sub_filter = Enum.find(filters, &String.contains?(&1, "subtitles="))
      # Backslashes should be converted to forward slashes
      assert sub_filter =~ "Users/test/subs.srt"
      # Colons should be escaped with backslash
      assert sub_filter =~ "C\\:"
    end

    test "full pipeline: videos + voice + BGM + subtitles" do
      voice_segs = [%{audio_path: "/tmp/v1.mp3", start_time: 0.0}]

      opts = [
        transition_type: "wipeleft",
        transition_duration: 0.3,
        subtitle_path: "/tmp/subs.srt",
        bgm_volume: 0.15,
        bgm_fade_in: 2.0,
        bgm_fade_out: 3.0
      ]

      {filters, video_out, audio_out} =
        FFmpeg.build_filter_graph(3, [4.0, 3.0, 5.0], voice_segs, "/tmp/bgm.mp3", 12.0, opts, nil)

      # Video: 2 xfade + 1 subtitle = filters present
      assert video_out == "[vfinal]"

      # Audio: orig_audio + voice + bgm -> aout
      assert audio_out == "[aout]"

      # 3-track mixing with correct weights
      final_mix = Enum.find(filters, &String.contains?(&1, "[aout]"))
      assert final_mix =~ "amix=inputs=3"
      assert final_mix =~ "weights=0.3 1.0 1.0"
    end
  end
end
