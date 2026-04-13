defmodule AstraAutoEx.AssetHub.GlobalCharacterAppearance do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "global_character_appearances" do
    belongs_to :global_character, AstraAutoEx.AssetHub.GlobalCharacter
    field :appearance_index, :integer, default: 0
    field :art_style, :string
    field :description, :string
    field :descriptions, {:array, :string}, default: []
    field :image_url, :string
    field :image_media_id, :binary_id
    timestamps()
  end

  def changeset(gca, attrs) do
    gca
    |> cast(attrs, [
      :global_character_id,
      :appearance_index,
      :art_style,
      :description,
      :descriptions,
      :image_url,
      :image_media_id
    ])
    |> validate_required([:global_character_id])
  end
end
