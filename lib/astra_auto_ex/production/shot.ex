defmodule AstraAutoEx.Production.Shot do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "shots" do
    field :episode_id, :binary_id
    belongs_to :panel, AstraAutoEx.Production.Panel
    field :shot_index, :integer
    field :srt_start, :float
    field :srt_end, :float
    field :srt_duration, :float
    field :sequence, :integer
    field :locations, :string
    field :characters, :string
    field :plot, :string
    field :image_prompt, :string
    field :image_url, :string
    field :image_media_id, :binary_id
    field :video_url, :string
    field :video_media_id, :binary_id
    field :scale, :string
    field :focus, :string
    field :pov, :string
    timestamps()
  end

  def changeset(shot, attrs) do
    shot
    |> cast(attrs, [
      :episode_id,
      :panel_id,
      :shot_index,
      :srt_start,
      :srt_end,
      :srt_duration,
      :sequence,
      :locations,
      :characters,
      :plot,
      :image_prompt,
      :image_url,
      :image_media_id,
      :video_url,
      :video_media_id,
      :scale,
      :focus,
      :pov
    ])
    |> validate_required([:episode_id])
  end
end
