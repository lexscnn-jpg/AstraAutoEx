defmodule AstraAutoEx.Locations.Location do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "locations" do
    belongs_to :user, AstraAutoEx.Accounts.User, type: :id
    field :project_id, :integer
    field :episode_id, :binary_id
    field :name, :string
    field :summary, :string
    field :asset_kind, :string

    has_many :images, AstraAutoEx.Locations.LocationImage
    timestamps()
  end

  def changeset(location, attrs) do
    location
    |> cast(attrs, [:user_id, :project_id, :episode_id, :name, :summary, :asset_kind])
    |> validate_required([:user_id, :project_id, :name])
  end
end
