defmodule AstraAutoEx.ShortDrama do
  @moduledoc "Context for short drama series planning and episode scripts."
  import Ecto.Query
  alias AstraAutoEx.Repo
  alias AstraAutoEx.ShortDrama.{SeriesPlan, EpisodeScript}

  def get_series_plan(project_id), do: Repo.get_by(SeriesPlan, project_id: project_id)
  def create_series_plan(attrs), do: %SeriesPlan{} |> SeriesPlan.changeset(attrs) |> Repo.insert()
  def update_series_plan(sp, attrs), do: sp |> SeriesPlan.changeset(attrs) |> Repo.update()

  def list_episode_scripts(series_plan_id) do
    from(es in EpisodeScript,
      where: es.series_plan_id == ^series_plan_id,
      order_by: [asc: es.episode_number]
    )
    |> Repo.all()
  end

  def create_episode_script(attrs),
    do: %EpisodeScript{} |> EpisodeScript.changeset(attrs) |> Repo.insert()

  def update_episode_script(es, attrs), do: es |> EpisodeScript.changeset(attrs) |> Repo.update()
end
