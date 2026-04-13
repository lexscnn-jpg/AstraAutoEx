defmodule AstraAutoExWeb.FileController do
  @moduledoc "Serves and uploads locally stored files."
  use AstraAutoExWeb, :controller

  alias AstraAutoEx.Storage.{Provider, Server}
  alias AstraAutoEx.Media

  def serve(conn, %{"path" => path_parts}) do
    key = Enum.join(path_parts, "/")
    safe_key = key |> String.replace("..", "") |> String.trim_leading("/")
    upload_dir = Application.get_env(:astra_auto_ex, :upload_dir, "priv/uploads")
    full_path = Path.join(upload_dir, safe_key)

    if File.exists?(full_path) do
      ext = Path.extname(safe_key) |> String.trim_leading(".")
      content_type = Provider.mime_from_ext(ext)

      conn
      |> put_resp_header("content-type", content_type)
      |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
      |> send_file(200, full_path)
    else
      conn
      |> put_status(:not_found)
      |> text("File not found")
    end
  end

  @doc "Upload a file via multipart POST."
  def upload(conn, %{"file" => upload} = params) do
    project_id = params["project_id"]
    media_type = params["media_type"] || "image"
    ext = Path.extname(upload.filename) |> String.trim_leading(".")

    storage_key =
      Provider.generate_key("upload", ext, project_id: project_id, media_type: media_type)

    case File.read(upload.path) do
      {:ok, data} ->
        case Server.upload(storage_key, data) do
          {:ok, _} ->
            {:ok, url} = Server.get_signed_url(storage_key)

            # Track in media objects
            Media.ensure_media_object(storage_key, %{
              project_id: project_id,
              media_type: media_type,
              content_type: Provider.mime_from_ext(ext),
              original_filename: upload.filename,
              byte_size: byte_size(data)
            })

            conn
            |> put_status(:created)
            |> json(%{ok: true, storage_key: storage_key, url: url})

          {:error, reason} ->
            conn |> put_status(500) |> json(%{error: inspect(reason)})
        end

      {:error, reason} ->
        conn |> put_status(400) |> json(%{error: inspect(reason)})
    end
  end

  def upload(conn, _params) do
    conn |> put_status(400) |> json(%{error: "Missing file parameter"})
  end
end
