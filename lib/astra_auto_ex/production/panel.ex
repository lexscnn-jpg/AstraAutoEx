defmodule AstraAutoEx.Production.Panel do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "panels" do
    belongs_to :storyboard, AstraAutoEx.Production.Storyboard
    field :episode_id, :binary_id
    field :panel_index, :integer
    field :shot_type, :string
    field :camera_move, :string
    field :description, :string
    field :location, :string
    field :characters, :string
    field :props, :string
    field :image_prompt, :string
    field :image_url, :string
    field :image_media_id, :binary_id
    field :image_history, :map
    field :video_prompt, :string
    field :video_url, :string
    field :video_media_id, :binary_id
    field :lip_sync_task_id, :binary_id
    field :lip_sync_video_url, :string
    field :lip_sync_video_media_id, :binary_id
    field :sketch_image_url, :string
    field :sketch_image_media_id, :binary_id
    field :photography_rules, :string
    field :acting_notes, :string
    field :candidate_images, :map

    has_many :voice_lines, AstraAutoEx.Production.VoiceLine
    timestamps()
  end

  def changeset(panel, attrs) do
    panel
    |> cast(attrs, [
      :storyboard_id,
      :episode_id,
      :panel_index,
      :shot_type,
      :camera_move,
      :description,
      :location,
      :characters,
      :props,
      :image_prompt,
      :image_url,
      :image_media_id,
      :image_history,
      :video_prompt,
      :video_url,
      :video_media_id,
      :lip_sync_task_id,
      :lip_sync_video_url,
      :lip_sync_video_media_id,
      :sketch_image_url,
      :sketch_image_media_id,
      :photography_rules,
      :acting_notes,
      :candidate_images
    ])
    |> validate_required([:storyboard_id])
  end
end
