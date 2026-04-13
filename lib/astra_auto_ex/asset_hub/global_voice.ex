defmodule AstraAutoEx.AssetHub.GlobalVoice do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "global_voices" do
    belongs_to :user, AstraAutoEx.Accounts.User, type: :id
    field :folder_id, :binary_id
    field :name, :string
    field :voice_id, :string
    field :voice_type, :string, default: "custom"
    field :custom_voice_url, :string
    field :custom_voice_media_id, :binary_id
    field :voice_prompt, :string
    field :gender, :string
    field :language, :string, default: "zh"
    field :description, :string
    timestamps()
  end

  def changeset(gv, attrs) do
    gv
    |> cast(attrs, [
      :user_id,
      :folder_id,
      :name,
      :voice_id,
      :voice_type,
      :custom_voice_url,
      :custom_voice_media_id,
      :voice_prompt,
      :gender,
      :language,
      :description
    ])
    |> validate_required([:user_id, :name])
  end
end
