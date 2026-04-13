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
end
