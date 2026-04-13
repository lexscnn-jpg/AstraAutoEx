defmodule AstraAutoEx.ShortDrama.EpisodeScript do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "episode_scripts" do
    belongs_to :series_plan, AstraAutoEx.ShortDrama.SeriesPlan
    field :episode_number, :integer
    field :title, :string
    field :conflict, :string
    field :script_content, :string
    field :quality_score, :float
    field :quality_report, :string
    field :compliance_status, :string
    field :status, :string, default: "draft"
    timestamps()
  end

  def changeset(es, attrs) do
    es
    |> cast(attrs, [
      :series_plan_id,
      :episode_number,
      :title,
      :conflict,
      :script_content,
      :quality_score,
      :quality_report,
      :compliance_status,
      :status
    ])
    |> validate_required([:series_plan_id])
  end
end
