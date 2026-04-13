defmodule AstraAutoEx.ProductionTest do
  use AstraAutoEx.DataCase

  alias AstraAutoEx.{Production, Projects}

  setup do
    {:ok, user} =
      AstraAutoEx.Accounts.register_user(%{
        email: "prod_test_#{System.unique_integer([:positive])}@example.com",
        username: "prodtest#{System.unique_integer([:positive])}",
        password: "password123456"
      })

    {:ok, project} = Projects.create_project(user.id, %{"name" => "Production Test"})
    %{user: user, project: project}
  end

  describe "episodes" do
    test "create and list", %{user: user, project: project} do
      {:ok, ep} =
        Production.create_episode(%{
          project_id: project.id,
          user_id: user.id,
          episode_number: 1,
          name: "Pilot"
        })

      assert ep.name == "Pilot"

      episodes = Production.list_episodes(project.id)
      assert length(episodes) == 1
      assert hd(episodes).name == "Pilot"
    end

    test "get_episode!/1", %{user: user, project: project} do
      {:ok, ep} =
        Production.create_episode(%{
          project_id: project.id,
          user_id: user.id,
          episode_number: 1
        })

      found = Production.get_episode!(ep.id)
      assert found.id == ep.id
    end
  end

  describe "clips" do
    test "create and list", %{user: user, project: project} do
      {:ok, ep} =
        Production.create_episode(%{project_id: project.id, user_id: user.id, episode_number: 1})

      {:ok, clip} =
        Production.create_clip(%{
          episode_id: ep.id,
          project_id: project.id,
          clip_index: 0,
          summary: "Opening scene"
        })

      assert clip.summary == "Opening scene"

      clips = Production.list_clips(ep.id)
      assert length(clips) == 1
    end
  end

  describe "storyboards and panels" do
    test "create storyboard with panels", %{user: user, project: project} do
      {:ok, ep} =
        Production.create_episode(%{project_id: project.id, user_id: user.id, episode_number: 1})

      {:ok, clip} =
        Production.create_clip(%{episode_id: ep.id, project_id: project.id, clip_index: 0})

      {:ok, sb} = Production.create_storyboard(%{episode_id: ep.id, clip_id: clip.id})

      {:ok, _p1} =
        Production.create_panel(%{
          storyboard_id: sb.id,
          episode_id: ep.id,
          panel_index: 0,
          description: "Wide establishing shot",
          shot_type: "extreme_wide"
        })

      {:ok, _p2} =
        Production.create_panel(%{
          storyboard_id: sb.id,
          episode_id: ep.id,
          panel_index: 1,
          description: "Close up on hero",
          shot_type: "close_up"
        })

      panels = Production.list_panels(sb.id)
      assert length(panels) == 2
      assert hd(panels).description == "Wide establishing shot"
    end

    test "update panel image_url", %{user: user, project: project} do
      {:ok, ep} =
        Production.create_episode(%{project_id: project.id, user_id: user.id, episode_number: 1})

      {:ok, clip} =
        Production.create_clip(%{episode_id: ep.id, project_id: project.id, clip_index: 0})

      {:ok, sb} = Production.create_storyboard(%{episode_id: ep.id, clip_id: clip.id})

      {:ok, panel} =
        Production.create_panel(%{
          storyboard_id: sb.id,
          episode_id: ep.id,
          panel_index: 0,
          description: "test"
        })

      {:ok, updated} = Production.update_panel(panel, %{image_url: "https://example.com/img.png"})
      assert updated.image_url == "https://example.com/img.png"
    end

    test "list_storyboards preloads panels", %{user: user, project: project} do
      {:ok, ep} =
        Production.create_episode(%{project_id: project.id, user_id: user.id, episode_number: 1})

      {:ok, clip} =
        Production.create_clip(%{episode_id: ep.id, project_id: project.id, clip_index: 0})

      {:ok, sb} = Production.create_storyboard(%{episode_id: ep.id, clip_id: clip.id})

      {:ok, _} =
        Production.create_panel(%{
          storyboard_id: sb.id,
          episode_id: ep.id,
          panel_index: 0,
          description: "panel 1"
        })

      [storyboard] = Production.list_storyboards(ep.id)
      assert length(storyboard.panels) == 1
      assert hd(storyboard.panels).description == "panel 1"
    end
  end

  describe "voice_lines" do
    test "create and list", %{user: user, project: project} do
      {:ok, ep} =
        Production.create_episode(%{project_id: project.id, user_id: user.id, episode_number: 1})

      {:ok, vl} =
        Production.create_voice_line(%{
          episode_id: ep.id,
          line_index: 0,
          speaker: "Hero",
          content: "I will save this world!"
        })

      assert vl.speaker == "Hero"

      lines = Production.list_voice_lines(ep.id)
      assert length(lines) == 1
    end

    test "update voice_line audio_url", %{user: user, project: project} do
      {:ok, ep} =
        Production.create_episode(%{project_id: project.id, user_id: user.id, episode_number: 1})

      {:ok, vl} =
        Production.create_voice_line(%{
          episode_id: ep.id,
          line_index: 0,
          speaker: "Test",
          content: "Hello"
        })

      {:ok, updated} =
        Production.update_voice_line(vl, %{audio_url: "https://example.com/audio.wav"})

      assert updated.audio_url == "https://example.com/audio.wav"
    end
  end
end
