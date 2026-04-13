defmodule AstraAutoEx.Characters do
  @moduledoc "Context for character and appearance management."
  import Ecto.Query
  alias AstraAutoEx.Repo
  alias AstraAutoEx.Characters.{Character, CharacterAppearance}

  def list_characters(project_id) do
    from(c in Character,
      where: c.project_id == ^project_id,
      order_by: [asc: c.inserted_at],
      preload: [:appearances]
    )
    |> Repo.all()
  end

  def get_character!(id), do: Repo.get!(Character, id) |> Repo.preload(:appearances)

  def create_character(attrs) do
    %Character{} |> Character.changeset(attrs) |> Repo.insert()
  end

  def update_character(character, attrs) do
    character |> Character.changeset(attrs) |> Repo.update()
  end

  def delete_character(character), do: Repo.delete(character)

  def list_appearances(character_id) do
    from(a in CharacterAppearance,
      where: a.character_id == ^character_id,
      order_by: [asc: a.inserted_at]
    )
    |> Repo.all()
  end

  def get_appearance!(id), do: Repo.get!(CharacterAppearance, id)

  def create_appearance(attrs) do
    %CharacterAppearance{} |> CharacterAppearance.changeset(attrs) |> Repo.insert()
  end

  def add_appearance(character_id, attrs) do
    attrs = Map.put(attrs, :character_id, character_id)
    %CharacterAppearance{} |> CharacterAppearance.changeset(attrs) |> Repo.insert()
  end

  def update_appearance(appearance, attrs) do
    appearance |> CharacterAppearance.changeset(attrs) |> Repo.update()
  end

  def delete_appearance(appearance), do: Repo.delete(appearance)
end
