defmodule AstraAutoEx.AI.VoicePresets do
  @moduledoc """
  MiniMax 2.8HD voice presets.
  Loads 300+ system voices from API on first access, falls back to hardcoded defaults.
  Provides search/filter by gender, language, category.
  """
  require Logger

  @doc "Get all voice presets. Fetches from API on first call, then caches."
  @spec all() :: [map()]
  def all do
    case :persistent_term.get({__MODULE__, :presets}, nil) do
      nil -> default_presets()
      presets -> presets
    end
  end

  @doc "Load voices from MiniMax API and cache them."
  @spec load_from_api(String.t()) :: {:ok, [map()]} | {:error, any()}
  def load_from_api(user_id) do
    alias AstraAutoEx.Workers.Handlers.Helpers

    with {:ok, config} <- Helpers.get_provider_config(user_id, "minimax") do
      case AstraAutoEx.AI.Providers.Minimax.list_voices(config) do
        {:ok, presets} when is_list(presets) and length(presets) > 0 ->
          cache_presets(presets)
          Logger.info("[VoicePresets] Loaded #{length(presets)} voices from MiniMax API")
          {:ok, presets}

        {:ok, []} ->
          Logger.info("[VoicePresets] API returned empty list, using defaults")
          {:ok, default_presets()}

        {:error, reason} ->
          Logger.warning(
            "[VoicePresets] Failed to load from API: #{inspect(reason)}, using defaults"
          )

          {:error, reason}
      end
    end
  end

  @doc "Search presets by name or description."
  @spec search(String.t()) :: [map()]
  def search(query) do
    q = String.downcase(query)

    Enum.filter(all(), fn p ->
      String.contains?(String.downcase(p.name), q) or
        String.contains?(String.downcase(p[:description] || ""), q)
    end)
  end

  @doc "Filter by gender."
  @spec filter_by_gender(String.t()) :: [map()]
  def filter_by_gender(gender) when gender in ["male", "female"] do
    Enum.filter(all(), &(&1.gender == gender))
  end

  def filter_by_gender(_), do: all()

  @doc "Filter by language."
  @spec filter_by_language(String.t()) :: [map()]
  def filter_by_language(lang) do
    Enum.filter(all(), &(&1.language == lang))
  end

  @doc "Filter by category."
  @spec filter_by_category(String.t()) :: [map()]
  def filter_by_category(category) do
    Enum.filter(all(), &(&1[:category] == category))
  end

  @doc "Get all unique categories."
  @spec categories() :: [String.t()]
  def categories do
    all()
    |> Enum.map(& &1[:category])
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc "Find a preset by ID."
  @spec get(String.t()) :: map() | nil
  def get(id) do
    Enum.find(all(), &(&1.id == id))
  end

  @doc "Store presets in persistent_term (call after API fetch)."
  @spec cache_presets([map()]) :: :ok
  def cache_presets(presets) do
    :persistent_term.put({__MODULE__, :presets}, presets)
    :ok
  end

  @doc "Check if voices have been loaded from API."
  @spec loaded?() :: boolean()
  def loaded? do
    :persistent_term.get({__MODULE__, :presets}, nil) != nil
  end

  defp default_presets do
    [
      %{
        id: "Calm_Woman",
        name: "沉稳女声",
        gender: "female",
        language: "zh",
        category: "通用",
        description: "温柔沉稳的成熟女声"
      },
      %{
        id: "Gentle_Woman",
        name: "温柔女声",
        gender: "female",
        language: "zh",
        category: "通用",
        description: "轻柔甜美的女声"
      },
      %{
        id: "Sweet_Girl",
        name: "甜美少女",
        gender: "female",
        language: "zh",
        category: "通用",
        description: "活泼可爱的少女声"
      },
      %{
        id: "Confident_Woman",
        name: "自信女声",
        gender: "female",
        language: "zh",
        category: "通用",
        description: "干练自信的职业女声"
      },
      %{
        id: "Deep_Voice_Man",
        name: "低沉男声",
        gender: "male",
        language: "zh",
        category: "通用",
        description: "浑厚低沉的男声"
      },
      %{
        id: "Warm_Man",
        name: "温暖男声",
        gender: "male",
        language: "zh",
        category: "通用",
        description: "温暖亲切的男声"
      },
      %{
        id: "Young_Man",
        name: "青年男声",
        gender: "male",
        language: "zh",
        category: "通用",
        description: "阳光开朗的年轻男声"
      },
      %{
        id: "Narrator",
        name: "旁白",
        gender: "male",
        language: "zh",
        category: "旁白",
        description: "专业沉稳的旁白配音"
      },
      %{
        id: "Cute_Boy",
        name: "可爱男孩",
        gender: "male",
        language: "zh",
        category: "儿童",
        description: "稚嫩可爱的男童声"
      },
      %{
        id: "Energetic_Girl_EN",
        name: "活力女生(英)",
        gender: "female",
        language: "en",
        category: "英文",
        description: "Energetic young female voice"
      },
      %{
        id: "Professional_Man_EN",
        name: "专业男声(英)",
        gender: "male",
        language: "en",
        category: "英文",
        description: "Professional male narrator"
      },
      %{
        id: "Friendly_Woman_EN",
        name: "友好女声(英)",
        gender: "female",
        language: "en",
        category: "英文",
        description: "Friendly warm female voice"
      }
    ]
  end
end
