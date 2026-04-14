defmodule AstraAutoEx.AssetHub.Generator do
  @moduledoc """
  Image/music generation for global assets.
  Builds prompts, calls providers, updates asset records.
  Used by AssetHub LiveView for inline generation (no task queue).
  """
  require Logger
  alias AstraAutoEx.Workers.Handlers.Helpers
  alias AstraAutoEx.AssetHub

  # ── Character Image (三视图) ──

  def generate_character_image(user_id, character, opts \\ []) do
    model_config = Helpers.get_model_config(user_id, nil, :image)
    provider = model_config["provider"]
    count = Keyword.get(opts, :candidate_count, 1)

    prompt = build_character_prompt(character)

    results =
      1..count
      |> Enum.map(fn _ ->
        request = %{
          prompt: prompt,
          model: model_config["model"],
          aspect_ratio: "3:4"
        }

        Helpers.generate_image(user_id, provider, request)
      end)

    successes =
      results
      |> Enum.filter(&match?({:ok, _}, &1))
      |> Enum.map(fn {:ok, result} ->
        Map.get(result, :image_url) || Map.get(result, :url)
      end)
      |> Enum.reject(&is_nil/1)

    case successes do
      [] ->
        {:error, "All image generations failed"}

      [url | _] ->
        # Create/update appearance with first successful image
        appearance_attrs = %{
          global_character_id: character.id,
          description: character.introduction || "",
          image_url: url
        }

        case AssetHub.create_or_update_appearance(character, appearance_attrs) do
          {:ok, _appearance} ->
            {:ok, %{image_urls: successes, primary_url: url}}

          error ->
            Logger.error("[Generator] Failed to save appearance: #{inspect(error)}")
            {:ok, %{image_urls: successes, primary_url: url}}
        end
    end
  end

  # ── Location Image ──

  def generate_location_image(user_id, location, _opts \\ []) do
    model_config = Helpers.get_model_config(user_id, nil, :image)
    provider = model_config["provider"]

    prompt = "场景参考图：#{location.name}。#{location.summary || location.description || ""}。画面要有环境氛围感，展示场景的整体布局与特征。"

    request = %{
      prompt: prompt,
      model: model_config["model"],
      aspect_ratio: "16:9"
    }

    case Helpers.generate_image(user_id, provider, request) do
      {:ok, result} ->
        url = Map.get(result, :image_url) || Map.get(result, :url)

        if url do
          AssetHub.create_or_update_location_image(location, %{
            global_location_id: location.id,
            description: location.summary || "",
            image_url: url
          })
        end

        {:ok, %{image_url: url}}

      error ->
        error
    end
  end

  # ── Prop Image (三视图) ──

  def generate_prop_image(user_id, prop, _opts \\ []) do
    model_config = Helpers.get_model_config(user_id, nil, :image)
    provider = model_config["provider"]

    prompt = build_prop_prompt(prop)

    request = %{
      prompt: prompt,
      model: model_config["model"],
      aspect_ratio: "3:4"
    }

    case Helpers.generate_image(user_id, provider, request) do
      {:ok, result} ->
        url = Map.get(result, :image_url) || Map.get(result, :url)

        if url do
          AssetHub.update_global_prop(prop, %{image_url: url})
        end

        {:ok, %{image_url: url}}

      error ->
        error
    end
  end

  # ── Refine Image (精调) ──

  def refine_image(user_id, asset_type, asset, instruction) do
    model_config = Helpers.get_model_config(user_id, nil, :image)
    provider = model_config["provider"]

    current_url = get_asset_image_url(asset_type, asset)

    prompt =
      "基于现有图片进行修改：#{instruction}。保持整体风格和构图不变，仅按指令调整。"

    request = %{
      prompt: prompt,
      model: model_config["model"],
      aspect_ratio: if(asset_type in ["character", "prop"], do: "3:4", else: "16:9"),
      reference_images: if(current_url, do: [current_url], else: [])
    }

    case Helpers.generate_image(user_id, provider, request) do
      {:ok, result} ->
        url = Map.get(result, :image_url) || Map.get(result, :url)

        if url do
          save_refined_image(asset_type, asset, url, current_url)
        end

        {:ok, %{image_url: url, previous_url: current_url}}

      error ->
        error
    end
  end

  # ── Music Generation (MiniMax) ──

  def generate_music(user_id, bgm) do
    alias AstraAutoEx.AI.Providers.Minimax

    with {:ok, config} <- Helpers.get_provider_config(user_id, "minimax") do
      request = %{
        prompt: bgm.description || bgm.prompt || "#{bgm.name} - #{bgm.category || "cinematic"} style background music",
        model: "music-2.6",
        lyrics: bgm.lyrics,
        is_instrumental: bgm.is_instrumental || true
      }

      case Minimax.generate_music(request, config) do
        {:ok, %{audio: audio_data}} when is_binary(audio_data) ->
          # audio_data could be a URL or hex data
          audio_url = if String.starts_with?(audio_data, "http"), do: audio_data, else: nil
          if audio_url, do: AssetHub.update_global_bgm(bgm, %{audio_url: audio_url})
          {:ok, %{audio_url: audio_url, raw: audio_data}}

        {:ok, result} ->
          {:ok, result}

        error ->
          error
      end
    end
  end

  # ── Undo Refinement ──

  def undo_refine(asset_type, asset) do
    case asset_type do
      "prop" ->
        if asset.previous_image_url do
          AssetHub.update_global_prop(asset, %{
            image_url: asset.previous_image_url,
            previous_image_url: nil
          })
        else
          {:error, "No previous version available"}
        end

      _ ->
        {:error, "Undo not supported for #{asset_type}"}
    end
  end

  # ── Private ──

  defp build_character_prompt(character) do
    name = character.name || ""
    intro = character.introduction || ""

    """
    角色设定图，画面分为左右两个区域：\
    【左侧区域】占约1/3宽度，#{name}的正面特写，五官清晰；\
    【右侧区域】占约2/3宽度，三视图横向排列（正面全身、侧面全身、背面全身），\
    三视图高度一致，比例协调。纯白色背景。\
    角色描述：#{intro}。#{name}。\
    """
    |> String.trim()
  end

  defp build_prop_prompt(prop) do
    name = prop.name || ""
    desc = prop.description || ""
    type_label = prop_type_label(prop.prop_type)

    """
    道具设定图，画面分为左右两个区域：\
    【左侧区域】占约1/3宽度，#{name}的主体主视图特写；\
    【右侧区域】占约2/3宽度，三视图横向排列（正面、侧面、背面），比例一致。\
    纯白色背景，无人物。\
    道具类型：#{type_label}。描述：#{desc}。\
    """
    |> String.trim()
  end

  defp prop_type_label("weapon"), do: "武器"
  defp prop_type_label("tool"), do: "工具"
  defp prop_type_label("accessory"), do: "配饰"
  defp prop_type_label("vehicle"), do: "载具"
  defp prop_type_label("food"), do: "食物"
  defp prop_type_label(_), do: "通用道具"

  defp get_asset_image_url("character", asset) do
    case asset.appearances do
      [%{image_url: url} | _] when is_binary(url) and url != "" -> url
      _ -> nil
    end
  end

  defp get_asset_image_url("location", asset) do
    case asset.images do
      [%{image_url: url} | _] when is_binary(url) and url != "" -> url
      _ -> nil
    end
  end

  defp get_asset_image_url("prop", asset), do: asset.image_url
  defp get_asset_image_url(_, _), do: nil

  defp save_refined_image("prop", asset, new_url, old_url) do
    AssetHub.update_global_prop(asset, %{
      image_url: new_url,
      previous_image_url: old_url
    })
  end

  defp save_refined_image("character", asset, new_url, _old_url) do
    AssetHub.create_or_update_appearance(asset, %{
      global_character_id: asset.id,
      image_url: new_url
    })
  end

  defp save_refined_image("location", asset, new_url, _old_url) do
    AssetHub.create_or_update_location_image(asset, %{
      global_location_id: asset.id,
      image_url: new_url
    })
  end

  defp save_refined_image(_, _, _, _), do: :ok
end
