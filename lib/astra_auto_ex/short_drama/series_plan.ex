defmodule AstraAutoEx.ShortDrama.SeriesPlan do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @stages ~w(topic_selection story_outline character_dev episode_directory episode_script quality_review compliance_check overseas_adapt)

  schema "series_plans" do
    field :project_id, :integer
    belongs_to :user, AstraAutoEx.Accounts.User, type: :id
    field :stage, :string, default: "topic_selection"
    field :topic_report, :string
    field :story_outline, :string
    field :characters, :string
    field :episode_directory, :string
    field :compliance_result, :string
    field :quality_reviews, :string
    field :overseas_adaptation, :string
    field :metadata, :map
    has_many :episode_scripts, AstraAutoEx.ShortDrama.EpisodeScript
    timestamps()
  end

  def changeset(sp, attrs) do
    sp
    |> cast(attrs, [
      :project_id,
      :user_id,
      :stage,
      :topic_report,
      :story_outline,
      :characters,
      :episode_directory,
      :compliance_result,
      :quality_reviews,
      :overseas_adaptation,
      :metadata
    ])
    |> validate_required([:project_id, :user_id])
    |> validate_inclusion(:stage, @stages)
  end
end
