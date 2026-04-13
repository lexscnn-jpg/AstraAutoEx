defmodule AstraAutoEx.Characters.CharacterAppearance do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "character_appearances" do
    belongs_to :character, AstraAutoEx.Characters.Character
    field :appearance_index, :integer, default: 0
    field :change_reason, :string
    field :description, :string
    field :descriptions, {:array, :string}, default: []
    field :image_url, :string
    field :image_media_id, :binary_id
    field :previous_description, :string
    field :previous_image_url, :string

    timestamps()
  end

  def changeset(appearance, attrs) do
    appearance
    |> cast(attrs, [
      :character_id,
      :appearance_index,
      :change_reason,
      :description,
      :descriptions,
      :image_url,
      :image_media_id,
      :previous_description,
      :previous_image_url
    ])
    |> validate_required([:character_id])
  end
end
