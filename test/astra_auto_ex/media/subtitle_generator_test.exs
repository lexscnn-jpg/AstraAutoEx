defmodule AstraAutoEx.Media.SubtitleGeneratorTest do
  use ExUnit.Case

  alias AstraAutoEx.Media.SubtitleGenerator

  describe "generate_for_panels/4" do
    test "generates SRT with cumulative time offsets from video durations" do
      panels = [
        %{id: "p1", srt_segment: nil, srt_start: nil, srt_end: nil},
        %{id: "p2", srt_segment: nil, srt_start: nil, srt_end: nil},
        %{id: "p3", srt_segment: nil, srt_start: nil, srt_end: nil}
      ]

      video_durations = [3.0, 4.0, 5.0]

      voice_lines = [
        %{matched_panel_id: "p1", content: "First panel text"},
        %{matched_panel_id: "p2", content: "Second panel text"},
        %{matched_panel_id: "p3", content: "Third panel text"}
      ]

      output = Path.join(System.tmp_dir!(), "panel_srt_test.srt")

      assert {:ok, ^output} =
               SubtitleGenerator.generate_for_panels(
                 panels,
                 video_durations,
                 voice_lines,
                 output
               )

      {:ok, content} = File.read(output)

      # Panel 1: 0.0 -> 3.0 (cumulative 0 + duration 3)
      assert content =~ "1\n00:00:00,000 --> 00:00:03,000\nFirst panel text"

      # Panel 2: 3.0 -> 7.0 (cumulative 3 + duration 4)
      assert content =~ "2\n00:00:03,000 --> 00:00:07,000\nSecond panel text"

      # Panel 3: 7.0 -> 12.0 (cumulative 7 + duration 5)
      assert content =~ "3\n00:00:07,000 --> 00:00:12,000\nThird panel text"

      File.rm(output)
    end

    test "srt_segment takes priority over voice line content" do
      panels = [
        %{id: "p1", srt_segment: "Custom subtitle", srt_start: nil, srt_end: nil}
      ]

      voice_lines = [
        %{matched_panel_id: "p1", content: "Voice content (should be ignored)"}
      ]

      output = Path.join(System.tmp_dir!(), "panel_srt_priority.srt")

      assert {:ok, _} =
               SubtitleGenerator.generate_for_panels(
                 panels,
                 [5.0],
                 voice_lines,
                 output
               )

      {:ok, content} = File.read(output)
      assert content =~ "Custom subtitle"
      refute content =~ "should be ignored"

      File.rm(output)
    end

    test "srt_start and srt_end override default timing" do
      panels = [
        %{id: "p1", srt_segment: "Delayed text", srt_start: 1.0, srt_end: 2.5}
      ]

      output = Path.join(System.tmp_dir!(), "panel_srt_custom_time.srt")

      assert {:ok, _} =
               SubtitleGenerator.generate_for_panels(
                 panels,
                 [5.0],
                 [],
                 output
               )

      {:ok, content} = File.read(output)
      # Start: cumulative(0) + srt_start(1.0) = 1.0
      # End: cumulative(0) + srt_end(2.5) = 2.5
      assert content =~ "00:00:01,000 --> 00:00:02,500"

      File.rm(output)
    end

    test "panels without text are skipped" do
      panels = [
        %{id: "p1", srt_segment: "Has text", srt_start: nil, srt_end: nil},
        %{id: "p2", srt_segment: nil, srt_start: nil, srt_end: nil},
        %{id: "p3", srt_segment: "Also has text", srt_start: nil, srt_end: nil}
      ]

      output = Path.join(System.tmp_dir!(), "panel_srt_skip.srt")

      # p2 has no voice line match and no srt_segment
      assert {:ok, _} =
               SubtitleGenerator.generate_for_panels(
                 panels,
                 [3.0, 4.0, 5.0],
                 [],
                 output
               )

      {:ok, content} = File.read(output)
      # Should have entries 1 and 2 (p2 skipped), but cumulative time still accounts for p2
      assert content =~ "1\n00:00:00,000 --> 00:00:03,000\nHas text"
      # p3 starts at cumulative 7.0 (3+4), even though p2 was skipped
      assert content =~ "2\n00:00:07,000 --> 00:00:12,000\nAlso has text"

      File.rm(output)
    end

    test "returns error when panel count != duration count" do
      assert {:error, msg} =
               SubtitleGenerator.generate_for_panels(
                 [%{id: "p1"}],
                 [3.0, 4.0],
                 [],
                 "/tmp/mismatch.srt"
               )

      assert msg =~ "Panel count"
    end
  end

  describe "calculate_timestamps/1" do
    test "sequential timestamps with gap between lines" do
      voice_lines = [
        %{id: "vl1", panel_id: "p1", content: "Line 1", audio_duration: 2.0, speaker: "A"},
        %{id: "vl2", panel_id: "p2", content: "Line 2", audio_duration: 3.0, speaker: "B"}
      ]

      result = SubtitleGenerator.calculate_timestamps(voice_lines)

      assert length(result) == 2

      [first, second] = result
      assert first.start_time == 0.0
      assert first.end_time == 2.0
      # 300ms gap
      assert second.start_time == 2.3
      assert second.end_time == 5.3
    end

    test "estimates duration from text when audio_duration is nil" do
      voice_lines = [
        %{id: "vl1", panel_id: "p1", content: "Short", audio_duration: nil, speaker: nil}
      ]

      result = SubtitleGenerator.calculate_timestamps(voice_lines)
      [line] = result
      # "Short" = 5 chars, 5/4 = 1.25, min 1.5
      assert line.duration == 1.5
    end
  end

  describe "build_srt/1" do
    test "formats timed lines with speaker prefix" do
      timed = [
        %{content: "Hello", speaker: "Alice", start_time: 0.0, end_time: 2.0},
        %{content: "World", speaker: nil, start_time: 2.5, end_time: 4.0}
      ]

      result = SubtitleGenerator.build_srt(timed)

      assert result =~ "[Alice] Hello"
      assert result =~ "World"
      refute result =~ "[nil]"
    end
  end
end
