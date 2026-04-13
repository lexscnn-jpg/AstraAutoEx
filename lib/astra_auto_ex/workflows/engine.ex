defmodule AstraAutoEx.Workflows.Engine do
  @moduledoc """
  Workflow execution engine — runs DAG-based workflows.
  Ported from original AstraAuto src/core/workflow/registry.ts.

  Two main workflows:
  - story_to_script: analyze chars → analyze locs → split clips → screenplay convert → persist
  - script_to_storyboard: plan panels → detail panels → voice analyze → persist
  """

  require Logger

  alias AstraAutoEx.{Workflows, Tasks}

  @workflow_definitions %{
    "story_to_script" => [
      %{id: "analyze_characters", depends_on: []},
      %{id: "analyze_locations", depends_on: []},
      %{id: "analyze_props", depends_on: []},
      %{
        id: "split_clips",
        depends_on: ["analyze_characters", "analyze_locations", "analyze_props"]
      },
      %{id: "screenplay_convert", depends_on: ["split_clips"]},
      %{id: "persist_artifacts", depends_on: ["screenplay_convert"]}
    ],
    "script_to_storyboard" => [
      %{id: "plan_panels", depends_on: []},
      %{id: "detail_panels", depends_on: ["plan_panels"]},
      %{id: "voice_analyze", depends_on: ["detail_panels"]},
      %{id: "persist_artifacts", depends_on: ["detail_panels", "voice_analyze"]}
    ]
  }

  @doc "Start a workflow run."
  def start_workflow(workflow_type, attrs) do
    steps = Map.get(@workflow_definitions, workflow_type, [])

    if Enum.empty?(steps) do
      {:error, "Unknown workflow: #{workflow_type}"}
    else
      {:ok, run} =
        Workflows.create_graph_run(%{
          project_id: attrs[:project_id],
          episode_id: attrs[:episode_id],
          user_id: attrs[:user_id],
          workflow_type: workflow_type,
          status: "running",
          metadata: attrs[:metadata] || %{}
        })

      # Create graph steps
      Enum.each(steps, fn step_def ->
        Workflows.create_graph_step(%{
          graph_run_id: run.id,
          step_id: step_def.id,
          status: "pending",
          depends_on: step_def.depends_on
        })
      end)

      # Execute ready steps
      execute_ready_steps(run)

      {:ok, run}
    end
  end

  @doc "Called when a step completes — advances the workflow."
  def step_completed(run_id, step_id, result \\ %{}) do
    Workflows.update_graph_step_by_step_id(run_id, step_id, %{
      status: "completed",
      result: result,
      completed_at: DateTime.utc_now()
    })

    run = Workflows.get_graph_run!(run_id)
    execute_ready_steps(run)
  end

  @doc "Called when a step fails."
  def step_failed(run_id, step_id, error) do
    Workflows.update_graph_step_by_step_id(run_id, step_id, %{
      status: "failed",
      error: error
    })

    # Check if workflow should fail
    run = Workflows.get_graph_run!(run_id)
    steps = Workflows.list_graph_steps(run_id)

    if Enum.any?(steps, fn s -> s.status == "failed" end) do
      Workflows.update_graph_run(run, %{status: "failed"})
    end
  end

  @doc "Get workflow definition."
  def get_definition(workflow_type) do
    Map.get(@workflow_definitions, workflow_type)
  end

  @doc "List all workflow types."
  def list_workflow_types, do: Map.keys(@workflow_definitions)

  # Execute all steps whose dependencies are satisfied
  defp execute_ready_steps(run) do
    steps = Workflows.list_graph_steps(run.id)

    ready_steps =
      steps
      |> Enum.filter(fn step ->
        step.status == "pending" and dependencies_met?(step, steps)
      end)

    if Enum.empty?(ready_steps) do
      # Check if all done
      all_completed = Enum.all?(steps, fn s -> s.status in ["completed", "skipped"] end)

      if all_completed do
        Workflows.update_graph_run(run, %{status: "completed", completed_at: DateTime.utc_now()})
        Logger.info("[Workflow] Run #{run.id} completed")
      end
    else
      Enum.each(ready_steps, fn step ->
        Workflows.update_graph_step_by_step_id(run.id, step.step_id, %{status: "running"})
        Logger.info("[Workflow] Executing step #{step.step_id} in run #{run.id}")

        # Dispatch step as a task
        dispatch_step_task(run, step)
      end)
    end
  end

  defp dependencies_met?(step, all_steps) do
    deps = step.depends_on || []

    Enum.all?(deps, fn dep_id ->
      Enum.any?(all_steps, fn s ->
        s.step_id == dep_id and s.status in ["completed", "skipped"]
      end)
    end)
  end

  defp dispatch_step_task(run, step) do
    # Map workflow step to task type
    task_type = step_to_task_type(run.workflow_type, step.step_id)

    if task_type do
      Tasks.create_task(%{
        user_id: run.user_id,
        project_id: run.project_id,
        episode_id: run.episode_id,
        type: task_type,
        target_type: "workflow_step",
        target_id: "#{run.id}:#{step.step_id}",
        payload: %{
          "workflow_run_id" => run.id,
          "step_id" => step.step_id,
          "metadata" => run.metadata
        }
      })
    else
      # Auto-complete steps without task mapping (like persist_artifacts)
      step_completed(run.id, step.step_id, %{auto: true})
    end
  end

  defp step_to_task_type("story_to_script", "analyze_characters"), do: "analyze_novel"
  defp step_to_task_type("story_to_script", "analyze_locations"), do: "analyze_novel"
  defp step_to_task_type("story_to_script", "analyze_props"), do: "analyze_novel"
  defp step_to_task_type("story_to_script", "split_clips"), do: "clips_build"
  defp step_to_task_type("story_to_script", "screenplay_convert"), do: "screenplay_convert"
  defp step_to_task_type("script_to_storyboard", "plan_panels"), do: "script_to_storyboard_run"
  defp step_to_task_type("script_to_storyboard", "detail_panels"), do: "script_to_storyboard_run"
  defp step_to_task_type("script_to_storyboard", "voice_analyze"), do: "voice_line"
  defp step_to_task_type(_, _), do: nil
end
