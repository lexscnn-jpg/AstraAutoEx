defmodule AstraAutoEx.TasksTest do
  use AstraAutoEx.DataCase

  alias AstraAutoEx.{Tasks, Projects}
  alias AstraAutoEx.Tasks.Task

  setup do
    {:ok, user} =
      AstraAutoEx.Accounts.register_user(%{
        email: "task_test_#{System.unique_integer([:positive])}@example.com",
        username: "tasktest#{System.unique_integer([:positive])}",
        password: "password123456"
      })

    {:ok, project} = Projects.create_project(user.id, %{"name" => "Task Test"})
    %{user: user, project: project}
  end

  describe "create_task/1" do
    test "creates a task", %{user: user, project: project} do
      {:ok, task} =
        Tasks.create_task(%{
          user_id: user.id,
          project_id: project.id,
          type: "image_panel",
          target_type: "panel",
          target_id: "test-panel-1"
        })

      assert task.type == "image_panel"
      assert task.status == "queued"
      assert task.attempt == 0
    end
  end

  describe "lifecycle" do
    test "mark_processing → mark_completed", %{user: user, project: project} do
      {:ok, task} =
        Tasks.create_task(%{
          user_id: user.id,
          project_id: project.id,
          type: "voice_line",
          target_type: "voice_line",
          target_id: "vl-1"
        })

      assert Tasks.mark_processing(task.id)
      updated = Tasks.get_task!(task.id)
      assert updated.status == "processing"

      Tasks.mark_completed(task.id, %{audio_url: "test.wav"})
      completed = Tasks.get_task!(task.id)
      assert completed.status == "completed"
    end

    test "mark_failed with error", %{user: user, project: project} do
      {:ok, task} =
        Tasks.create_task(%{
          user_id: user.id,
          project_id: project.id,
          type: "video_panel",
          target_type: "panel",
          target_id: "p-1"
        })

      Tasks.mark_processing(task.id)
      Tasks.mark_failed(task.id, "api_error", "Provider returned 500")

      failed = Tasks.get_task!(task.id)
      assert failed.status == "failed"
      assert failed.error_code == "api_error"
    end
  end

  describe "queries" do
    test "list_queued_tasks", %{user: user, project: project} do
      {:ok, _} =
        Tasks.create_task(%{
          user_id: user.id,
          project_id: project.id,
          type: "image_panel",
          target_type: "panel",
          target_id: "p1"
        })

      {:ok, _} =
        Tasks.create_task(%{
          user_id: user.id,
          project_id: project.id,
          type: "voice_line",
          target_type: "voice_line",
          target_id: "vl1"
        })

      queued = Tasks.list_queued_tasks()
      assert length(queued) >= 2
    end

    test "list_project_tasks", %{user: user, project: project} do
      {:ok, _} =
        Tasks.create_task(%{
          user_id: user.id,
          project_id: project.id,
          type: "image_panel",
          target_type: "panel",
          target_id: "p1"
        })

      tasks = Tasks.list_project_tasks(project.id)
      assert length(tasks) >= 1
    end
  end

  describe "queue_type/1" do
    test "image tasks go to image queue" do
      assert Task.queue_type("image_panel") == :image
      assert Task.queue_type("image_character") == :image
    end

    test "video tasks go to video queue" do
      assert Task.queue_type("video_panel") == :video
      assert Task.queue_type("video_compose") == :video
    end

    test "voice tasks go to voice queue" do
      assert Task.queue_type("voice_line") == :voice
      assert Task.queue_type("music_generate") == :voice
    end

    test "text tasks default to text queue" do
      assert Task.queue_type("analyze_novel") == :text
      assert Task.queue_type("story_to_script_run") == :text
      assert Task.queue_type("sd_topic_selection") == :text
    end
  end

  describe "events" do
    test "create_event!/3 logs events", %{user: user, project: project} do
      {:ok, task} =
        Tasks.create_task(%{
          user_id: user.id,
          project_id: project.id,
          type: "image_panel",
          target_type: "panel",
          target_id: "p1"
        })

      event = Tasks.create_event!(task, "task.processing")
      assert event.event_type == "task.processing"

      events = Tasks.list_events(task.id)
      assert length(events) >= 1
    end
  end
end
