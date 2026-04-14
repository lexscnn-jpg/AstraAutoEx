defmodule AstraAutoEx.AI.FlPromptRewriter do
  @moduledoc """
  Generates transition descriptions between adjacent panels using LLM.
  Port of original project's rewriteFlPromptWithLLM logic.
  """

  alias AstraAutoEx.Workers.Handlers.Helpers

  @doc """
  Generate a first-last-frame transition prompt via LLM.
  Falls back to mechanical join on failure.
  """
  def rewrite(first_desc, last_desc, first_dialogue, last_dialogue, art_style, opts \\ []) do
    user_id = Keyword.get(opts, :user_id)
    model = Keyword.get(opts, :model, "default")

    system_prompt = """
    你是一个专业的视频转场描述生成器。根据两个相邻画面的描述和对白，
    生成一段 20-200 字的转场描述，描述从第一个画面到第二个画面的自然过渡。
    保持画面风格：#{art_style || "与参考图风格一致"}。
    只输出转场描述，不要输出其他内容。
    """

    user_prompt = """
    第一帧描述：#{first_desc || "(无)"}
    第一帧对白：#{first_dialogue || "(无对白)"}
    末帧描述：#{last_desc || "(无)"}
    末帧对白：#{last_dialogue || "(无对白)"}
    """

    case Helpers.chat(user_id, model, system_prompt, user_prompt, temperature: 0.3, max_tokens: 300) do
      {:ok, result} ->
        text = String.trim(result)

        if String.length(text) >= 20 and String.length(text) <= 200 do
          {:ok, text}
        else
          {:ok, fallback(first_desc, last_desc)}
        end

      {:error, _reason} ->
        {:ok, fallback(first_desc, last_desc)}
    end
  end

  @doc "Mechanical fallback when LLM fails"
  def fallback(first_desc, last_desc) do
    first = first_desc || ""
    last = last_desc || ""

    if last == "" do
      first
    else
      "#{first}。镜头自然过渡：#{last}"
    end
  end
end
