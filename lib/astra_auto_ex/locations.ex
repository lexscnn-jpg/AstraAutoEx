defmodule AstraAutoEx.Locations do
  @moduledoc "Context for location and location image management."
  import Ecto.Query
  alias AstraAutoEx.Repo
  alias AstraAutoEx.Locations.{Location, LocationImage}

  def list_locations(project_id) do
    from(l in Location,
      where: l.project_id == ^project_id,
      order_by: [asc: l.inserted_at],
      preload: [:images]
    )
    |> Repo.all()
  end

  def get_location!(id), do: Repo.get!(Location, id) |> Repo.preload(:images)

  def create_location(attrs) do
    %Location{} |> Location.changeset(attrs) |> Repo.insert()
  end

  def update_location(location, attrs) do
    location |> Location.changeset(attrs) |> Repo.update()
  end

  def delete_location(location), do: Repo.delete(location)

  def add_image(location_id, attrs) do
    attrs = Map.put(attrs, :location_id, location_id)
    %LocationImage{} |> LocationImage.changeset(attrs) |> Repo.insert()
  end

  def update_image(image, attrs) do
    image |> LocationImage.changeset(attrs) |> Repo.update()
  end

  def select_image(location_id, image_id) do
    Repo.transaction(fn ->
      from(li in LocationImage, where: li.location_id == ^location_id)
      |> Repo.update_all(set: [is_selected: false])

      from(li in LocationImage, where: li.id == ^image_id)
      |> Repo.update_all(set: [is_selected: true])
    end)
  end

  def delete_image(image), do: Repo.delete(image)
end
