defmodule AstraAutoEx.Media.FFmpeg do
  @moduledoc """
  FFmpeg wrapper for video composition with xfade transitions and 3-track audio mixing.

  Ported from original AstraAuto compose-ffmpeg.ts.

  Video chain:
    [i:v] -> setpts -> xfade chain -> subtitles burn-in -> [vfinal]

  Audio chain:
    Original audio concat -> voice adelay+amix -> BGM volume+fade -> 3-track amix
  """
  require Logger

  # Supported xfade transition types
  @valid_transitions ~w(fade dissolve wipeleft wiperight slideup slidedown)

  # ASS subtitle style for burn-in
  @ass_style "FontName=Noto Sans SC,FontSize=24,PrimaryColour=&HFFFFFF,OutlineColour=&H000000,Outline=2,Shadow=1"

  # ── Types ──

  @type clip :: %{
          video_url: String.t(),
          target_duration: float() | nil,
          panel_id: String.t() | nil,
          video_generation_mode: String.t() | nil,
          storyboard_id: String.t() | nil,
          panel_index: integer() | nil
        }

  @type voice_segment :: %{
          audio_path: String.t(),
          start_time: float()
        }

  @type compose_opts :: [
          transition_type: String.t(),
          transition_duration: float(),
          subtitle_path: String.t() | nil,
          bgm_path: String.t() | nil,
          bgm_volume: float(),
          bgm_fade_in: float(),
          bgm_fade_out: float(),
          voice_segments: [voice_segment()],
          speed_factor: float() | nil,
          skip_fl_tail: boolean()
        ]

  # ── Public API ──

  @doc """
  Compose final video from panel clips using filter_complex with xfade transitions
  and 3-track audio mixing (original + voice + BGM).

  Options:
    - transition_type: one of #{inspect(@valid_transitions)} (default: "fade")
    - transition_duration: seconds (default: 0.5)
    - subtitle_path: path to SRT file for burn-in
    - bgm_path: path to BGM audio file
    - bgm_volume: BGM volume 0.0-1.0 (default: 0.15)
    - bgm_fade_in: BGM fade-in seconds (default: 2.0)
    - bgm_fade_out: BGM fade-out seconds (default: 3.0)
    - voice_segments: list of %{audio_path, start_time} for voiceover mixing
    - speed_factor: playback speed 0.85-1.2 (nil = no adjustment)
    - skip_fl_tail: skip FL tail panels (default: true)
  """
  @spec compose(list(clip()), String.t(), compose_opts()) ::
          {:ok, String.t()} | {:error, String.t()}
  def compose(clips, output_path, opts \\ []) do
    cond do
      not ffmpeg_available?() ->
        {:error, "FFmpeg not found. Install FFmpeg to enable video composition."}

      # Force simple concat when explicitly requested, OR as a fallback after
      # filter_complex fails (caller can retry with this option).
      Keyword.get(opts, :mode) == :simple_concat ->
        simple_concat(clips, output_path, opts)

      true ->
        case do_compose(clips, output_path, opts) do
          {:ok, path} ->
            {:ok, path}

          {:error, reason} ->
            Logger.warning("[FFmpeg] filter_complex failed (#{reason}), retrying with simple concat")
            simple_concat(clips, output_path, opts)
        end
    end
  end

  @doc """
  Simple concat composition using the ffmpeg concat demuxer.
  No transitions. Optional subtitle burn-in via opts[:subtitle_path].
  Used as a fallback when filter_complex (xfade) fails.
  """
  @spec simple_concat(list(map()), String.t(), compose_opts()) :: {:ok, String.t()} | {:error, String.t()}
  def simple_concat(clips, output_path, opts \\ []) do
    work_dir = Path.join(System.tmp_dir!(), "astra_concat_#{System.system_time(:millisecond)}")
    File.mkdir_p!(work_dir)

    try do
      # Download/copy all clip sources to local files
      local =
        clips
        |> Enum.with_index()
        |> Enum.map(fn {c, idx} ->
          dest = Path.join(work_dir, "clip_#{idx}.mp4")

          case ensure_local_file(c.video_url, ".mp4") do
            {:ok, src_path} ->
              if src_path != dest, do: File.cp!(src_path, dest)
              dest

            {:error, _} ->
              nil
          end
        end)
        |> Enum.reject(&is_nil/1)

      if Enum.empty?(local) do
        {:error, "No clips available for concat"}
      else
        # Write concat list file (ffmpeg concat demuxer format)
        list_path = Path.join(work_dir, "list.txt")

        list_content =
          local
          |> Enum.map(fn p -> "file '#{String.replace(p, "'", "\\''")}'" end)
          |> Enum.join("\n")

        File.write!(list_path, list_content)

        subtitle_path = Keyword.get(opts, :subtitle_path)

        # With subtitles we MUST re-encode (filter can't run on -c copy).
        if is_binary(subtitle_path) and File.exists?(subtitle_path) do
          reencode_concat(list_path, output_path, subtitle_path: subtitle_path)
        else
          args = [
            "-y",
            "-f",
            "concat",
            "-safe",
            "0",
            "-i",
            list_path,
            "-c",
            "copy",
            output_path
          ]

          case System.cmd("ffmpeg", args, stderr_to_stdout: true) do
            {_, 0} ->
              if File.exists?(output_path) do
                {:ok, output_path}
              else
                # codec copy can fail silently on mixed streams — re-encode
                reencode_concat(list_path, output_path)
              end

            {out, _code} ->
              Logger.warning("[FFmpeg] concat -c copy failed, retrying with re-encode: #{String.slice(out, -300, 300)}")
              reencode_concat(list_path, output_path)
          end
        end
      end
    after
      File.rm_rf!(work_dir)
    end
  end

  defp reencode_concat(list_path, output_path, opts \\ []) do
    subtitle_path = Keyword.get(opts, :subtitle_path)

    # ffmpeg subtitles filter needs forward-slashes even on Windows, and single
    # quotes around any path containing special chars.
    vf_arg =
      if subtitle_path do
        # Escape backslashes & colons for Windows paths inside filter strings
        escaped = subtitle_path |> String.replace("\\", "/") |> String.replace(":", "\\:")
        "subtitles='#{escaped}':force_style='Fontsize=22,PrimaryColour=&Hffffff&,Outline=2,BorderStyle=1'"
      else
        nil
      end

    base = [
      "-y",
      "-f",
      "concat",
      "-safe",
      "0",
      "-i",
      list_path,
      "-c:v",
      "libx264",
      "-pix_fmt",
      "yuv420p",
      "-c:a",
      "aac"
    ]

    args =
      if vf_arg do
        base ++ ["-vf", vf_arg, output_path]
      else
        base ++ [output_path]
      end

    case System.cmd("ffmpeg", args, stderr_to_stdout: true) do
      {_, 0} ->
        if File.exists?(output_path) do
          {:ok, output_path}
        else
          {:error, "concat re-encode produced no output"}
        end

      {out, code} ->
        {:error, "concat re-encode exited #{code}: #{String.slice(out, -400, 400)}"}
    end
  end

  @doc "Get media duration in seconds using ffprobe."
  @spec get_duration(String.t()) :: {:ok, float()} | {:error, String.t()}
  def get_duration(path) do
    args = [
      "-v",
      "error",
      "-show_entries",
      "format=duration",
      "-of",
      "default=noprint_wrappers=1:nokey=1",
      path
    ]

    case System.cmd("ffprobe", args, stderr_to_stdout: true) do
      {output, 0} ->
        case Float.parse(String.trim(output)) do
          {duration, _} -> {:ok, duration}
          :error -> {:error, "Could not parse duration from: #{String.trim(output)}"}
        end

      {output, code} ->
        {:error, "ffprobe exited #{code}: #{String.slice(output, 0..200)}"}
    end
  end

  @doc "Check if FFmpeg is available on the system."
  @spec ffmpeg_available?() :: boolean()
  def ffmpeg_available? do
    case System.cmd("ffmpeg", ["-version"], stderr_to_stdout: true) do
      {_, 0} -> true
      _ -> false
    end
  rescue
    _ -> false
  end

  @doc """
  Convert a still image (local path or http(s) URL) into an mp4 video clip
  of the given duration. Used by VideoCompose as a fallback when panels have
  images but no generated video yet.
  """
  @spec image_to_video(String.t(), number(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def image_to_video(image_source, duration_seconds, output_path) do
    with {:ok, local_image} <- ensure_local_file(image_source, ".jpg") do
      args = [
        "-y",
        # loop the single image as source
        "-loop",
        "1",
        "-i",
        local_image,
        # silent audio so the clip has an audio track compatible with later concat/mixing
        "-f",
        "lavfi",
        "-i",
        "anullsrc=channel_layout=stereo:sample_rate=44100",
        "-t",
        to_string(duration_seconds),
        "-c:v",
        "libx264",
        "-tune",
        "stillimage",
        "-pix_fmt",
        "yuv420p",
        # pad to even dimensions (libx264 requires)
        "-vf",
        "scale=trunc(iw/2)*2:trunc(ih/2)*2",
        "-c:a",
        "aac",
        "-shortest",
        output_path
      ]

      case System.cmd("ffmpeg", args, stderr_to_stdout: true) do
        {_, 0} -> {:ok, output_path}
        {out, code} -> {:error, "ffmpeg image→video exited #{code}: #{String.slice(out, -400, 400)}"}
      end
    end
  end

  # If the source is an http(s) URL, download it to a temp file.
  # If it's a local file, return as-is.
  defp ensure_local_file("http" <> _ = url, default_ext) do
    ext =
      case Path.extname(URI.parse(url).path || "") do
        e when byte_size(e) > 0 and byte_size(e) <= 5 -> e
        _ -> default_ext
      end

    tmp = Path.join(System.tmp_dir!(), "astra-img-#{:erlang.unique_integer([:positive])}#{ext}")

    case Req.get(url, receive_timeout: 30_000, retry: false) do
      {:ok, %{status: 200, body: body}} ->
        File.write!(tmp, body)
        {:ok, tmp}

      {:ok, %{status: status}} ->
        {:error, "download failed: HTTP #{status}"}

      {:error, reason} ->
        {:error, "download error: #{inspect(reason)}"}
    end
  end

  defp ensure_local_file(path, _default_ext) when is_binary(path), do: {:ok, path}
  defp ensure_local_file(_, _), do: {:error, "invalid image source"}

  @doc "Generate SRT subtitle file from voice line maps."
  @spec generate_srt([map()], String.t()) :: :ok | {:error, any()}
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

  # ── Private: Main composition pipeline ──

  defp do_compose(clips, output_path, opts) do
    work_dir = create_work_dir()

    try do
      local_videos = download_clips(clips, work_dir, opts)

      if Enum.empty?(local_videos) do
        {:error, "No video clips available after download"}
      else
        compose_with_filter_complex(local_videos, output_path, work_dir, opts)
      end
    after
      File.rm_rf!(work_dir)
    end
  end

  defp create_work_dir do
    dir = Path.join(System.tmp_dir!(), "astra_compose_#{System.system_time(:millisecond)}")
    File.mkdir_p!(dir)
    dir
  end

  @doc false
  # Download clips to local temp files, applying FL tail skip and speed adjustment.
  defp download_clips(clips, work_dir, opts) do
    skip_fl_tail = Keyword.get(opts, :skip_fl_tail, true)

    clips
    |> maybe_filter_fl_tails(skip_fl_tail)
    |> Enum.with_index()
    |> Enum.map(fn {clip, idx} ->
      local_path = Path.join(work_dir, "clip_#{String.pad_leading(to_string(idx), 3, "0")}.mp4")

      case download_or_copy(clip.video_url, local_path) do
        :ok ->
          maybe_apply_speed(local_path, clip[:target_duration])
          local_path

        {:error, reason} ->
          Logger.warning("[FFmpeg] Failed to download clip #{idx}: #{inspect(reason)}")
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  # Filter out FL (first-last frame) tail panels.
  # The tail panel in a storyboard with FL videos has no independent video.
  defp maybe_filter_fl_tails(clips, false), do: clips

  defp maybe_filter_fl_tails(clips, true) do
    # Group by storyboard_id to find FL tails
    by_storyboard =
      clips
      |> Enum.filter(& &1[:storyboard_id])
      |> Enum.group_by(& &1.storyboard_id)

    fl_tail_ids =
      Enum.flat_map(by_storyboard, fn {_sb_id, sb_clips} ->
        has_fl = Enum.any?(sb_clips, &(&1[:video_generation_mode] == "firstlastframe"))

        if has_fl and length(sb_clips) >= 2 do
          sorted = Enum.sort_by(sb_clips, & &1[:panel_index])
          last = List.last(sorted)
          if last[:panel_id], do: [last.panel_id], else: []
        else
          []
        end
      end)
      |> MapSet.new()

    if MapSet.size(fl_tail_ids) > 0 do
      Logger.info("[FFmpeg] Skipping #{MapSet.size(fl_tail_ids)} FL tail panel(s)")
    end

    Enum.reject(clips, &MapSet.member?(fl_tail_ids, &1[:panel_id]))
  end

  # Apply speed adjustment if target_duration differs from actual.
  # Only adjusts within [0.85, 1.2] range with >3% deviation.
  defp maybe_apply_speed(_local_path, nil), do: :ok

  defp maybe_apply_speed(local_path, target_duration) when target_duration > 0 do
    case get_duration(local_path) do
      {:ok, actual} when actual > 0 ->
        factor = actual / target_duration

        if factor >= 0.85 and factor <= 1.2 and abs(factor - 1.0) > 0.03 do
          adjusted = local_path <> ".adj.mp4"
          adjust_speed(local_path, adjusted, factor)
          File.rename!(adjusted, local_path)
        end

      _ ->
        :ok
    end
  end

  defp maybe_apply_speed(_local_path, _), do: :ok

  # ── Filter Complex Builder ──

  @spec compose_with_filter_complex([String.t()], String.t(), String.t(), compose_opts()) ::
          {:ok, String.t()} | {:error, String.t()}
  defp compose_with_filter_complex(local_videos, output_path, _work_dir, opts) do
    n = length(local_videos)
    voice_segments = Keyword.get(opts, :voice_segments, [])
    bgm_path = Keyword.get(opts, :bgm_path)

    # Probe durations for all videos
    durations = probe_all_durations(local_videos)
    total_duration = Enum.sum(durations)

    Logger.info("[FFmpeg] Composing #{n} videos, total=#{Float.round(total_duration, 1)}s")

    # Build filter_complex string
    speed_factor = Keyword.get(opts, :speed_factor)

    {filters, video_out, audio_out} =
      build_filter_graph(
        n,
        durations,
        voice_segments,
        bgm_path,
        total_duration,
        opts,
        speed_factor
      )

    # Build ffmpeg args
    args =
      build_ffmpeg_args(
        local_videos,
        voice_segments,
        bgm_path,
        filters,
        video_out,
        audio_out,
        output_path
      )

    Logger.info("[FFmpeg] filter_complex: #{length(filters)} rules")

    case run_ffmpeg(args) do
      {:ok, _} ->
        case File.exists?(output_path) do
          true ->
            {:ok, output_path}

          false ->
            {:error, "FFmpeg exited 0 but output file not created (no-op filter graph?)"}
        end

      {:error, reason} ->
        Logger.error("[FFmpeg] #{reason}")
        {:error, reason}
    end
  end

  # Probe duration of each video, defaulting to 5.0s on failure.
  defp probe_all_durations(video_paths) do
    Enum.map(video_paths, fn path ->
      case get_duration(path) do
        {:ok, d} when d > 0 -> d
        _ -> 5.0
      end
    end)
  end

  @doc false
  # Build the complete filter graph with video xfade, subtitle burn-in, and 3-track audio.
  # Returns {filter_list, video_output_label, audio_output_label}.
  @spec build_filter_graph(
          integer(),
          [float()],
          [voice_segment()],
          String.t() | nil,
          float(),
          compose_opts(),
          float() | nil
        ) :: {[String.t()], String.t(), String.t()}
  def build_filter_graph(
        n,
        durations,
        voice_segments,
        bgm_path,
        total_duration,
        opts,
        speed_factor
      ) do
    filters = []

    # Speed adjustment preprocessing
    {filters, adjusted_durations, has_speed} =
      build_speed_filters(filters, n, durations, speed_factor)

    # Video chain: xfade transitions
    {filters, video_out} =
      build_video_chain(filters, n, adjusted_durations, has_speed, opts)

    # Subtitle burn-in
    {filters, video_out} =
      build_subtitle_filter(filters, video_out, opts)

    # Audio chain: original + voice + BGM -> 3-track mix
    {filters, audio_out} =
      build_audio_chain(filters, n, has_speed, voice_segments, bgm_path, total_duration, opts)

    {filters, video_out, audio_out}
  end

  # ── Speed Filters ──

  # Apply setpts (video) and atempo (audio) for speed adjustment.
  # setpts=PTS/factor: factor>1 compresses timestamps -> faster playback.
  # atempo=factor: matches audio speed to video.
  defp build_speed_filters(filters, _n, durations, nil), do: {filters, durations, false}

  defp build_speed_filters(filters, _n, durations, factor)
       when abs(factor - 1.0) <= 0.01 do
    {filters, durations, false}
  end

  defp build_speed_filters(filters, n, durations, factor) do
    clamped = max(0.85, min(1.2, factor))
    factor_str = :erlang.float_to_binary(clamped, decimals: 4)

    new_filters =
      Enum.flat_map(0..(n - 1), fn i ->
        [
          "[#{i}:v]setpts=PTS/#{factor_str}[sv#{i}]",
          "[#{i}:a]atempo=#{factor_str}[sa#{i}]"
        ]
      end)

    adjusted = Enum.map(durations, &(&1 / clamped))
    {filters ++ new_filters, adjusted, true}
  end

  # ── Video Chain: xfade transitions ──

  # Build xfade chain between consecutive video streams.
  # offset = cumulative_duration - transition_duration
  defp build_video_chain(filters, 1, _durations, has_speed, _opts) do
    label = if has_speed, do: "[sv0]", else: "[0:v]"
    {filters, label}
  end

  defp build_video_chain(filters, n, durations, has_speed, opts) do
    transition_type = Keyword.get(opts, :transition_type, "fade")
    transition_dur = Keyword.get(opts, :transition_duration, 0.5)

    # Validate transition type
    xfade_type =
      if transition_type in @valid_transitions, do: transition_type, else: "fade"

    # Input label: [sv0] if speed-adjusted, [0:v] otherwise
    vin = fn i -> if has_speed, do: "[sv#{i}]", else: "[#{i}:v]" end

    {xfade_filters, _cum, last_label} =
      Enum.reduce(1..(n - 1), {[], Enum.at(durations, 0), vin.(0)}, fn i, {acc, cum_dur, prev} ->
        # offset = total accumulated duration so far minus transition overlap
        offset = max(0.0, cum_dur - transition_dur)
        offset_str = :erlang.float_to_binary(offset, decimals: 3)
        dur_str = :erlang.float_to_binary(transition_dur, decimals: 3)

        # Final segment uses [vmerged], intermediates use [v1], [v2], etc.
        out_label = if i == n - 1, do: "[vmerged]", else: "[v#{i}]"

        filter =
          if transition_dur > 0 do
            "#{prev}#{vin.(i)}xfade=transition=#{xfade_type}:duration=#{dur_str}:offset=#{offset_str}#{out_label}"
          else
            "#{prev}#{vin.(i)}concat=n=2:v=1:a=0#{out_label}"
          end

        # Next cumulative = offset + current video duration
        new_cum = offset + Enum.at(durations, i)
        {acc ++ [filter], new_cum, out_label}
      end)

    {filters ++ xfade_filters, last_label}
  end

  # ── Subtitle Burn-in ──

  # Add subtitles filter with ASS style if subtitle_path is provided.
  defp build_subtitle_filter(filters, video_out, opts) do
    case Keyword.get(opts, :subtitle_path) do
      nil ->
        {filters, video_out}

      "" ->
        {filters, video_out}

      srt_path ->
        # Escape path for FFmpeg filter: backslashes -> forward slashes, colons escaped
        escaped =
          srt_path
          |> String.replace("\\", "/")
          |> String.replace(":", "\\:")
          |> String.replace("'", "\\'")

        sub_filter = "#{video_out}subtitles='#{escaped}':force_style='#{@ass_style}'[vfinal]"
        {filters ++ [sub_filter], "[vfinal]"}
    end
  end

  # ── Audio Chain: 3-track mixing ──

  # Build audio pipeline: original concat -> voice adelay+amix -> BGM fade -> final amix.
  # Weights: original=0.3, voice=1.0, BGM=1.0
  defp build_audio_chain(filters, n, has_speed, voice_segments, bgm_path, total_duration, opts) do
    # 1. Concat original video audio tracks
    ain = fn i -> if has_speed, do: "[sa#{i}]", else: "[#{i}:a]" end
    audio_labels = Enum.map_join(0..(n - 1), "", &ain.(&1))
    orig_filter = "#{audio_labels}concat=n=#{n}:v=0:a=1[orig_audio]"
    filters = filters ++ [orig_filter]

    mix_inputs = ["[orig_audio]"]
    mix_weights = ["0.3"]

    # 2. Voice segments: adelay for positioning, then amix
    {filters, mix_inputs, mix_weights} =
      build_voice_filters(filters, mix_inputs, mix_weights, voice_segments, n)

    # 3. BGM: volume + fade in/out
    {filters, mix_inputs, mix_weights} =
      build_bgm_filter(
        filters,
        mix_inputs,
        mix_weights,
        bgm_path,
        total_duration,
        n,
        voice_segments,
        opts
      )

    # 4. Final mix
    case length(mix_inputs) do
      1 ->
        # Only original audio, no mixing needed
        {filters, "[orig_audio]"}

      count ->
        inputs_str = Enum.join(mix_inputs, "")
        weights_str = Enum.join(mix_weights, " ")

        final =
          "#{inputs_str}amix=inputs=#{count}:duration=longest:weights=#{weights_str}:normalize=0[aout]"

        {filters ++ [final], "[aout]"}
    end
  end

  # Voice segments: each gets adelay for time positioning, then mixed together.
  defp build_voice_filters(filters, mix_inputs, mix_weights, [], _n) do
    {filters, mix_inputs, mix_weights}
  end

  defp build_voice_filters(filters, mix_inputs, mix_weights, voice_segments, n) do
    # Voice inputs start after video inputs (index n, n+1, ...)
    voice_filters =
      voice_segments
      |> Enum.with_index()
      |> Enum.map(fn {seg, i} ->
        input_idx = n + i
        delay_ms = trunc((seg.start_time || 0.0) * 1000)
        "[#{input_idx}:a]adelay=#{delay_ms}|#{delay_ms}[vd#{i}]"
      end)

    voice_labels = Enum.map_join(0..(length(voice_segments) - 1), "", &"[vd#{&1}]")

    voice_mix_filter =
      if length(voice_segments) == 1 do
        # Single voice: just copy
        "[vd0]acopy[voice_mix]"
      else
        # Multiple voices: amix
        "#{voice_labels}amix=inputs=#{length(voice_segments)}:duration=longest:normalize=0[voice_mix]"
      end

    {
      filters ++ voice_filters ++ [voice_mix_filter],
      mix_inputs ++ ["[voice_mix]"],
      mix_weights ++ ["1.0"]
    }
  end

  # BGM: volume control + fade in at start + fade out before end.
  defp build_bgm_filter(filters, mix_inputs, mix_weights, nil, _total, _n, _vs, _opts) do
    {filters, mix_inputs, mix_weights}
  end

  defp build_bgm_filter(
         filters,
         mix_inputs,
         mix_weights,
         _bgm_path,
         total_duration,
         n,
         voice_segments,
         opts
       ) do
    bgm_volume = Keyword.get(opts, :bgm_volume, 0.15)
    fade_in = Keyword.get(opts, :bgm_fade_in, 2.0)
    fade_out = Keyword.get(opts, :bgm_fade_out, 3.0)
    fade_out_start = max(0.0, total_duration - fade_out)

    # BGM input index is after videos and voice segments
    bgm_idx = n + length(voice_segments)

    vol_str = :erlang.float_to_binary(bgm_volume, decimals: 2)
    fade_in_str = :erlang.float_to_binary(fade_in, decimals: 1)
    fade_out_start_str = :erlang.float_to_binary(fade_out_start, decimals: 3)
    fade_out_str = :erlang.float_to_binary(fade_out, decimals: 1)

    bgm_filter =
      "[#{bgm_idx}:a]volume=#{vol_str}," <>
        "afade=t=in:d=#{fade_in_str}," <>
        "afade=t=out:st=#{fade_out_start_str}:d=#{fade_out_str}[bgm_audio]"

    {
      filters ++ [bgm_filter],
      mix_inputs ++ ["[bgm_audio]"],
      mix_weights ++ ["1.0"]
    }
  end

  # ── FFmpeg Args Builder ──

  defp build_ffmpeg_args(
         local_videos,
         voice_segments,
         bgm_path,
         filters,
         video_out,
         audio_out,
         output_path
       ) do
    # Input args: -i for each video, voice, and BGM
    video_inputs = Enum.flat_map(local_videos, &["-i", &1])
    voice_inputs = Enum.flat_map(voice_segments, &["-i", &1.audio_path])
    bgm_inputs = if bgm_path, do: ["-i", bgm_path], else: []

    filter_str = Enum.join(filters, ";")

    ["-y"] ++
      video_inputs ++
      voice_inputs ++
      bgm_inputs ++
      ["-filter_complex", filter_str] ++
      ["-map", video_out, "-map", audio_out] ++
      [
        "-c:v",
        "libx264",
        "-preset",
        "medium",
        "-crf",
        "23",
        "-c:a",
        "aac",
        "-b:a",
        "192k",
        "-movflags",
        "+faststart",
        output_path
      ]
  end

  # ── Legacy Public Functions (kept for backward compatibility) ──

  @doc "Adjust video speed. Factor range clamped to [0.85, 1.2]."
  @spec adjust_speed(String.t(), String.t(), float()) :: {:ok, :done} | {:error, String.t()}
  def adjust_speed(input_path, output_path, speed_factor) do
    speed = max(0.85, min(1.2, speed_factor))
    pts_factor = 1.0 / speed

    args = [
      "-y",
      "-i",
      input_path,
      "-filter:v",
      "setpts=#{pts_factor}*PTS",
      "-filter:a",
      "atempo=#{speed}",
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

  @doc "Simple concatenation using concat demuxer (no transitions)."
  @spec concat([String.t()], String.t(), Keyword.t()) :: {:ok, String.t()} | {:error, String.t()}
  def concat(video_paths, output_path, opts \\ []) do
    list_path = output_path <> ".list.txt"
    list_content = Enum.map_join(video_paths, "\n", &"file '#{&1}'")
    File.write!(list_path, list_content)

    args = ["-y", "-f", "concat", "-safe", "0", "-i", list_path, "-c", "copy"]

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

  @doc "Add subtitles to video with ASS styling."
  @spec add_subtitles(String.t(), String.t(), String.t()) :: {:ok, :done} | {:error, String.t()}
  def add_subtitles(video_path, srt_path, output_path) do
    escaped =
      srt_path
      |> String.replace("\\", "/")
      |> String.replace(":", "\\:")

    args = [
      "-y",
      "-i",
      video_path,
      "-vf",
      "subtitles=#{escaped}:force_style='#{@ass_style}'",
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

  @doc "Mix BGM audio into video."
  @spec mix_bgm(String.t(), String.t(), String.t(), Keyword.t()) ::
          {:ok, :done} | {:error, String.t()}
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

  @doc "Merge voice audio track into video (replace or mix mode)."
  @spec merge_voice_audio(String.t(), String.t(), String.t(), Keyword.t()) ::
          {:ok, :done} | {:error, String.t()}
  def merge_voice_audio(video_path, audio_path, output_path, opts \\ []) do
    case Keyword.get(opts, :mode, :replace) do
      :replace ->
        run_ffmpeg([
          "-y",
          "-i",
          video_path,
          "-i",
          audio_path,
          "-map",
          "0:v",
          "-map",
          "1:a",
          "-c:v",
          "copy",
          "-c:a",
          "aac",
          "-shortest",
          output_path
        ])

      :mix ->
        voice_vol = Keyword.get(opts, :voice_volume, 1.0)
        video_vol = Keyword.get(opts, :video_volume, 0.3)

        run_ffmpeg([
          "-y",
          "-i",
          video_path,
          "-i",
          audio_path,
          "-filter_complex",
          "[0:a]volume=#{video_vol}[va];[1:a]volume=#{voice_vol}[voice];[va][voice]amix=inputs=2:duration=first[out]",
          "-map",
          "0:v",
          "-map",
          "[out]",
          "-c:v",
          "copy",
          "-c:a",
          "aac",
          output_path
        ])
    end
  end

  @doc "Merge voice audio segments at specific timestamps into a single track."
  @spec merge_voice_segments([voice_segment()], String.t()) ::
          {:ok, :done} | {:error, String.t()}
  def merge_voice_segments(segments, output_path) do
    if Enum.empty?(segments) do
      {:error, "No audio segments"}
    else
      input_args = Enum.flat_map(segments, &["-i", &1.audio_path])

      delays =
        segments
        |> Enum.with_index()
        |> Enum.map_join(";", fn {s, i} ->
          delay_ms = trunc((s.start_time || 0.0) * 1000)
          "[#{i}:a]adelay=#{delay_ms}|#{delay_ms}[a#{i}]"
        end)

      mix_inputs = Enum.map_join(0..(length(segments) - 1), "", &"[a#{&1}]")
      filter = "#{delays};#{mix_inputs}amix=inputs=#{length(segments)}:normalize=0[out]"

      args =
        ["-y"] ++
          input_args ++ ["-filter_complex", filter, "-map", "[out]", "-c:a", "aac", output_path]

      run_ffmpeg(args)
    end
  end

  # ── Private Helpers ──

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
