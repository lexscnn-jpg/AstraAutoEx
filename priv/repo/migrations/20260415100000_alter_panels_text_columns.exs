defmodule AstraAutoEx.Repo.Migrations.AlterPanelsTextColumns do
  use Ecto.Migration

  def change do
    alter table(:panels) do
      modify :shot_type, :text, from: :string
      modify :camera_move, :text, from: :string
      modify :location, :text, from: :string
      modify :characters, :text, from: :string
      modify :props, :text, from: :string
    end
  end
end
