defmodule AstraAutoEx.AssetHub do
  @moduledoc "Context for global reusable assets: characters, locations, voices, folders."
  import Ecto.Query
  alias AstraAutoEx.Repo
  alias AstraAutoEx.AssetHub.{GlobalAssetFolder, GlobalCharacter, GlobalLocation, GlobalVoice}

  # ── Folders ──
  def list_folders(user_id),
    do: from(f in GlobalAssetFolder, where: f.user_id == ^user_id) |> Repo.all()

  def create_folder(attrs),
    do: %GlobalAssetFolder{} |> GlobalAssetFolder.changeset(attrs) |> Repo.insert()

  def delete_folder(folder), do: Repo.delete(folder)

  # ── Global Characters ──
  def list_global_characters(user_id) do
    from(gc in GlobalCharacter, where: gc.user_id == ^user_id, preload: [:appearances])
    |> Repo.all()
  end

  def create_global_character(attrs),
    do: %GlobalCharacter{} |> GlobalCharacter.changeset(attrs) |> Repo.insert()

  def update_global_character(gc, attrs),
    do: gc |> GlobalCharacter.changeset(attrs) |> Repo.update()

  def delete_global_character(gc), do: Repo.delete(gc)

  # ── Global Locations ──
  def list_global_locations(user_id) do
    from(gl in GlobalLocation, where: gl.user_id == ^user_id, preload: [:images]) |> Repo.all()
  end

  def create_global_location(attrs),
    do: %GlobalLocation{} |> GlobalLocation.changeset(attrs) |> Repo.insert()

  def delete_global_location(gl), do: Repo.delete(gl)

  # ── Global Voices ──
  def list_global_voices(user_id),
    do: from(gv in GlobalVoice, where: gv.user_id == ^user_id) |> Repo.all()

  def create_global_voice(attrs),
    do: %GlobalVoice{} |> GlobalVoice.changeset(attrs) |> Repo.insert()

  def delete_global_voice(gv), do: Repo.delete(gv)
end
