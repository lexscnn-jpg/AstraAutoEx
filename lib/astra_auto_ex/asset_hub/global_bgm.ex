defmodule AstraAutoEx.AssetHub.GlobalBgm do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "global_bgm" do
    field :user_id, :integer
    field :folder_id, :binary_id
    field :name, :string
    field :category, :string
    field :description, :string
    field :audio_url, :string
    field :duration_ms, :integer
    field :prompt, :string
    field :lyrics, :string
    field :is_instrumental, :boolean, default: false

    timestamps()
  end

  def changeset(bgm, attrs) do
    bgm
    |> cast(attrs, [
      :user_id,
      :folder_id,
      :name,
      :category,
      :description,
      :audio_url,
      :duration_ms,
      :prompt,
      :lyrics,
      :is_instrumental
    ])
    |> validate_required([:user_id, :name])
  end
end
