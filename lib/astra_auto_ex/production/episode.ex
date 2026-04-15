defmodule AstraAutoEx.Production.Episode do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "episodes" do
    field :project_id, :integer
    field :user_id, :integer
    field :episode_number, :integer
    field :title, :string
    field :name, :string
    field :status, :string, default: "draft"
    field :novel_text, :string
    field :audio_url, :string
    field :audio_media_id, :binary_id
    field :srt_content, :string
    field :imported_script_text, :string
    field :imported_script_meta, :map
    field :composed_video_key, :string
    field :compose_status, :string
    field :compose_task_id, :binary_id
    field :public_id, :string

    has_many :clips, AstraAutoEx.Production.Clip
    has_many :voice_lines, AstraAutoEx.Production.VoiceLine
    timestamps()
  end

  def changeset(episode, attrs) do
    episode
    |> cast(attrs, [
      :project_id,
      :user_id,
      :episode_number,
      :title,
      :name,
      :status,
      :novel_text,
      :audio_url,
      :audio_media_id,
      :srt_content,
      :imported_script_text,
      :imported_script_meta,
      :composed_video_key,
      :compose_status,
      :compose_task_id,
      :public_id
    ])
    |> validate_required([:project_id, :user_id])
  end
end
