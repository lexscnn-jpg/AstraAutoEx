defmodule AstraAutoEx.AssetHub.GlobalProp do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "global_props" do
    field :user_id, :integer
    field :folder_id, :binary_id
    field :name, :string
    field :prop_type, :string
    field :description, :string
    field :image_url, :string
    field :image_urls, {:array, :string}, default: []
    field :selected_index, :integer, default: 0
    field :previous_image_url, :string

    timestamps()
  end

  def changeset(prop, attrs) do
    prop
    |> cast(attrs, [:user_id, :folder_id, :name, :prop_type, :description,
                    :image_url, :image_urls, :selected_index, :previous_image_url])
    |> validate_required([:user_id, :name])
  end
end
