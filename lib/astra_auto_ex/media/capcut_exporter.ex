defmodule AstraAutoEx.Media.CapcutExporter do
  @moduledoc """
  Exports project timeline as CapCut/JianYing compatible XML format.
  Generates a draft JSON that can be imported into CapCut desktop app.
  """

  @doc """
  Export episode timeline as CapCut-compatible JSON draft.
  Returns {:ok, output_path} or {:error, reason}.
  """
  @spec export(map(), [map()], [map()]) :: {:ok, String.t()} | {:error, any()}
  def export(episode, panels, voice_lines) do
    if Enum.empty?(panels) do
      {:error, "No panels to export"}
    else
      draft = build_draft(episode, panels, voice_lines)
      output_dir = export_dir()
      File.mkdir_p!(output_dir)
      filename = "capcut_#{episode.id}_#{System.system_time(:second)}.json"
      output_path = Path.join(output_dir, filename)

      case Jason.encode(draft, pretty: true) do
        {:ok, json} ->
          File.write!(output_path, json)
          {:ok, output_path}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp build_draft(episode, panels, voice_lines) do
    # Calculate timeline from panels
    tracks = build_video_track(panels)
    audio_track = build_audio_track(voice_lines)

    %{
      "type" => "astra_auto_ex_export",
      "version" => "1.0",
      "name" => episode.title || "Episode #{episode.episode_number}",
      "canvas" => %{
        "width" => 1920,
        "height" => 1080
      },
      "tracks" => [
        %{
          "type" => "video",
          "segments" => tracks
        },
        %{
          "type" => "audio",
          "segments" => audio_track
        }
      ],
      "duration" => calculate_total_duration(panels),
      "panel_count" => length(panels),
      "export_time" => DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp build_video_track(panels) do
    {segments, _} =
      panels
      |> Enum.filter(&(&1.video_url && &1.video_url != ""))
      |> Enum.map_reduce(0, fn panel, offset ->
        duration = 5_000_000  # Default 5s in microseconds

        segment = %{
          "material_id" => panel.id,
          "source" => panel.video_url,
          "target_timerange" => %{
            "start" => offset,
            "duration" => duration
          },
          "description" => panel.description || ""
        }

        {segment, offset + duration}
      end)

    segments
  end

  defp build_audio_track(voice_lines) do
    {segments, _} =
      voice_lines
      |> Enum.filter(&(&1.audio_url && &1.audio_url != ""))
      |> Enum.map_reduce(0, fn vl, offset ->
        duration = trunc((vl.audio_duration || 3.0) * 1_000_000)

        segment = %{
          "material_id" => vl.id,
          "source" => vl.audio_url,
          "target_timerange" => %{
            "start" => offset,
            "duration" => duration
          },
          "speaker" => vl.speaker,
          "content" => vl.content
        }

        {segment, offset + duration + 300_000}
      end)

    segments
  end

  defp calculate_total_duration(panels) do
    video_panels = Enum.filter(panels, &(&1.video_url && &1.video_url != ""))
    length(video_panels) * 5_000_000
  end

  defp export_dir do
    upload_dir = Application.get_env(:astra_auto_ex, :upload_dir, "priv/uploads")
    Path.join(upload_dir, "exports")
  end
end
