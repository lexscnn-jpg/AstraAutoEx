defmodule AstraAutoEx.Production.Storyboard do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "storyboards" do
    belongs_to :clip, AstraAutoEx.Production.Clip
    field :episode_id, :binary_id
    field :panel_count, :integer, default: 0
    field :storyboard_text_json, :string
    field :image_history, :map

    has_many :panels, AstraAutoEx.Production.Panel
    timestamps()
  end

  def changeset(sb, attrs) do
    sb
    |> cast(attrs, [:clip_id, :episode_id, :panel_count, :storyboard_text_json, :image_history])
    |> validate_required([:clip_id, :episode_id])
  end
end
