defmodule AstraAutoEx.Workers.ConcurrencyTest do
  use AstraAutoEx.DataCase

  alias AstraAutoEx.{Tasks, Projects}
  alias AstraAutoEx.Workers.ConcurrencyLimiter

  setup do
    {:ok, user} =
      AstraAutoEx.Accounts.register_user(%{
        email: "conc_#{System.unique_integer([:positive])}@example.com",
        username: "conc#{System.unique_integer([:positive])}",
        password: "password123456"
      })

    {:ok, project} = Projects.create_project(user.id, %{"name" => "Concurrency Test"})
    %{user: user, project: project}
  end

  describe "ConcurrencyLimiter" do
    test "limit_for returns correct limits" do
      assert ConcurrencyLimiter.limit_for(:image) == 20
      assert ConcurrencyLimiter.limit_for(:video) == 5
      assert ConcurrencyLimiter.limit_for(:voice) == 10
      assert ConcurrencyLimiter.limit_for(:text) == 50
    end

    test "acquire and release" do
      uid = "conc-test-#{System.unique_integer([:positive])}"
      assert :ok = ConcurrencyLimiter.acquire(:image, uid)
      ConcurrencyLimiter.release(:image, uid)
      # Give cast time to process
      Process.sleep(10)
    end

    test "acquire returns at_capacity when full" do
      # Use unique prefix to avoid conflicts with other tests
      prefix = "fill-#{System.unique_integer([:positive])}"

      # Fill video queue (limit 5)
      for i <- 1..5 do
        assert :ok = ConcurrencyLimiter.acquire(:video, "#{prefix}-#{i}")
      end

      assert {:error, :at_capacity} = ConcurrencyLimiter.acquire(:video, "#{prefix}-overflow")

      # Cleanup
      for i <- 1..5 do
        ConcurrencyLimiter.release(:video, "#{prefix}-#{i}")
      end

      Process.sleep(10)
    end
  end

  describe "Task retry logic" do
    test "task starts with attempt 0 and max_attempts 5", %{user: user, project: project} do
      {:ok, task} =
        Tasks.create_task(%{
          user_id: user.id,
          project_id: project.id,
          type: "image_panel",
          target_type: "panel",
          target_id: "retry-#{System.unique_integer([:positive])}"
        })

      assert task.attempt == 0
      assert task.max_attempts == 5
    end

    test "mark_processing increments attempt", %{user: user, project: project} do
      {:ok, task} =
        Tasks.create_task(%{
          user_id: user.id,
          project_id: project.id,
          type: "voice_line",
          target_type: "voice_line",
          target_id: "retry-#{System.unique_integer([:positive])}"
        })

      Tasks.mark_processing(task.id)
      updated = Tasks.get_task!(task.id)
      assert updated.status == "processing"
      assert updated.attempt == 1
    end

    test "task can be canceled", %{user: user, project: project} do
      {:ok, task} =
        Tasks.create_task(%{
          user_id: user.id,
          project_id: project.id,
          type: "video_panel",
          target_type: "panel",
          target_id: "cancel-#{System.unique_integer([:positive])}"
        })

      Tasks.mark_canceled(task.id, "user_requested")
      canceled = Tasks.get_task!(task.id)
      assert canceled.status == "canceled"
    end

    test "update_progress sets progress", %{user: user, project: project} do
      {:ok, task} =
        Tasks.create_task(%{
          user_id: user.id,
          project_id: project.id,
          type: "image_panel",
          target_type: "panel",
          target_id: "prog-#{System.unique_integer([:positive])}"
        })

      Tasks.update_progress(task.id, 50)
      updated = Tasks.get_task!(task.id)
      assert updated.progress == 50
    end

    test "set_external_id stores async reference", %{user: user, project: project} do
      {:ok, task} =
        Tasks.create_task(%{
          user_id: user.id,
          project_id: project.id,
          type: "video_panel",
          target_type: "panel",
          target_id: "ext-#{System.unique_integer([:positive])}"
        })

      Tasks.set_external_id(task.id, "FAL:VIDEO:endpoint:req123")
      updated = Tasks.get_task!(task.id)
      assert updated.external_id == "FAL:VIDEO:endpoint:req123"
    end

    test "dedupe_key prevents duplicate tasks", %{user: user, project: project} do
      key = "dedupe-#{System.unique_integer([:positive])}"

      attrs = %{
        user_id: user.id,
        project_id: project.id,
        type: "image_panel",
        target_type: "panel",
        target_id: "dup-test",
        dedupe_key: key
      }

      assert {:ok, _} = Tasks.create_task(attrs)
      assert {:error, _} = Tasks.create_task(attrs)
    end
  end

  describe "stale task detection" do
    test "list_stale_processing finds old tasks", %{user: user, project: project} do
      {:ok, task} =
        Tasks.create_task(%{
          user_id: user.id,
          project_id: project.id,
          type: "image_panel",
          target_type: "panel",
          target_id: "stale-#{System.unique_integer([:positive])}"
        })

      Tasks.mark_processing(task.id)

      # Set heartbeat to 10 minutes ago
      past = DateTime.add(DateTime.utc_now(), -600, :second)
      import Ecto.Query

      AstraAutoEx.Repo.update_all(
        from(t in AstraAutoEx.Tasks.Task, where: t.id == ^task.id),
        set: [heartbeat_at: past]
      )

      stale = Tasks.list_stale_processing(300)
      assert Enum.any?(stale, fn t -> t.id == task.id end)
    end
  end
end
