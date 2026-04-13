defmodule AstraAutoExWeb.WorkspaceLive.PanelEditor do
  @moduledoc """
  Panel editing modal — edit description, shot type, camera, dialogue.
  Inline image/video preview. Generate/regenerate buttons.
  """
  use AstraAutoExWeb, :live_component

  alias AstraAutoEx.Production
  alias AstraAutoEx.Storage.{Server, Provider}

  @shot_types ~w(extreme_wide wide full medium medium_close_up close_up extreme_close_up over_shoulder pov)
  @camera_moves ~w(static pan_left pan_right tilt_up tilt_down dolly_in dolly_out track_left track_right crane_up crane_down)

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:editing_field, nil)
     |> allow_upload(:panel_image,
       accept: ~w(.png .jpg .jpeg .webp),
       max_entries: 1,
       max_file_size: 20_000_000,
       auto_upload: true
     )}
  end

  @impl true
  def update(assigns, socket) do
    panel = assigns.panel

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:form, panel_to_form(panel))
     |> assign(:shot_types, @shot_types)
     |> assign(:camera_moves, @camera_moves)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center">
      <div class="absolute inset-0 bg-black/70" phx-click="close_panel_editor" />
      <div class="glass-card p-0 w-full max-w-4xl relative z-10 max-h-[90vh] overflow-hidden flex flex-col">
        <%!-- Header --%>
        <div class="flex items-center justify-between px-6 py-4 border-b border-[var(--glass-stroke-base)]">
          <h2 class="text-lg font-bold text-[var(--glass-text-primary)]">
            Panel #{@panel.panel_index + 1}
          </h2>
          <button
            phx-click="close_panel_editor"
            class="text-[var(--glass-text-tertiary)] hover:text-[var(--glass-text-primary)] text-xl"
          >
            &times;
          </button>
        </div>

        <div class="flex flex-1 overflow-hidden">
          <%!-- Left: Preview --%>
          <div class="w-1/2 p-4 border-r border-[var(--glass-stroke-base)] flex flex-col">
            <div
              class="aspect-video bg-[var(--glass-bg-muted)] rounded-lg overflow-hidden mb-3 flex items-center justify-center relative"
              id="panel-preview"
              phx-hook="ImageCrop"
              phx-target={@myself}
            >
              <%= cond do %>
                <% @panel.video_url && @panel.video_url != "" -> %>
                  <video src={@panel.video_url} class="w-full h-full object-cover" controls />
                <% @panel.image_url && @panel.image_url != "" -> %>
                  <img src={@panel.image_url} class="w-full h-full object-cover" />
                  <canvas
                    class="absolute inset-0 w-full h-full cursor-crosshair"
                    style="display:none"
                  />
                <% true -> %>
                  <span class="text-[var(--glass-text-tertiary)] opacity-40 text-sm">
                    No image generated
                  </span>
              <% end %>
            </div>

            <div class="flex gap-2">
              <button
                phx-click="generate_panel_image"
                phx-value-panel-id={@panel.id}
                class="glass-btn glass-btn-primary px-3 py-1.5 text-xs flex-1"
              >
                {if @panel.image_url, do: "Regenerate Image", else: "Generate Image"}
              </button>
              <button
                :if={@panel.image_url && @panel.image_url != ""}
                phx-click="generate_panel_video"
                phx-value-panel-id={@panel.id}
                class="glass-btn glass-btn-primary px-3 py-1.5 text-xs flex-1"
              >
                {if @panel.video_url, do: "Regenerate Video", else: "Generate Video"}
              </button>
            </div>

            <%!-- Upload custom image --%>
            <div class="mt-3">
              <form phx-change="validate_image" phx-submit="upload_image" phx-target={@myself}>
                <div
                  class="glass-surface rounded-lg p-3 text-center border border-dashed border-[var(--glass-stroke-base)] hover:border-[var(--glass-stroke-strong)] transition-colors cursor-pointer"
                  phx-drop-target={@uploads.panel_image.ref}
                >
                  <.live_file_input upload={@uploads.panel_image} class="hidden" />
                  <p class="text-[var(--glass-text-tertiary)] text-xs">
                    Drop image to replace, or click to browse
                  </p>
                </div>
                <%= for entry <- @uploads.panel_image.entries do %>
                  <div class="flex items-center gap-2 mt-2 text-xs">
                    <div class="flex-1">
                      <span class="text-[var(--glass-text-secondary)]">{entry.client_name}</span>
                      <div class="h-1 bg-[var(--glass-bg-muted)] rounded-full mt-1">
                        <div
                          class="h-full bg-blue-500 rounded-full"
                          style={"width: #{entry.progress}%"}
                        />
                      </div>
                    </div>
                    <button type="submit" class="glass-btn glass-btn-primary px-2 py-1 text-[10px]">
                      Upload
                    </button>
                  </div>
                <% end %>
              </form>
            </div>

            <%!-- Metadata --%>
            <div class="mt-3 space-y-1 text-xs text-[var(--glass-text-tertiary)] opacity-60">
              <div :if={@panel.image_url}>
                Image: {String.slice(@panel.image_url || "", -30..-1//1)}
              </div>
              <div :if={@panel.video_url}>
                Video: {String.slice(@panel.video_url || "", -30..-1//1)}
              </div>
            </div>
          </div>

          <%!-- Right: Edit fields --%>
          <div class="w-1/2 p-4 overflow-y-auto">
            <.form for={@form} phx-submit="save_panel" phx-target={@myself} class="space-y-4">
              <input type="hidden" name="panel_id" value={@panel.id} />

              <div>
                <label class="text-xs text-[var(--glass-text-tertiary)] mb-1 block">
                  Description
                </label>
                <textarea
                  name="panel[description]"
                  class="glass-input w-full h-24 resize-none text-sm"
                  phx-debounce="500"
                ><%= @form[:description].value %></textarea>
              </div>

              <div class="grid grid-cols-2 gap-3">
                <div>
                  <label class="text-xs text-[var(--glass-text-tertiary)] mb-1 block">
                    Shot Type
                  </label>
                  <select name="panel[shot_type]" class="glass-input w-full text-sm">
                    <%= for st <- @shot_types do %>
                      <option value={st} selected={@form[:shot_type].value == st}>
                        {format_shot_type(st)}
                      </option>
                    <% end %>
                  </select>
                </div>
                <div>
                  <label class="text-xs text-[var(--glass-text-tertiary)] mb-1 block">Camera</label>
                  <select name="panel[camera_move]" class="glass-input w-full text-sm">
                    <option value="">None</option>
                    <%= for cm <- @camera_moves do %>
                      <option value={cm} selected={@form[:camera_move].value == cm}>
                        {format_camera(cm)}
                      </option>
                    <% end %>
                  </select>
                </div>
              </div>

              <div>
                <label class="text-xs text-[var(--glass-text-tertiary)] mb-1 block">Dialogue</label>
                <textarea
                  name="panel[dialogue]"
                  class="glass-input w-full h-16 resize-none text-sm"
                  placeholder="Character dialogue in this panel..."
                ><%= @form[:dialogue].value || Map.get(@panel, :dialogue, "") %></textarea>
              </div>

              <div>
                <label class="text-xs text-[var(--glass-text-tertiary)] mb-1 block">Location</label>
                <input
                  type="text"
                  name="panel[location]"
                  value={@form[:location].value}
                  class="glass-input w-full text-sm"
                  placeholder="Scene location..."
                />
              </div>

              <div>
                <label class="text-xs text-[var(--glass-text-tertiary)] mb-1 block">
                  Characters
                </label>
                <input
                  type="text"
                  name="panel[characters]"
                  value={@form[:characters].value}
                  class="glass-input w-full text-sm"
                  placeholder="Characters in this panel..."
                />
              </div>

              <div>
                <label class="text-xs text-[var(--glass-text-tertiary)] mb-1 block">
                  Photography Rules
                </label>
                <textarea
                  name="panel[photography_rules]"
                  class="glass-input w-full h-16 resize-none text-sm"
                  placeholder="Lighting, color palette, depth of field..."
                ><%= @form[:photography_rules].value %></textarea>
              </div>

              <div>
                <label class="text-xs text-[var(--glass-text-tertiary)] mb-1 block">
                  Acting Notes
                </label>
                <textarea
                  name="panel[acting_notes]"
                  class="glass-input w-full h-12 resize-none text-sm"
                  placeholder="Character expressions, movements..."
                ><%= @form[:acting_notes].value %></textarea>
              </div>

              <div class="flex justify-end pt-2">
                <button type="submit" class="glass-btn glass-btn-primary px-6 py-2 text-sm">
                  Save Panel
                </button>
              </div>
            </.form>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("image_cropped", %{"data_url" => data_url}, socket) do
    panel = socket.assigns.panel
    project_id = socket.assigns.project.id

    # Extract base64 from data URL
    case String.split(data_url, ";base64,", parts: 2) do
      [_header, base64] ->
        data = Base.decode64!(base64)
        key = Provider.generate_key("crop", "png", project_id: project_id, media_type: "image")
        {:ok, _} = Server.upload(key, data)
        {:ok, url} = Server.get_signed_url(key)

        {:ok, updated} = Production.update_panel(panel, %{image_url: url})
        send(self(), {:panel_updated, updated})
        {:noreply, socket |> assign(:panel, updated) |> assign(:form, panel_to_form(updated))}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("validate_image", _params, socket), do: {:noreply, socket}

  def handle_event("upload_image", _params, socket) do
    panel = socket.assigns.panel
    project_id = socket.assigns.project.id

    uploaded =
      consume_uploaded_entries(socket, :panel_image, fn %{path: path}, entry ->
        ext = Path.extname(entry.client_name) |> String.trim_leading(".")
        key = Provider.generate_key("panel", ext, project_id: project_id, media_type: "image")
        data = File.read!(path)
        {:ok, _} = Server.upload(key, data)
        {:ok, url} = Server.get_signed_url(key)
        {:ok, url}
      end)

    case uploaded do
      [url | _] ->
        {:ok, updated} = Production.update_panel(panel, %{image_url: url})
        send(self(), {:panel_updated, updated})
        {:noreply, socket |> assign(:panel, updated) |> assign(:form, panel_to_form(updated))}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("save_panel", %{"panel" => params, "panel_id" => panel_id}, socket) do
    panel = Production.get_panel!(panel_id)

    case Production.update_panel(panel, params) do
      {:ok, updated} ->
        send(self(), {:panel_updated, updated})
        {:noreply, socket |> assign(:panel, updated) |> assign(:form, panel_to_form(updated))}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  defp panel_to_form(panel) do
    data = %{
      description: panel.description || "",
      shot_type: panel.shot_type || "medium",
      camera_move: panel.camera_move || "",
      location: panel.location || "",
      characters: panel.characters || "",
      photography_rules: panel.photography_rules || "",
      acting_notes: panel.acting_notes || "",
      dialogue: Map.get(panel, :dialogue, "")
    }

    to_form(data, as: "panel")
  end

  defp format_shot_type(st) do
    st
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp format_camera(cm) do
    cm
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end
