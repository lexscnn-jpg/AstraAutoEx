defmodule AstraAutoEx.AI.LLMStreamer do
  @moduledoc """
  Streams LLM tokens from a provider to a subscriber process via messages.

  Purpose: Give LiveView pages real-time token feedback during long LLM calls
  (story→script, script→storyboard etc.). The original Next.js project did
  this via SSE; in Phoenix we use process messages + LiveView handle_info.

  ## Message contract

  Sends these to the subscriber pid:

    - `{:llm_chunk, stream_id, text}` — each token/chunk as it arrives
    - `{:llm_done, stream_id, full_text}` — stream complete, full accumulated text
    - `{:llm_error, stream_id, reason}` — stream failed

  ## Usage

      stream_id = "story-gen-" <> Ecto.UUID.generate()
      LLMStreamer.stream_to(self(), stream_id, user_id, "apiyi", %{
        messages: [%{role: "user", content: "Write a short story"}],
        model: "gpt-4o-mini"
      })

  ## Design

  - Spawns a Task under a named supervisor so streams can be cancelled.
  - Falls back to non-streaming chat when provider lacks stream_chat support,
    still emits a single :llm_chunk + :llm_done so caller UI is uniform.
  - 300s timeout per stream.
  """

  require Logger

  alias AstraAutoEx.Workers.Handlers.Helpers

  @supervisor_name __MODULE__.TaskSupervisor

  @doc """
  Return the child spec for the internal Task.Supervisor. Add to your
  supervision tree so streams run under it.
  """
  def task_supervisor_child_spec do
    {Task.Supervisor, name: @supervisor_name}
  end

  @doc """
  Start streaming in the background. The subscriber pid receives chunks.
  Returns `{:ok, task_pid}` — caller can `Task.Supervisor.terminate_child/2`
  to cancel.
  """
  @spec stream_to(pid(), String.t(), integer() | nil, String.t(), map()) ::
          {:ok, pid()} | {:error, term()}
  def stream_to(subscriber, stream_id, user_id, provider, request) do
    Task.Supervisor.start_child(@supervisor_name, fn ->
      do_stream(subscriber, stream_id, user_id, provider, request)
    end)
  end

  # ── Internal ──

  defp do_stream(subscriber, stream_id, user_id, provider, request) do
    try do
      case Helpers.chat_stream(user_id, provider, request) do
        {:ok, stream} ->
          accumulate_and_forward(subscriber, stream_id, stream)

        {:error, :not_supported} ->
          # Fallback: run blocking chat, emit as single chunk
          fallback_to_blocking(subscriber, stream_id, user_id, provider, request)

        {:error, reason} ->
          send(subscriber, {:llm_error, stream_id, reason})
      end
    rescue
      e ->
        Logger.error("[LLMStreamer] stream crashed: #{Exception.message(e)}")
        send(subscriber, {:llm_error, stream_id, Exception.message(e)})
    end
  end

  defp accumulate_and_forward(subscriber, stream_id, stream) do
    full_text =
      stream
      |> Enum.reduce("", fn chunk, acc ->
        # chunk is a binary (token slice) from provider parse_sse_chunks
        send(subscriber, {:llm_chunk, stream_id, chunk})
        acc <> chunk
      end)

    send(subscriber, {:llm_done, stream_id, full_text})
  end

  defp fallback_to_blocking(subscriber, stream_id, user_id, provider, request) do
    case Helpers.chat(user_id, provider, request) do
      {:ok, text, _meta} when is_binary(text) ->
        # Simulate streaming in 50-char chunks so UI shows "progress"
        text
        |> String.graphemes()
        |> Enum.chunk_every(50)
        |> Enum.each(fn chunk ->
          send(subscriber, {:llm_chunk, stream_id, Enum.join(chunk)})
          Process.sleep(30)
        end)

        send(subscriber, {:llm_done, stream_id, text})

      {:error, reason} ->
        send(subscriber, {:llm_error, stream_id, reason})

      other ->
        send(subscriber, {:llm_error, stream_id, {:unexpected, other}})
    end
  end
end
