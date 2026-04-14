defmodule AstraAutoEx.Media.SubtitleGenerator do
  @moduledoc """
  Generates SRT subtitles from voice lines with proper timestamps.
  Calculates time codes based on audio durations and sequential ordering.
  """

  alias AstraAutoEx.Production

  @doc """
  Generate SRT file from episode voice lines.
  Returns {:ok, srt_path} or {:error, reason}.
  """
  @spec generate_for_episode(String.t(), Keyword.t()) :: {:ok, String.t()} | {:error, any()}
  def generate_for_episode(episode_id, opts \\ []) do
    voice_lines =
      Production.list_voice_lines(episode_id)
      |> Enum.filter(&(&1.audio_url != nil && &1.audio_url != ""))
      |> Enum.sort_by(& &1.line_index)

    if Enum.empty?(voice_lines) do
      {:error, "No voice lines with audio found"}
    else
      # Calculate timestamps based on audio durations
      timed_lines = calculate_timestamps(voice_lines)

      output_dir = System.tmp_dir!()
      srt_path = Path.join(output_dir, "episode_#{episode_id}.srt")

      srt_content = build_srt(timed_lines)
      File.write!(srt_path, srt_content)

      # Optionally save SRT content to episode
      if Keyword.get(opts, :persist, false) do
        episode = Production.get_episode!(episode_id)
        Production.update_episode(episode, %{srt_content: srt_content})
      end

      {:ok, srt_path}
    end
  end

  @doc """
  Calculate start/end timestamps for voice lines sequentially.
  Each line starts after the previous one ends, with a small gap.
  """
  @spec calculate_timestamps([map()]) :: [map()]
  def calculate_timestamps(voice_lines) do
    gap = 0.3  # 300ms gap between lines

    {lines, _} =
      Enum.map_reduce(voice_lines, 0.0, fn vl, current_time ->
        duration = vl.audio_duration || estimate_duration(vl.content)
        start_time = current_time
        end_time = current_time + duration

        timed = %{
          content: vl.content || "",
          speaker: vl.speaker,
          start_time: start_time,
          end_time: end_time,
          duration: duration,
          voice_line_id: vl.id,
          panel_id: vl.panel_id
        }

        {timed, end_time + gap}
      end)

    lines
  end

  @doc "Build SRT format string from timed lines."
  @spec build_srt([map()]) :: String.t()
  def build_srt(timed_lines) do
    timed_lines
    |> Enum.with_index(1)
    |> Enum.map(fn {line, idx} ->
      start_str = format_srt_time(line.start_time)
      end_str = format_srt_time(line.end_time)
      text = if line.speaker, do: "[#{line.speaker}] #{line.content}", else: line.content
      "#{idx}\n#{start_str} --> #{end_str}\n#{text}\n"
    end)
    |> Enum.join("\n")
  end

  # Estimate duration from text length (Chinese ~4 chars/sec, English ~3 words/sec)
  defp estimate_duration(nil), do: 2.0
  defp estimate_duration(""), do: 2.0

  defp estimate_duration(text) do
    char_count = String.length(text)
    # Rough: 4 characters per second for Chinese
    max(1.5, char_count / 4.0)
  end

  defp format_srt_time(seconds) when is_number(seconds) do
    total_ms = trunc(seconds * 1000)
    h = div(total_ms, 3_600_000)
    m = div(rem(total_ms, 3_600_000), 60_000)
    s = div(rem(total_ms, 60_000), 1000)
    ms = rem(total_ms, 1000)

    pad2 = &String.pad_leading(to_string(&1), 2, "0")
    pad3 = &String.pad_leading(to_string(&1), 3, "0")

    "#{pad2.(h)}:#{pad2.(m)}:#{pad2.(s)},#{pad3.(ms)}"
  end
end
