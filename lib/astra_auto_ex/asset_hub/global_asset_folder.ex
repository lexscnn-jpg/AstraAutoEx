defmodule AstraAutoEx.AssetHub.GlobalAssetFolder do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "global_asset_folders" do
    belongs_to :user, AstraAutoEx.Accounts.User, type: :id
    field :name, :string
    field :description, :string
    timestamps()
  end

  def changeset(folder, attrs) do
    folder |> cast(attrs, [:user_id, :name, :description]) |> validate_required([:user_id, :name])
  end
end
