defmodule AstraAutoEx.Tasks.Task do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "tasks" do
    belongs_to :user, AstraAutoEx.Accounts.User, type: :id
    field :project_id, :integer
    field :episode_id, :binary_id
    field :type, :string
    field :target_type, :string
    field :target_id, :string
    field :status, :string, default: "queued"
    field :progress, :integer, default: 0
    field :attempt, :integer, default: 0
    field :max_attempts, :integer, default: 5
    field :priority, :integer, default: 0
    field :dedupe_key, :string
    field :external_id, :string
    field :payload, :map
    field :result, :map
    field :error_code, :string
    field :error_message, :string
    field :billing_info, :map
    field :billed_at, :utc_datetime
    field :queued_at, :utc_datetime
    field :started_at, :utc_datetime
    field :finished_at, :utc_datetime
    field :heartbeat_at, :utc_datetime

    has_many :events, AstraAutoEx.Tasks.TaskEvent

    timestamps()
  end

  @statuses ~w(queued processing completed failed canceled paused dismissed)
  @active_statuses ~w(queued processing)

  def active_statuses, do: @active_statuses

  @queue_map %{
    "image_panel" => :image,
    "image_character" => :image,
    "image_location" => :image,
    "panel_variant" => :image,
    "modify_asset_image" => :image,
    "regenerate_group" => :image,
    "asset_hub_image" => :image,
    "asset_hub_modify" => :image,
    "video_panel" => :video,
    "lip_sync" => :video,
    "video_compose" => :video,
    "voice_line" => :voice,
    "voice_design" => :voice,
    "asset_hub_voice_design" => :voice,
    "music_generate" => :voice
  }

  def queue_type(task_type) do
    Map.get(@queue_map, task_type, :text)
  end

  def changeset(task, attrs) do
    task
    |> cast(attrs, [
      :user_id,
      :project_id,
      :episode_id,
      :type,
      :target_type,
      :target_id,
      :status,
      :progress,
      :attempt,
      :max_attempts,
      :priority,
      :dedupe_key,
      :external_id,
      :payload,
      :result,
      :error_code,
      :error_message,
      :billing_info,
      :billed_at,
      :queued_at,
      :started_at,
      :finished_at,
      :heartbeat_at
    ])
    |> validate_required([:user_id, :project_id, :type, :target_type, :target_id])
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint(:dedupe_key)
  end
end
