defmodule AstraAutoEx.AssetHub do
  @moduledoc "Context for global reusable assets: characters, locations, voices, folders."
  import Ecto.Query
  alias AstraAutoEx.Repo

  alias AstraAutoEx.AssetHub.{
    GlobalAssetFolder,
    GlobalCharacter,
    GlobalCharacterAppearance,
    GlobalLocation,
    GlobalLocationImage,
    GlobalVoice,
    GlobalProp,
    GlobalSfx,
    GlobalBgm
  }

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
  def update_global_voice(gv, attrs), do: gv |> GlobalVoice.changeset(attrs) |> Repo.update()

  # ── Global Props ──
  def list_global_props(user_id),
    do: from(gp in GlobalProp, where: gp.user_id == ^user_id) |> Repo.all()

  def create_global_prop(attrs),
    do: %GlobalProp{} |> GlobalProp.changeset(attrs) |> Repo.insert()

  def update_global_prop(gp, attrs), do: gp |> GlobalProp.changeset(attrs) |> Repo.update()
  def delete_global_prop(gp), do: Repo.delete(gp)

  def get_global_prop!(id), do: Repo.get!(GlobalProp, id)

  # ── Global SFX ──
  def list_global_sfx(user_id),
    do: from(gs in GlobalSfx, where: gs.user_id == ^user_id) |> Repo.all()

  def create_global_sfx(attrs),
    do: %GlobalSfx{} |> GlobalSfx.changeset(attrs) |> Repo.insert()

  def delete_global_sfx(gs), do: Repo.delete(gs)

  # ── Global BGM ──
  def list_global_bgm(user_id),
    do: from(gb in GlobalBgm, where: gb.user_id == ^user_id) |> Repo.all()

  def create_global_bgm(attrs),
    do: %GlobalBgm{} |> GlobalBgm.changeset(attrs) |> Repo.insert()

  def delete_global_bgm(gb), do: Repo.delete(gb)
  def update_global_bgm(gb, attrs), do: gb |> GlobalBgm.changeset(attrs) |> Repo.update()

  def update_global_sfx(gs, attrs), do: gs |> GlobalSfx.changeset(attrs) |> Repo.update()
  def get_global_sfx!(id), do: Repo.get!(GlobalSfx, id)
  def get_global_bgm!(id), do: Repo.get!(GlobalBgm, id)

  def update_global_location(gl, attrs), do: gl |> GlobalLocation.changeset(attrs) |> Repo.update()

  # ── Appearance helpers ──

  def create_or_update_appearance(character, attrs) do
    case character.appearances do
      [existing | _] ->
        existing |> GlobalCharacterAppearance.changeset(attrs) |> Repo.update()

      _ ->
        %GlobalCharacterAppearance{}
        |> GlobalCharacterAppearance.changeset(attrs)
        |> Repo.insert()
    end
  end

  def list_appearances(character_id) do
    from(a in GlobalCharacterAppearance,
      where: a.global_character_id == ^character_id,
      order_by: [asc: a.appearance_index]
    )
    |> Repo.all()
  end

  # ── Location image helpers ──

  def create_or_update_location_image(location, attrs) do
    case location.images do
      [existing | _] ->
        existing |> GlobalLocationImage.changeset(attrs) |> Repo.update()

      _ ->
        %GlobalLocationImage{}
        |> GlobalLocationImage.changeset(attrs)
        |> Repo.insert()
    end
  end

  # ── Generic helpers ──
  def get_global_character!(id), do: Repo.get!(GlobalCharacter, id) |> Repo.preload(:appearances)
  def get_global_location!(id), do: Repo.get!(GlobalLocation, id) |> Repo.preload(:images)
  def get_global_voice!(id), do: Repo.get!(GlobalVoice, id)
end
