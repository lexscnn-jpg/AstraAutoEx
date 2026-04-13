defmodule AstraAutoEx.Repo.Migrations.FixUrlColumnLengths do
  use Ecto.Migration

  def change do
    # MiniMax returns very long URLs (>255 chars)
    alter table(:panels) do
      modify :image_url, :text
      modify :video_url, :text
      modify :image_prompt, :text
      modify :video_prompt, :text
    end

    alter table(:voice_lines) do
      modify :audio_url, :text
    end

    alter table(:episodes) do
      modify :audio_url, :text
      modify :composed_video_key, :text
    end

    # characters and locations may not have image_url column yet
    # skip for now — they use text fields already or don't have URLs
  end
end
