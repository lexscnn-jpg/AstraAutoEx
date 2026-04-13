defmodule AstraAutoEx.Media do
  @moduledoc "Media context for managing MediaObject records."

  import Ecto.Query
  alias AstraAutoEx.Repo
  alias AstraAutoEx.Media.MediaObject

  def get_by_id(id), do: Repo.get(MediaObject, id)

  def get_by_public_id(public_id) do
    Repo.get_by(MediaObject, public_id: public_id)
  end

  def get_by_storage_key(storage_key) do
    Repo.get_by(MediaObject, storage_key: storage_key)
  end

  @doc """
  Upsert a MediaObject from a storage key.
  If one already exists with this storage_key, returns it.
  Handles concurrent race conditions.
  """
  def ensure_media_object(storage_key, metadata \\ %{}) do
    public_id = MediaObject.stable_public_id(storage_key)

    attrs =
      Map.merge(metadata, %{
        storage_key: storage_key,
        public_id: public_id
      })

    changeset = MediaObject.changeset(%MediaObject{}, attrs)

    case Repo.insert(changeset,
           on_conflict: :nothing,
           conflict_target: :storage_key,
           returning: true
         ) do
      {:ok, %MediaObject{id: nil}} ->
        # on_conflict: :nothing returned no id, look it up
        {:ok, Repo.get_by!(MediaObject, storage_key: storage_key)}

      {:ok, media_object} ->
        {:ok, media_object}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def upsert_media_object(attrs) do
    ensure_media_object(
      Map.get(attrs, :storage_key) || Map.get(attrs, "storage_key"),
      attrs
    )
  end

  def list_recent(limit \\ 50) do
    MediaObject
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def delete(media_object) do
    Repo.delete(media_object)
  end
end
