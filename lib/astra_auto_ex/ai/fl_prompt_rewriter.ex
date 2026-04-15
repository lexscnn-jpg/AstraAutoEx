defmodule AstraAutoEx.AI.FlPromptRewriter do
  @moduledoc """
  Generates transition descriptions between adjacent panels using LLM.
  Also provides FL (First-Last frame) pair suggestion logic based on
  scene and character overlap.
  """

  alias AstraAutoEx.Workers.Handlers.Helpers

  @doc """
  Generate a first-last-frame transition prompt via LLM.
  Falls back to mechanical join on failure.
  """
  @spec rewrite(
          String.t() | nil,
          String.t() | nil,
          String.t() | nil,
          String.t() | nil,
          String.t() | nil,
          keyword()
        ) ::
          {:ok, String.t()}
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

    request = %{
      "messages" => [
        %{"role" => "system", "content" => system_prompt},
        %{"role" => "user", "content" => user_prompt}
      ],
      "temperature" => 0.3,
      "max_tokens" => 300
    }

    case Helpers.chat(user_id, model, request) do
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
  @spec fallback(String.t() | nil, String.t() | nil) :: String.t()
  def fallback(first_desc, last_desc) do
    first = first_desc || ""
    last = last_desc || ""

    if last == "" do
      first
    else
      "#{first}\u3002\u955C\u5934\u81EA\u7136\u8FC7\u6E21\uFF1A#{last}"
    end
  end

  # ---------------------------------------------------------------------------
  # FL Pair Suggestion
  # ---------------------------------------------------------------------------

  @doc """
  Suggest FL (First-Last frame) pairs from a list of panels.
  Adjacent panels sharing the same location and at least 1 character
  are good candidates for smooth FL transitions.

  Scoring:
  - location_match: +3
  - each shared character: +2
  - same clip (storyboard): +1

  Returns a list of `{panel_a, panel_b, score}` tuples, sorted by score descending.
  """
  @spec suggest_fl_pairs(list()) :: [{map(), map(), integer()}]
  def suggest_fl_pairs(panels) when is_list(panels) do
    panels
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [a, b] ->
      score = compute_pair_score(a, b)
      {a, b, score}
    end)
    |> Enum.filter(fn {_a, _b, score} -> score >= 3 end)
    |> Enum.sort_by(fn {_a, _b, score} -> -score end)
  end

  def suggest_fl_pairs(_), do: []

  defp compute_pair_score(panel_a, panel_b) do
    loc_a = normalize_field(panel_a, :location)
    loc_b = normalize_field(panel_b, :location)

    chars_a = parse_characters(panel_a)
    chars_b = parse_characters(panel_b)

    location_score = if loc_a != "" and loc_a == loc_b, do: 3, else: 0

    overlap =
      MapSet.intersection(MapSet.new(chars_a), MapSet.new(chars_b))
      |> MapSet.size()

    character_score = overlap * 2

    # Same storyboard (clip) bonus
    sb_a = Map.get(panel_a, :storyboard_id)
    sb_b = Map.get(panel_b, :storyboard_id)
    clip_score = if sb_a && sb_a == sb_b, do: 1, else: 0

    location_score + character_score + clip_score
  end

  defp normalize_field(panel, field) do
    (Map.get(panel, field) || "")
    |> String.trim()
    |> String.downcase()
  end

  defp parse_characters(panel) do
    chars_str = Map.get(panel, :characters) || ""

    chars_str
    |> String.split(~r/[,;，、]/)
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.downcase/1)
    |> Enum.reject(&(&1 == ""))
  end
end
