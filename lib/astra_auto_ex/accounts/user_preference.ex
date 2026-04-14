defmodule AstraAutoEx.Accounts.UserPreference do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_preferences" do
    field :provider_configs, :map, default: %{}
    field :model_selections, :map, default: %{}
    field :storage_config, :map, default: %{}
    field :prompt_overrides, :map, default: %{}
    field :theme, :string, default: "system"
    field :locale, :string, default: "zh"

    belongs_to :user, AstraAutoEx.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(preference, attrs) do
    preference
    |> cast(attrs, [
      :user_id,
      :provider_configs,
      :model_selections,
      :storage_config,
      :prompt_overrides,
      :theme,
      :locale
    ])
    |> validate_required([:user_id])
    |> validate_inclusion(:theme, ["system", "light", "dark"])
    |> validate_inclusion(:locale, ["en", "zh"])
    |> unique_constraint(:user_id)
  end
end
