defmodule AstraAutoEx.AI.VoicePresets do
  @moduledoc """
  MiniMax 2.8HD voice presets. Will be populated from API on first load.
  Provides search/filter by gender, language.
  """

  @doc "Get all cached voice presets. Returns empty list if not loaded yet."
  def all do
    case :persistent_term.get({__MODULE__, :presets}, nil) do
      nil -> default_presets()
      presets -> presets
    end
  end

  @doc "Search presets by name"
  def search(query) do
    q = String.downcase(query)
    Enum.filter(all(), fn p ->
      String.contains?(String.downcase(p.name), q) or
        String.contains?(String.downcase(p.description || ""), q)
    end)
  end

  @doc "Filter by gender"
  def filter_by_gender(gender) when gender in ["male", "female"] do
    Enum.filter(all(), &(&1.gender == gender))
  end
  def filter_by_gender(_), do: all()

  @doc "Filter by language"
  def filter_by_language(lang) do
    Enum.filter(all(), &(&1.language == lang))
  end

  @doc "Store presets in persistent_term (call after API fetch)"
  def cache_presets(presets) do
    :persistent_term.put({__MODULE__, :presets}, presets)
  end

  defp default_presets do
    [
      %{id: "Calm_Woman", name: "沉稳女声", gender: "female", language: "zh", description: "温柔沉稳的成熟女声"},
      %{id: "Gentle_Woman", name: "温柔女声", gender: "female", language: "zh", description: "轻柔甜美的女声"},
      %{id: "Sweet_Girl", name: "甜美少女", gender: "female", language: "zh", description: "活泼可爱的少女声"},
      %{id: "Confident_Woman", name: "自信女声", gender: "female", language: "zh", description: "干练自信的职业女声"},
      %{id: "Deep_Voice_Man", name: "低沉男声", gender: "male", language: "zh", description: "浑厚低沉的男声"},
      %{id: "Warm_Man", name: "温暖男声", gender: "male", language: "zh", description: "温暖亲切的男声"},
      %{id: "Young_Man", name: "青年男声", gender: "male", language: "zh", description: "阳光开朗的年轻男声"},
      %{id: "Narrator", name: "旁白", gender: "male", language: "zh", description: "专业沉稳的旁白配音"},
      %{id: "Cute_Boy", name: "可爱男孩", gender: "male", language: "zh", description: "稚嫩可爱的男童声"},
      %{id: "Energetic_Girl_EN", name: "活力女生(英)", gender: "female", language: "en", description: "Energetic young female voice"},
      %{id: "Professional_Man_EN", name: "专业男声(英)", gender: "male", language: "en", description: "Professional male narrator"},
      %{id: "Friendly_Woman_EN", name: "友好女声(英)", gender: "female", language: "en", description: "Friendly warm female voice"}
    ]
  end
end
