defmodule AstraAutoEx.Media.LipSyncPreprocessor do
  @moduledoc """
  Audio preprocessing for lip sync providers.

  Ensures audio meets provider requirements before submission:
  - Minimum duration: pad short audio (<2s) with silence to reach 2 seconds
  - Maximum duration: trim audio exceeding video duration
  - WAV alignment: ensure byte count is a multiple of block size for WAV format

  Uses ffprobe for duration detection and ffmpeg for audio manipulation.
  """
  require Logger

  alias AstraAutoEx.Media.FFmpeg

  @min_duration_seconds 2.0

  # WAV block size (16-bit stereo = 4 bytes per sample)
  @wav_block_size 4

  @doc """
  Preprocess audio file for lip sync.

  Steps:
  1. Detect audio duration via ffprobe
  2. If < 2 seconds, pad with silence to reach 2s minimum
  3. If > video_duration, trim to video_duration
  4. Ensure WAV block alignment if output is WAV format

  Returns the path to the processed file (may be the original if no processing needed).
  """
  @spec preprocess(String.t(), float()) :: {:ok, String.t()} | {:error, String.t()}
  def preprocess(audio_path, video_duration)
      when is_binary(audio_path) and is_float(video_duration) do
    Logger.info("[LipSyncPreprocess] Processing: #{audio_path}, video_dur=#{video_duration}s")

    with {:ok, audio_duration} <- detect_duration(audio_path),
         {:ok, path_after_pad} <- maybe_pad_silence(audio_path, audio_duration),
         {:ok, path_after_trim} <- maybe_trim(path_after_pad, video_duration),
         {:ok, final_path} <- maybe_align_wav(path_after_trim) do
      Logger.info("[LipSyncPreprocess] Done: #{final_path}")
      {:ok, final_path}
    end
  end

  def preprocess(audio_path, video_duration)
      when is_binary(audio_path) and is_integer(video_duration) do
    preprocess(audio_path, video_duration / 1.0)
  end

  def preprocess(_, _),
    do: {:error, "Invalid arguments: expected audio_path (string) and video_duration (float)"}

  @doc """
  Detect audio duration in seconds using ffprobe.
  """
  @spec detect_duration(String.t()) :: {:ok, float()} | {:error, String.t()}
  def detect_duration(audio_path) do
    case FFmpeg.get_duration(audio_path) do
      {:ok, duration} when duration > 0 ->
        Logger.debug("[LipSyncPreprocess] Audio duration: #{Float.round(duration, 2)}s")
        {:ok, duration}

      {:ok, _} ->
        {:error, "Audio file has zero or negative duration: #{audio_path}"}

      {:error, reason} ->
        {:error, "Failed to detect audio duration: #{reason}"}
    end
  end

  @doc """
  Pad audio with silence if shorter than minimum duration (2 seconds).

  Uses ffmpeg's apad filter to append silence, then trims to target.
  """
  @spec maybe_pad_silence(String.t(), float()) :: {:ok, String.t()} | {:error, String.t()}
  def maybe_pad_silence(audio_path, duration) when duration >= @min_duration_seconds do
    {:ok, audio_path}
  end

  def maybe_pad_silence(audio_path, duration) do
    Logger.info(
      "[LipSyncPreprocess] Padding: #{Float.round(duration, 2)}s -> #{@min_duration_seconds}s"
    )

    output_path = generate_temp_path(audio_path, "padded")

    # apad: append silence; atrim: trim to exact target duration
    # -af "apad=whole_dur=2" pads silence until total duration reaches 2s
    target_str = :erlang.float_to_binary(@min_duration_seconds, decimals: 3)

    args = [
      "-y",
      "-i",
      audio_path,
      "-af",
      "apad=whole_dur=#{target_str}",
      "-c:a",
      "pcm_s16le",
      "-ar",
      "16000",
      "-ac",
      "1",
      output_path
    ]

    case run_ffmpeg(args) do
      {:ok, _} -> {:ok, output_path}
      {:error, reason} -> {:error, "Failed to pad audio: #{reason}"}
    end
  end

  @doc """
  Trim audio to video duration if audio is longer.
  """
  @spec maybe_trim(String.t(), float()) :: {:ok, String.t()} | {:error, String.t()}
  def maybe_trim(audio_path, video_duration) do
    case detect_duration(audio_path) do
      {:ok, audio_dur} when audio_dur > video_duration ->
        Logger.info(
          "[LipSyncPreprocess] Trimming: #{Float.round(audio_dur, 2)}s -> #{Float.round(video_duration, 2)}s"
        )

        do_trim(audio_path, video_duration)

      {:ok, _} ->
        {:ok, audio_path}

      {:error, reason} ->
        {:error, "Duration check before trim failed: #{reason}"}
    end
  end

  defp do_trim(audio_path, target_duration) do
    output_path = generate_temp_path(audio_path, "trimmed")
    dur_str = :erlang.float_to_binary(target_duration, decimals: 3)

    # -t: output duration limit
    args = [
      "-y",
      "-i",
      audio_path,
      "-t",
      dur_str,
      "-c:a",
      "copy",
      output_path
    ]

    case run_ffmpeg(args) do
      {:ok, _} -> {:ok, output_path}
      {:error, reason} -> {:error, "Failed to trim audio: #{reason}"}
    end
  end

  @doc """
  Ensure WAV file has block-aligned byte count.

  WAV format requires data chunk size to be a multiple of the block alignment
  (bytes_per_sample * num_channels). Misaligned files can cause lip sync
  providers to reject or misprocess the audio.
  """
  @spec maybe_align_wav(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def maybe_align_wav(audio_path) do
    if String.ends_with?(audio_path, ".wav") do
      align_wav_blocks(audio_path)
    else
      {:ok, audio_path}
    end
  end

  defp align_wav_blocks(audio_path) do
    case File.stat(audio_path) do
      {:ok, %{size: size}} ->
        # WAV header is typically 44 bytes; data = size - 44
        data_size = size - 44
        remainder = rem(data_size, @wav_block_size)

        if remainder == 0 do
          {:ok, audio_path}
        else
          Logger.info(
            "[LipSyncPreprocess] WAV block alignment: trimming #{remainder} trailing bytes"
          )

          # Re-encode to ensure proper alignment
          output_path = generate_temp_path(audio_path, "aligned")

          args = [
            "-y",
            "-i",
            audio_path,
            "-c:a",
            "pcm_s16le",
            "-ar",
            "16000",
            "-ac",
            "1",
            output_path
          ]

          case run_ffmpeg(args) do
            {:ok, _} -> {:ok, output_path}
            {:error, reason} -> {:error, "WAV alignment failed: #{reason}"}
          end
        end

      {:error, reason} ->
        {:error, "Cannot stat WAV file: #{inspect(reason)}"}
    end
  end

  # ── Private Helpers ──

  defp generate_temp_path(original_path, suffix) do
    ext = Path.extname(original_path)
    base = Path.rootname(original_path)
    "#{base}_#{suffix}#{ext}"
  end

  defp run_ffmpeg(args) do
    case System.cmd("ffmpeg", args, stderr_to_stdout: true) do
      {_, 0} -> {:ok, :done}
      {output, code} -> {:error, "FFmpeg exited #{code}: #{String.slice(output, 0..300)}"}
    end
  end
end
