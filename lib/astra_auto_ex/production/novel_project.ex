defmodule AstraAutoEx.Production.NovelProject do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "novel_projects" do
    field :project_id, :integer
    field :analysis_model, :string
    field :image_model, :string
    field :video_model, :string
    field :audio_model, :string
    field :storyboard_llm_model, :string
    field :video_ratio, :string, default: "9:16"
    field :video_resolution, :string, default: "720p"
    field :art_style, :string
    field :tts_rate, :float
    field :auto_chain_enabled, :boolean, default: false
    field :full_auto_chain_enabled, :boolean, default: false
    timestamps()
  end

  def changeset(np, attrs) do
    np
    |> cast(attrs, [
      :project_id,
      :analysis_model,
      :image_model,
      :video_model,
      :audio_model,
      :storyboard_llm_model,
      :video_ratio,
      :video_resolution,
      :art_style,
      :tts_rate,
      :auto_chain_enabled,
      :full_auto_chain_enabled
    ])
    |> validate_required([:project_id])
    |> unique_constraint(:project_id)
  end
end
