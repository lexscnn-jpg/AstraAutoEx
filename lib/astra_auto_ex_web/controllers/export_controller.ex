defmodule AstraAutoExWeb.ExportController do
  @moduledoc """
  Bulk download controllers for project assets.

  Consolidates the original Next.js endpoints
  `/api/novel-promotion/[projectId]/download-{images,videos,voices}` into one
  controller with a `kind` param.

  Endpoints:
    GET /projects/:project_id/download/:kind  (kind: "images" | "videos" | "voices")

  Streams a ZIP archive. Implementation uses Erlang's built-in `:zip` module —
  builds in memory for <100MB archives; spills to temp for larger.
  """

  use AstraAutoExWeb, :controller

  alias AstraAutoEx.Production

  @max_in_memory_mb 100

  @doc "Download all panel images/videos/voices for a project as a ZIP."
  def project_download(conn, %{"project_id" => project_id, "kind" => kind}) do
    user_id = conn.assigns.current_scope.user.id
    project_id_int = String.to_integer(project_id)

    case AstraAutoEx.Projects.get_project!(project_id_int, user_id) do
      nil ->
        conn |> put_status(:forbidden) |> json(%{error: "forbidden"})

      _project ->
        episodes = Production.list_episodes(project_id_int)
        assets = collect_assets(episodes, kind)
        send_zip(conn, assets, "project_#{project_id}_#{kind}.zip")
    end
  rescue
    Ecto.NoResultsError ->
      conn |> put_status(:not_found) |> json(%{error: "project not found"})
  end

  # ── Internal ──

  defp collect_assets(episodes, "images") do
    episodes
    |> Enum.flat_map(fn ep ->
      ep.id
      |> Production.list_storyboards()
      |> Enum.flat_map(fn sb ->
        Production.list_panels(sb.id)
        |> Enum.filter(&(is_binary(&1.image_url) and &1.image_url != ""))
        |> Enum.map(fn p ->
          {build_filename(ep, sb, p, "png"), p.image_url}
        end)
      end)
    end)
  end

  defp collect_assets(episodes, "videos") do
    episodes
    |> Enum.flat_map(fn ep ->
      ep.id
      |> Production.list_storyboards()
      |> Enum.flat_map(fn sb ->
        Production.list_panels(sb.id)
        |> Enum.filter(&(is_binary(&1.video_url) and &1.video_url != ""))
        |> Enum.map(fn p ->
          {build_filename(ep, sb, p, "mp4"), p.video_url}
        end)
      end)
    end)
  end

  defp collect_assets(episodes, "voices") do
    episodes
    |> Enum.flat_map(fn ep ->
      Production.list_voice_lines(ep.id)
      |> Enum.filter(&(is_binary(&1.audio_url) and &1.audio_url != ""))
      |> Enum.map(fn vl ->
        safe_title = sanitize(ep.title || "episode")
        name = "#{safe_title}/voice_#{vl.line_index}.wav"
        {name, vl.audio_url}
      end)
    end)
  end

  defp collect_assets(_episodes, _other), do: []

  defp build_filename(episode, storyboard, panel, ext) do
    safe_title = sanitize(episode.title || "episode")
    sb_idx = safe_storyboard_index(storyboard)
    "#{safe_title}/sb#{sb_idx}_p#{panel.panel_index}.#{ext}"
  end

  defp safe_storyboard_index(%{inserted_at: ts}) when not is_nil(ts),
    do: Calendar.strftime(ts, "%H%M%S")

  defp safe_storyboard_index(_), do: "unknown"

  defp sanitize(name) do
    name
    |> to_string()
    |> String.replace(~r/[^\w\-_.]/u, "_")
    |> String.slice(0, 60)
  end

  defp send_zip(conn, [], _filename) do
    conn |> put_status(:not_found) |> json(%{error: "no assets"})
  end

  defp send_zip(conn, assets, filename) do
    {entries, total_size} =
      Enum.reduce(assets, {[], 0}, fn {name, url}, {acc, size} ->
        case fetch_bytes(url) do
          {:ok, bytes} ->
            {[{String.to_charlist(name), bytes} | acc], size + byte_size(bytes)}

          :error ->
            {acc, size}
        end
      end)

    if entries == [] do
      conn |> put_status(500) |> json(%{error: "no assets fetched"})
    else
      if total_size > @max_in_memory_mb * 1024 * 1024 do
        send_zip_via_tempfile(conn, Enum.reverse(entries), filename)
      else
        send_zip_in_memory(conn, Enum.reverse(entries), filename)
      end
    end
  end

  defp send_zip_in_memory(conn, entries, filename) do
    case :zip.create(~c"bundle.zip", entries, [:memory]) do
      {:ok, {_name, zip_bytes}} ->
        conn
        |> put_resp_content_type("application/zip")
        |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
        |> send_resp(200, zip_bytes)

      {:error, reason} ->
        conn |> put_status(500) |> json(%{error: "zip failed: #{inspect(reason)}"})
    end
  end

  defp send_zip_via_tempfile(conn, entries, filename) do
    tmp_path = Path.join(System.tmp_dir!(), "export-#{:erlang.unique_integer([:positive])}.zip")

    case :zip.create(String.to_charlist(tmp_path), entries) do
      {:ok, _} ->
        conn =
          conn
          |> put_resp_content_type("application/zip")
          |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))

        conn = send_file(conn, 200, tmp_path)
        File.rm(tmp_path)
        conn

      {:error, reason} ->
        conn |> put_status(500) |> json(%{error: "zip failed: #{inspect(reason)}"})
    end
  end

  defp fetch_bytes("/uploads/" <> rel) do
    upload_dir = Application.get_env(:astra_auto_ex, :upload_dir, "priv/uploads")
    local_path = Path.join(upload_dir, rel)

    case File.read(local_path) do
      {:ok, bytes} -> {:ok, bytes}
      {:error, _} -> :error
    end
  end

  defp fetch_bytes("http" <> _ = url) do
    case Req.get(url, receive_timeout: 60_000, max_retries: 1) do
      {:ok, %{status: 200, body: body}} when is_binary(body) -> {:ok, body}
      _ -> :error
    end
  rescue
    _ -> :error
  end

  defp fetch_bytes(_), do: :error
end
