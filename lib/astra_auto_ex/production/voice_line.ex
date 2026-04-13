defmodule AstraAutoEx.Production.VoiceLine do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "voice_lines" do
    field :episode_id, :binary_id
    belongs_to :panel, AstraAutoEx.Production.Panel
    field :line_index, :integer
    field :speaker, :string
    field :content, :string
    field :audio_url, :string
    field :audio_media_id, :binary_id
    field :audio_duration, :float
    field :voice_preset_id, :string
    field :voice_type, :string
    field :emotion_prompt, :string
    field :emotion_strength, :float
    field :matched_panel_id, :binary_id
    field :matched_panel_index, :integer
    timestamps()
  end

  def changeset(vl, attrs) do
    vl
    |> cast(attrs, [
      :episode_id,
      :panel_id,
      :line_index,
      :speaker,
      :content,
      :audio_url,
      :audio_media_id,
      :audio_duration,
      :voice_preset_id,
      :voice_type,
      :emotion_prompt,
      :emotion_strength,
      :matched_panel_id,
      :matched_panel_index
    ])
    |> validate_required([:episode_id])
  end
end
