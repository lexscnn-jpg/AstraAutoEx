defmodule AstraAutoEx.Storage.Provider do
  @moduledoc """
  Behaviour for storage providers (local filesystem, S3/MinIO).
  """

  @type key :: String.t()
  @type opts :: keyword()

  @callback upload(key, body :: binary(), opts) :: {:ok, key} | {:error, term()}
  @callback delete(key) :: :ok | {:error, term()}
  @callback delete_many([key]) :: {:ok, non_neg_integer()} | {:error, term()}
  @callback get(key) :: {:ok, binary()} | {:error, term()}
  @callback get_signed_url(key, expires_in :: pos_integer()) ::
              {:ok, String.t()} | {:error, term()}
  @callback exists?(key) :: boolean()

  @doc "Generate a unique storage key."
  def generate_key(prefix, ext, opts \\ []) do
    project_id = Keyword.get(opts, :project_id)
    media_type = Keyword.get(opts, :media_type)
    ts = System.system_time(:millisecond)
    rand = :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
    filename = "#{prefix}-#{ts}-#{rand}.#{ext}"

    if project_id && media_type do
      "projects/#{project_id}/#{media_type}/#{filename}"
    else
      filename
    end
  end

  @doc "Detect MIME type from file extension."
  def mime_from_ext(ext) do
    case String.downcase(ext) do
      "png" -> "image/png"
      "jpg" -> "image/jpeg"
      "jpeg" -> "image/jpeg"
      "webp" -> "image/webp"
      "gif" -> "image/gif"
      "mp4" -> "video/mp4"
      "webm" -> "video/webm"
      "mov" -> "video/quicktime"
      "mp3" -> "audio/mpeg"
      "wav" -> "audio/wav"
      "ogg" -> "audio/ogg"
      "m4a" -> "audio/mp4"
      _ -> "application/octet-stream"
    end
  end
end
