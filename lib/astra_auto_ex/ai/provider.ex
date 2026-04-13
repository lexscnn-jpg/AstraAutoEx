defmodule AstraAutoEx.AI.Provider do
  @moduledoc "Behaviour interface for AI providers."

  @callback generate_image(request :: map(), config :: map()) :: {:ok, map()} | {:error, term()}
  @callback generate_video(request :: map(), config :: map()) :: {:ok, map()} | {:error, term()}
  @callback text_to_speech(request :: map(), config :: map()) :: {:ok, map()} | {:error, term()}
  @callback chat(request :: map(), config :: map()) :: {:ok, String.t()} | {:error, term()}
  @callback chat_stream(request :: map(), config :: map()) ::
              {:ok, Enumerable.t()} | {:error, term()}
  @callback poll_task(external_id :: String.t(), config :: map()) ::
              {:ok, map()} | {:error, term()}
  @callback capabilities() :: [atom()]

  @optional_callbacks [
    generate_image: 2,
    generate_video: 2,
    text_to_speech: 2,
    chat: 2,
    chat_stream: 2,
    poll_task: 2
  ]
end
