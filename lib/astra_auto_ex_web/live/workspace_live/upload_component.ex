defmodule AstraAutoExWeb.WorkspaceLive.UploadComponent do
  @moduledoc "Drag-and-drop file upload component for workspace."
  use AstraAutoExWeb, :live_component

  alias AstraAutoEx.Storage.{Server, Provider}

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:uploaded_files, [])
     |> allow_upload(:media,
       accept: ~w(.png .jpg .jpeg .webp .mp4 .mp3 .wav .m4a),
       max_entries: 10,
       max_file_size: 100_000_000,
       auto_upload: true
     )}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-3">
      <form phx-change="validate_upload" phx-submit="save_upload" phx-target={@myself}>
        <div
          class="glass-surface rounded-lg p-8 text-center border-2 border-dashed border-[var(--glass-stroke-base)] hover:border-[var(--glass-stroke-strong)] transition-colors"
          phx-drop-target={@uploads.media.ref}
        >
          <.live_file_input upload={@uploads.media} class="hidden" />
          <p class="text-[var(--glass-text-tertiary)] text-sm mb-2">
            Drag & drop files here, or click to browse
          </p>
          <p class="text-[var(--glass-text-tertiary)] opacity-40 text-xs">
            Supports: PNG, JPG, WebP, MP4, MP3, WAV (max 100MB)
          </p>
        </div>

        <%!-- Upload previews --%>
        <div :if={length(@uploads.media.entries) > 0} class="space-y-2 mt-3">
          <%= for entry <- @uploads.media.entries do %>
            <div class="flex items-center gap-3 glass-surface p-2 rounded-lg">
              <div class="w-10 h-10 rounded bg-[var(--glass-bg-muted)] flex items-center justify-center text-xs text-[var(--glass-text-tertiary)]">
                {entry_icon(entry)}
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-sm text-[var(--glass-text-primary)] truncate">{entry.client_name}</p>
                <div class="h-1 bg-[var(--glass-bg-muted)] rounded-full mt-1">
                  <div
                    class="h-full bg-gradient-to-r from-blue-500 to-purple-500 rounded-full transition-all"
                    style={"width: #{entry.progress}%"}
                  />
                </div>
              </div>
              <button
                type="button"
                phx-click="cancel_upload"
                phx-value-ref={entry.ref}
                phx-target={@myself}
                class="text-[var(--glass-text-tertiary)] hover:text-[var(--glass-text-primary)] text-sm"
              >
                &times;
              </button>
            </div>
          <% end %>

          <button type="submit" class="glass-btn glass-btn-primary px-4 py-2 text-sm w-full mt-2">
            Upload {length(@uploads.media.entries)} file(s)
          </button>
        </div>

        <%!-- Uploaded files --%>
        <div :if={length(@uploaded_files) > 0} class="space-y-1 mt-3">
          <p class="text-xs text-[var(--glass-text-tertiary)]">Uploaded:</p>
          <%= for file <- @uploaded_files do %>
            <div class="flex items-center gap-2 text-xs text-[var(--glass-text-secondary)]">
              <span class="text-green-500">OK</span>
              <span class="truncate">{file.name}</span>
            </div>
          <% end %>
        </div>
      </form>
    </div>
    """
  end

  @impl true
  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :media, ref)}
  end

  def handle_event("save_upload", _params, socket) do
    project_id = socket.assigns[:project_id]
    media_type = socket.assigns[:media_type] || "image"

    uploaded_files =
      consume_uploaded_entries(socket, :media, fn %{path: path}, entry ->
        ext = Path.extname(entry.client_name) |> String.trim_leading(".")

        storage_key =
          Provider.generate_key("upload", ext, project_id: project_id, media_type: media_type)

        data = File.read!(path)
        {:ok, _} = Server.upload(storage_key, data)
        {:ok, url} = Server.get_signed_url(storage_key)

        {:ok, %{name: entry.client_name, url: url, storage_key: storage_key}}
      end)

    # Notify parent
    send(self(), {:files_uploaded, uploaded_files})

    {:noreply,
     socket
     |> update(:uploaded_files, &(&1 ++ uploaded_files))}
  end

  defp entry_icon(entry) do
    cond do
      String.starts_with?(entry.client_type, "image/") -> "IMG"
      String.starts_with?(entry.client_type, "video/") -> "VID"
      String.starts_with?(entry.client_type, "audio/") -> "AUD"
      true -> "FILE"
    end
  end
end
