defmodule AstraAutoEx.Characters.Character do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "characters" do
    belongs_to :user, AstraAutoEx.Accounts.User, type: :id
    field :project_id, :integer
    field :episode_id, :binary_id
    field :name, :string
    field :aliases, :string
    field :introduction, :string
    field :voice_id, :string
    field :voice_type, :string
    field :custom_voice_url, :string
    field :custom_voice_media_id, :binary_id
    field :profile_data, :map
    field :profile_confirmed, :boolean, default: false

    has_many :appearances, AstraAutoEx.Characters.CharacterAppearance
    timestamps()
  end

  def changeset(character, attrs) do
    character
    |> cast(attrs, [
      :user_id,
      :project_id,
      :episode_id,
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
    |> validate_required([:user_id, :project_id, :name])
  end
end
