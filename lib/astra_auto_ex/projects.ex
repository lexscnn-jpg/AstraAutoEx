defmodule AstraAutoEx.Projects do
  @moduledoc """
  The Projects context.
  """

  import Ecto.Query, warn: false
  alias AstraAutoEx.Repo
  alias AstraAutoEx.Projects.Project

  def list_projects(user_id) do
    Project
    |> where(user_id: ^user_id)
    |> where([p], p.status != "archived")
    |> order_by([p], desc: p.updated_at)
    |> Repo.all()
  end

  def get_project!(id, user_id) do
    Project
    |> where(id: ^id, user_id: ^user_id)
    |> Repo.one!()
  end

  def create_project(user_id, attrs) do
    %Project{user_id: user_id}
    |> Project.changeset(attrs)
    |> Repo.insert()
  end

  def update_project(%Project{} = project, attrs) do
    project
    |> Project.changeset(attrs)
    |> Repo.update()
  end

  def delete_project(%Project{} = project) do
    Repo.delete(project)
  end

  def archive_project(%Project{} = project) do
    project
    |> Project.changeset(%{status: "archived"})
    |> Repo.update()
  end

  def change_project(%Project{} = project, attrs \\ %{}) do
    Project.changeset(project, attrs)
  end
end
