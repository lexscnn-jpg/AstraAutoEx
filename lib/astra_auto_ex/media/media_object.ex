defmodule AstraAutoEx.Media.MediaObject do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "media_objects" do
    field :public_id, :string
    field :storage_key, :string
    field :sha256, :string
    field :mime_type, :string
    field :size_bytes, :integer
    field :width, :integer
    field :height, :integer
    field :duration_ms, :integer

    timestamps()
  end

  @required_fields [:storage_key, :public_id]
  @optional_fields [:sha256, :mime_type, :size_bytes, :width, :height, :duration_ms]

  def changeset(media_object, attrs) do
    media_object
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:public_id)
    |> unique_constraint(:storage_key)
  end

  @doc "Generate a stable public_id from a storage key: m_{sha256_hex_40}"
  def stable_public_id(storage_key) do
    hex = :crypto.hash(:sha256, storage_key) |> Base.encode16(case: :lower)
    "m_" <> binary_part(hex, 0, 40)
  end
end
