defmodule AstraAutoEx.AssetHub.GlobalSfx do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "global_sfx" do
    field :user_id, :integer
    field :folder_id, :binary_id
    field :name, :string
    field :category, :string
    field :description, :string
    field :audio_url, :string
    field :duration_ms, :integer

    timestamps()
  end

  def changeset(sfx, attrs) do
    sfx
    |> cast(attrs, [:user_id, :folder_id, :name, :category, :description, :audio_url, :duration_ms])
    |> validate_required([:user_id, :name])
  end
end
