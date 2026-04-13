defmodule AstraAutoEx.Media.FFmpeg do
  @moduledoc """
  FFmpeg wrapper for video composition.
  Handles: concatenation, speed adjustment, SRT subtitles, BGM mixing.
  Ported from original AstraAuto video compose worker.
  """
  require Logger

  @doc """
  Compose final video from panel clips.
  Returns {:ok, output_path} or {:error, reason}.
  """
  def compose(clips, output_path, opts \\ []) do
    if ffmpeg_available?() do
      do_compose(clips, output_path, opts)
    else
      {:error, "FFmpeg not found. Install FFmpeg to enable video composition."}
    end
  end

  @doc "Generate SRT subtitle file from voice lines."
  def generate_srt(voice_lines, output_path) do
    srt_content =
      voice_lines
      |> Enum.with_index(1)
      |> Enum.map(fn {line, idx} ->
        start_time = format_srt_time(line.start_time || 0.0)

        end_time =
          format_srt_time(line.end_time || (line.start_time || 0.0) + (line.duration || 3.0))

        text = line.content || ""
        "#{idx}\n#{start_time} --> #{end_time}\n#{text}\n"
      end)
      |> Enum.join("\n")

    File.write(output_path, srt_content)
  end

  @doc "Concatenate video files."
  def concat(video_paths, output_path, opts \\ []) do
    # Create concat file list
    list_path = output_path <> ".list.txt"
    list_content = Enum.map(video_paths, fn p -> "file '#{p}'" end) |> Enum.join("\n")
    File.write!(list_path, list_content)

    args = [
      "-y",
      "-f",
      "concat",
      "-safe",
      "0",
      "-i",
      list_path,
      "-c",
      "copy"
    ]

    # Add subtitle if provided
    args =
      case Keyword.get(opts, :subtitle_path) do
        nil -> args
        srt -> args ++ ["-vf", "subtitles=#{srt}"]
      end

    args = args ++ [output_path]

    case run_ffmpeg(args) do
      {:ok, _} ->
        File.rm(list_path)
        {:ok, output_path}

      error ->
        File.rm(list_path)
        error
    end
  end

  @doc "Adjust video speed (0.85-1.2x range)."
  def adjust_speed(input_path, output_path, speed_factor) do
    speed = max(0.85, min(1.2, speed_factor))
    pts_factor = 1.0 / speed
    atempo = speed

    args = [
      "-y",
      "-i",
      input_path,
      "-filter:v",
      "setpts=#{pts_factor}*PTS",
      "-filter:a",
      "atempo=#{atempo}",
      "-c:v",
      "libx264",
      "-preset",
      "fast",
      "-c:a",
      "aac",
      output_path
    ]

    run_ffmpeg(args)
  end

  @doc "Mix BGM audio into video."
  def mix_bgm(video_path, bgm_path, output_path, opts \\ []) do
    bgm_volume = Keyword.get(opts, :bgm_volume, 0.15)

    args = [
      "-y",
      "-i",
      video_path,
      "-i",
      bgm_path,
      "-filter_complex",
      "[1:a]volume=#{bgm_volume}[bgm];[0:a][bgm]amix=inputs=2:duration=first[out]",
      "-map",
      "0:v",
      "-map",
      "[out]",
      "-c:v",
      "copy",
      "-c:a",
      "aac",
      output_path
    ]

    run_ffmpeg(args)
  end

  @doc "Add subtitles to video."
  def add_subtitles(video_path, srt_path, output_path) do
    args = [
      "-y",
      "-i",
      video_path,
      "-vf",
      "subtitles=#{srt_path}:force_style='FontSize=18,PrimaryColour=&H00FFFFFF'",
      "-c:v",
      "libx264",
      "-preset",
      "fast",
      "-c:a",
      "copy",
      output_path
    ]

    run_ffmpeg(args)
  end

  @doc "Get video duration in seconds."
  def get_duration(video_path) do
    args = [
      "-v",
      "error",
      "-show_entries",
      "format=duration",
      "-of",
      "default=noprint_wrappers=1:nokey=1",
      video_path
    ]

    case System.cmd("ffprobe", args, stderr_to_stdout: true) do
      {output, 0} ->
        case Float.parse(String.trim(output)) do
          {duration, _} -> {:ok, duration}
          :error -> {:error, "Could not parse duration"}
        end

      {output, _} ->
        {:error, "ffprobe failed: #{output}"}
    end
  end

  # ── Private ──

  defp do_compose(clips, output_path, opts) do
    tmp_dir = System.tmp_dir!()
    work_dir = Path.join(tmp_dir, "astra_compose_#{System.system_time(:millisecond)}")
    File.mkdir_p!(work_dir)

    try do
      # Download clips to temp files
      local_videos =
        clips
        |> Enum.with_index()
        |> Enum.map(fn {clip, idx} ->
          local_path =
            Path.join(work_dir, "clip_#{String.pad_leading(to_string(idx), 3, "0")}.mp4")

          case download_or_copy(clip.video_url, local_path) do
            :ok ->
              # Apply speed adjustment if needed
              target_duration = clip[:target_duration]

              if target_duration do
                case get_duration(local_path) do
                  {:ok, actual} when actual > 0 ->
                    speed = actual / target_duration

                    if speed >= 0.85 and speed <= 1.2 do
                      adjusted = local_path <> ".adj.mp4"
                      adjust_speed(local_path, adjusted, speed)
                      File.rename!(adjusted, local_path)
                    end

                  _ ->
                    :ok
                end
              end

              local_path

            {:error, reason} ->
              Logger.warning("[FFmpeg] Failed to download clip #{idx}: #{inspect(reason)}")
              nil
          end
        end)
        |> Enum.reject(&is_nil/1)

      if Enum.empty?(local_videos) do
        {:error, "No video clips available"}
      else
        # Concatenate
        concat_result = concat(local_videos, output_path, opts)

        # Add BGM if provided
        case {concat_result, Keyword.get(opts, :bgm_path)} do
          {{:ok, _}, bgm} when is_binary(bgm) ->
            final_path = output_path <> ".final.mp4"

            case mix_bgm(output_path, bgm, final_path, opts) do
              {:ok, _} -> File.rename!(final_path, output_path)
              _ -> :ok
            end

            {:ok, output_path}

          {{:ok, _}, _} ->
            {:ok, output_path}

          {error, _} ->
            error
        end
      end
    after
      File.rm_rf!(work_dir)
    end
  end

  defp download_or_copy(url, local_path) when is_binary(url) do
    cond do
      File.exists?(url) ->
        File.cp(url, local_path)

      String.starts_with?(url, "http") ->
        case Req.get(url, into: local_path, max_retries: 2, receive_timeout: 120_000) do
          {:ok, %{status: s}} when s in 200..299 -> :ok
          {:ok, %{status: s}} -> {:error, "HTTP #{s}"}
          {:error, reason} -> {:error, reason}
        end

      String.starts_with?(url, "/api/files/") ->
        key = String.replace_prefix(url, "/api/files/", "")
        upload_dir = Application.get_env(:astra_auto_ex, :upload_dir, "priv/uploads")
        source = Path.join(upload_dir, key)
        if File.exists?(source), do: File.cp(source, local_path), else: {:error, :not_found}

      true ->
        {:error, "Unknown URL format: #{url}"}
    end
  end

  defp run_ffmpeg(args) do
    case System.cmd("ffmpeg", args, stderr_to_stdout: true) do
      {_, 0} -> {:ok, :done}
      {output, code} -> {:error, "FFmpeg exited #{code}: #{String.slice(output, 0..500)}"}
    end
  end

  defp ffmpeg_available? do
    case System.cmd("ffmpeg", ["-version"], stderr_to_stdout: true) do
      {_, 0} -> true
      _ -> false
    end
  rescue
    _ -> false
  end

  defp format_srt_time(seconds) when is_number(seconds) do
    total_ms = trunc(seconds * 1000)
    h = div(total_ms, 3_600_000)
    m = div(rem(total_ms, 3_600_000), 60_000)
    s = div(rem(total_ms, 60_000), 1000)
    ms = rem(total_ms, 1000)
    "#{pad(h)}:#{pad(m)}:#{pad(s)},#{pad3(ms)}"
  end

  defp pad(n), do: String.pad_leading(to_string(n), 2, "0")
  defp pad3(n), do: String.pad_leading(to_string(n), 3, "0")
end
