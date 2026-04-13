defmodule AstraAutoEx.Projects.Project do
  use Ecto.Schema
  import Ecto.Changeset

  schema "projects" do
    field :name, :string
    field :description, :string
    field :type, :string, default: "standard"
    field :status, :string, default: "active"
    field :aspect_ratio, :string, default: "16:9"
    field :settings, :map, default: %{}
    field :metadata, :map, default: %{}

    belongs_to :user, AstraAutoEx.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @valid_types ~w(standard short_drama)
  @valid_statuses ~w(active archived completed)
  @valid_ratios ~w(16:9 9:16 1:1 4:3 3:2 21:9)

  def changeset(project, attrs) do
    project
    |> cast(attrs, [:name, :description, :type, :status, :aspect_ratio, :settings, :metadata])
    |> validate_required([:name, :user_id])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_inclusion(:type, @valid_types)
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_inclusion(:aspect_ratio, @valid_ratios)
    |> foreign_key_constraint(:user_id)
  end
end
