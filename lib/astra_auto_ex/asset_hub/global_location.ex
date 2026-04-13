defmodule AstraAutoEx.AssetHub.GlobalLocation do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "global_locations" do
    belongs_to :user, AstraAutoEx.Accounts.User, type: :id
    field :folder_id, :binary_id
    field :name, :string
    field :art_style, :string
    field :summary, :string
    has_many :images, AstraAutoEx.AssetHub.GlobalLocationImage, foreign_key: :global_location_id
    timestamps()
  end

  def changeset(gl, attrs) do
    gl
    |> cast(attrs, [:user_id, :folder_id, :name, :art_style, :summary])
    |> validate_required([:user_id, :name])
  end
end
