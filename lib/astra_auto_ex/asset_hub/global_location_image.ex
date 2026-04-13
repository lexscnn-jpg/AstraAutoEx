defmodule AstraAutoEx.AssetHub.GlobalLocationImage do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "global_location_images" do
    belongs_to :global_location, AstraAutoEx.AssetHub.GlobalLocation
    field :image_index, :integer, default: 0
    field :description, :string
    field :available_slots, :integer
    field :image_url, :string
    field :image_media_id, :binary_id
    field :is_selected, :boolean, default: false
    timestamps()
  end

  def changeset(gli, attrs) do
    gli
    |> cast(attrs, [
      :global_location_id,
      :image_index,
      :description,
      :available_slots,
      :image_url,
      :image_media_id,
      :is_selected
    ])
    |> validate_required([:global_location_id])
  end
end
