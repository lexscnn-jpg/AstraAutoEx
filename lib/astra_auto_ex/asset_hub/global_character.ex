defmodule AstraAutoEx.AssetHub.GlobalCharacter do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "global_characters" do
    belongs_to :user, AstraAutoEx.Accounts.User, type: :id
    field :folder_id, :binary_id
    field :name, :string
    field :aliases, :string
    field :introduction, :string
    field :voice_id, :string
    field :voice_type, :string
    field :custom_voice_url, :string
    field :custom_voice_media_id, :binary_id
    field :profile_data, :map
    field :profile_confirmed, :boolean, default: false

    has_many :appearances, AstraAutoEx.AssetHub.GlobalCharacterAppearance,
      foreign_key: :global_character_id

    timestamps()
  end

  def changeset(gc, attrs) do
    gc
    |> cast(attrs, [
      :user_id,
      :folder_id,
      :name,
      :aliases,
      :introduction,
      :voice_id,
      :voice_type,
      :custom_voice_url,
      :custom_voice_media_id,
      :profile_data,
      :profile_confirmed
    ])
    |> validate_required([:user_id, :name])
  end
end
