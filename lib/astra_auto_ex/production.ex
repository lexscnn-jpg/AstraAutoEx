defmodule AstraAutoEx.Production do
  @moduledoc "Context for production pipeline: episodes, clips, storyboards, panels, shots, voice lines."
  import Ecto.Query
  alias AstraAutoEx.Repo
  alias AstraAutoEx.Production.{NovelProject, Episode, Clip, Storyboard, Panel, Shot, VoiceLine}

  # ── NovelProject ──
  def get_novel_project(project_id), do: Repo.get_by(NovelProject, project_id: project_id)

  def upsert_novel_project(attrs) do
    case get_novel_project(attrs[:project_id] || attrs["project_id"]) do
      nil -> %NovelProject{} |> NovelProject.changeset(attrs) |> Repo.insert()
      np -> np |> NovelProject.changeset(attrs) |> Repo.update()
    end
  end

  # ── Episodes ──
  def list_episodes(project_id) do
    from(e in Episode, where: e.project_id == ^project_id, order_by: [asc: e.episode_number])
    |> Repo.all()
  end

  def get_episode!(id), do: Repo.get!(Episode, id)
  def create_episode(attrs), do: %Episode{} |> Episode.changeset(attrs) |> Repo.insert()
  def update_episode(episode, attrs), do: episode |> Episode.changeset(attrs) |> Repo.update()
  def delete_episode(episode), do: Repo.delete(episode)

  @doc "Find an episode by its public sharing ID."
  @spec get_episode_by_public_id(String.t()) :: Episode.t() | nil
  def get_episode_by_public_id(public_id) when is_binary(public_id) do
    Repo.get_by(Episode, public_id: public_id)
  end

  @doc "Generate a short Base62-encoded random ID for public sharing."
  @spec generate_public_id() :: String.t()
  def generate_public_id do
    alphabet = ~c"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

    1..8
    |> Enum.map(fn _ -> Enum.random(alphabet) end)
    |> List.to_string()
  end

  @doc "Ensure an episode has a public_id; generate one if missing."
  @spec ensure_public_id(Episode.t()) :: {:ok, Episode.t()} | {:error, Ecto.Changeset.t()}
  def ensure_public_id(%Episode{public_id: pid} = episode) when is_binary(pid) and pid != "" do
    {:ok, episode}
  end

  def ensure_public_id(%Episode{} = episode) do
    update_episode(episode, %{public_id: generate_public_id()})
  end

  # ── Clips ──
  def list_clips(episode_id) do
    from(c in Clip, where: c.episode_id == ^episode_id, order_by: [asc: c.clip_index])
    |> Repo.all()
  end

  def create_clip(attrs), do: %Clip{} |> Clip.changeset(attrs) |> Repo.insert()
  def update_clip(clip, attrs), do: clip |> Clip.changeset(attrs) |> Repo.update()

  # ── Storyboards ──
  def list_storyboards(episode_id) do
    from(s in Storyboard,
      where: s.episode_id == ^episode_id,
      preload: [panels: ^from(p in Panel, order_by: p.panel_index)]
    )
    |> Repo.all()
  end

  def get_storyboard!(id), do: Repo.get!(Storyboard, id)
  def create_storyboard(attrs), do: %Storyboard{} |> Storyboard.changeset(attrs) |> Repo.insert()

  def list_storyboards_by_clip(clip_id) do
    from(s in Storyboard, where: s.clip_id == ^clip_id, order_by: [asc: s.inserted_at])
    |> Repo.all()
  end

  # ── Panels ──
  def list_panels(storyboard_id) do
    from(p in Panel, where: p.storyboard_id == ^storyboard_id, order_by: [asc: p.panel_index])
    |> Repo.all()
  end

  def get_panel!(id), do: Repo.get!(Panel, id)
  def create_panel(attrs), do: %Panel{} |> Panel.changeset(attrs) |> Repo.insert()
  def update_panel(panel, attrs), do: panel |> Panel.changeset(attrs) |> Repo.update()

  @doc "Update a panel's index for drag-and-drop reordering."
  @spec update_panel_index(String.t(), integer()) ::
          {:ok, Panel.t()} | {:error, Ecto.Changeset.t()}
  def update_panel_index(panel_id, new_index) do
    panel_id |> get_panel!() |> update_panel(%{panel_index: new_index})
  end

  # ── Shots ──
  def list_shots(episode_id) do
    from(s in Shot, where: s.episode_id == ^episode_id, order_by: [asc: s.shot_index])
    |> Repo.all()
  end

  def create_shot(attrs), do: %Shot{} |> Shot.changeset(attrs) |> Repo.insert()

  # ── Voice Lines ──
  def list_voice_lines(episode_id) do
    from(v in VoiceLine, where: v.episode_id == ^episode_id, order_by: [asc: v.line_index])
    |> Repo.all()
  end

  def get_voice_line!(id), do: Repo.get!(VoiceLine, id)
  def create_voice_line(attrs), do: %VoiceLine{} |> VoiceLine.changeset(attrs) |> Repo.insert()
  def update_voice_line(vl, attrs), do: vl |> VoiceLine.changeset(attrs) |> Repo.update()
end
