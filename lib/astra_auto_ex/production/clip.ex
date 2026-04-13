defmodule AstraAutoEx.Production.Clip do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "clips" do
    belongs_to :episode, AstraAutoEx.Production.Episode
    field :clip_index, :integer
    field :start_time, :float
    field :end_time, :float
    field :duration, :float
    field :content, :string
    field :summary, :string
    field :location, :string
    field :characters, :string
    field :props, :string
    field :screenplay, :string

    has_many :storyboards, AstraAutoEx.Production.Storyboard
    timestamps()
  end

  def changeset(clip, attrs) do
    clip
    |> cast(attrs, [
      :episode_id,
      :clip_index,
      :start_time,
      :end_time,
      :duration,
      :content,
      :summary,
      :location,
      :characters,
      :props,
      :screenplay
    ])
    |> validate_required([:episode_id])
  end
end
