defmodule AstraAutoEx.Media.SubtitleGenerator do
  @moduledoc """
  Generates SRT subtitles with proper cumulative time offsets.

  Two generation modes:
  1. `generate_for_episode/2` - from voice lines with sequential timestamps
  2. `generate_for_panels/3` - from ordered panels + video durations (compose pipeline)

  The panel-based mode matches the original compose-srt.ts logic:
    cumulativeTime = 0
    for each panel:
      text = panel.srt_segment || voiceLine.content
      startTime = cumulativeTime + (panel.srt_start ?? 0)
      endTime = panel.srt_end ? cumulativeTime + panel.srt_end : cumulativeTime + video_duration
      cumulativeTime += video_duration
  """

  require Logger
  alias AstraAutoEx.Production

  # ── Panel-based SRT generation (for compose pipeline) ──

  @doc """
  Generate SRT file from ordered panels with video durations.

  Each panel contributes a subtitle entry using cumulative time offsets
  based on video durations (not voice durations).

  Parameters:
    - panels: list of panel maps, each with :id and optional :srt_segment, :srt_start, :srt_end
    - video_durations: list of durations in seconds, same order as panels
    - voice_lines: list of voice line maps with :matched_panel_id and :content
    - output_path: where to write the SRT file

  Returns {:ok, srt_path} or {:error, reason}.
  """
  @spec generate_for_panels([map()], [float()], [map()], String.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def generate_for_panels(panels, video_durations, voice_lines, output_path) do
    if length(panels) != length(video_durations) do
      {:error, "Panel count (#{length(panels)}) != duration count (#{length(video_durations)})"}
    else
      # Build voice line lookup: panel_id -> voice_line
      voice_map = build_voice_map(voice_lines)

      srt_content =
        panels
        |> Enum.zip(video_durations)
        |> build_panel_srt(voice_map)

      case File.write(output_path, srt_content) do
        :ok ->
          Logger.info(
            "[SubtitleGen] Generated panel SRT: #{output_path} (#{length(panels)} panels)"
          )

          {:ok, output_path}

        {:error, reason} ->
          {:error, "Failed to write SRT: #{inspect(reason)}"}
      end
    end
  end

  # Build SRT from panel+duration pairs using cumulative time offsets.
  defp build_panel_srt(panel_duration_pairs, voice_map) do
    {entries, _cumulative} =
      Enum.reduce(panel_duration_pairs, {[], 0.0}, fn {panel, video_dur}, {acc, cum_time} ->
        # Subtitle text: srt_segment takes priority, then voice line content
        text = resolve_subtitle_text(panel, voice_map)

        if text do
          # Start time: cumulative + panel-specific offset (default 0)
          start_time = cum_time + (panel[:srt_start] || 0.0)

          # End time: if panel has srt_end use cumulative + srt_end, else cumulative + video_duration
          end_time =
            if panel[:srt_end] do
              cum_time + panel.srt_end
            else
              cum_time + video_dur
            end

          entry = %{content: text, start_time: start_time, end_time: end_time}
          {acc ++ [entry], cum_time + video_dur}
        else
          {acc, cum_time + video_dur}
        end
      end)

    format_srt_entries(entries)
  end

  defp resolve_subtitle_text(panel, voice_map) do
    cond do
      panel[:srt_segment] && panel.srt_segment != "" ->
        panel.srt_segment

      panel[:id] && Map.has_key?(voice_map, panel.id) ->
        voice_map[panel.id].content

      true ->
        nil
    end
  end

  defp build_voice_map(voice_lines) do
    Enum.reduce(voice_lines, %{}, fn vl, acc ->
      panel_id = vl[:matched_panel_id] || vl[:panel_id]

      if panel_id && vl[:content] && vl.content != "" do
        Map.put(acc, panel_id, vl)
      else
        acc
      end
    end)
  end

  # ── Voice-line-based SRT generation (standalone mode) ──

  @doc """
  Generate SRT file from episode voice lines.

  Uses voice line audio durations for sequential timing.
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
      timed_lines = calculate_timestamps(voice_lines)
      output_dir = System.tmp_dir!()
      srt_path = Path.join(output_dir, "episode_#{episode_id}.srt")

      srt_content = format_srt_entries_with_speaker(timed_lines)
      File.write!(srt_path, srt_content)

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
    gap = 0.3

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

  @doc "Build SRT format string from timed lines (legacy API)."
  @spec build_srt([map()]) :: String.t()
  def build_srt(timed_lines), do: format_srt_entries_with_speaker(timed_lines)

  # ── Formatting Helpers ──

  # Format entries without speaker prefix (panel-based mode).
  defp format_srt_entries(entries) do
    entries
    |> Enum.with_index(1)
    |> Enum.map(fn {entry, idx} ->
      start_str = format_srt_time(entry.start_time)
      end_str = format_srt_time(entry.end_time)
      "#{idx}\n#{start_str} --> #{end_str}\n#{String.trim(entry.content)}\n"
    end)
    |> Enum.join("\n")
  end

  # Format entries with optional speaker prefix (voice-line mode).
  defp format_srt_entries_with_speaker(timed_lines) do
    timed_lines
    |> Enum.with_index(1)
    |> Enum.map(fn {line, idx} ->
      start_str = format_srt_time(line.start_time)
      end_str = format_srt_time(line.end_time)
      text = if line[:speaker], do: "[#{line.speaker}] #{line.content}", else: line.content
      "#{idx}\n#{start_str} --> #{end_str}\n#{text}\n"
    end)
    |> Enum.join("\n")
  end

  # Estimate duration from text length (Chinese ~4 chars/sec)
  defp estimate_duration(nil), do: 2.0
  defp estimate_duration(""), do: 2.0

  defp estimate_duration(text) do
    char_count = String.length(text)
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
